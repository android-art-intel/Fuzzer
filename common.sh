#--------------------------------------------------------------------------
#
# Copyright (C) 2016 Intel Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
#--------------------------------------------------------------------------

#--------------------------------------------------------------------------------
# Common part for the scripts dealing with running Android in host mode
#--------------------------------------------------------------------------------

HOME_DIR=<Path to local host builds, called $HOST_BUILDS in readme>
RUN_DIR=<Path to store the local copy of Fuzzer>
FILER_DIR=<Path where the original Fuzzer is located>
APK_DIR="$FILER_DIR/apk"
DX="$ANDROID_SDK_ROOT/platform-tools/dx"

export SAVE_PASSED="false"
export DEVICE_MODE="off"

# Actual branches
AOSP_MASTER="WW10 WW11 WW12"
BRANCH=aosp-master
TARGET=ND
BUILD="WW12"
BITS="64"
SPEC=""
BUILD_SUFF=_HostMode
TEST_NAME=Test
DEX_NAME=classes.dex
VM=dalvikvm
TIME_OUT=120

#--------------------------------------------------------------------------------
# Print error message and exit
function Err {
    echo "Error: $1"
    exit 1
}
#--------------------------------------------------------------------------------
# Print error message and exit
function SetTimeout {
    TIME_OUT=$1
}
#--------------------------------------------------------------------------------
# Parse arguments for setting a new build for run
# Arguments:
#     $1, $2 - option name and option value
function New_build_args {
    [[ "$2" != "" ]] || Err "No value for option $1"
    case $1 in
    -b)
        BRANCH=$2;;
    -bw)
        BUILD=$2;;
    -bb)
        BITS=$2;;
    -bs)
        SPEC=$2
        [[ $SPEC = "-" ]] && SPEC="";;
    *)
        Err "Invalid option $1";;
    esac
}
#--------------------------------------------------------------------------------
# Designate a build for run - build ID is defined by branch, ww, and bits
function Set_build {

    if [ "$BITS" = "64" ]; then
        BUILD_PREF=${BRANCH}/${BUILD}${SPEC}/HOST_64-userdebug
        VM=dalvikvm
        lib_suff="64"
    else
        BUILD_PREF=${BRANCH}/${BUILD}${SPEC}/HOST-userdebug
        VM=dalvikvm32
        lib_suff=""
    fi
    export ANDROID_BUILD_TOP=$HOME_DIR/$BUILD_PREF
    [[ -d $ANDROID_BUILD_TOP ]] || Err "no build directory: $ANDROID_BUILD_TOP"
    export PATH=$ANDROID_BUILD_TOP/out/host/linux-x86/bin:$PATH
    unset ANDROID_PRODUCT_OUT
    export ANDROID_ROOT="${ANDROID_BUILD_TOP}/out/host/linux-x86"
    export ANDROID_HOST_OUT=$ANDROID_ROOT
    export LD_LIBRARY_PATH=$ANDROID_ROOT/lib/
    VM_ARGS="-Ximage:${ANDROID_ROOT}/framework/core.art"
}
#--------------------------------------------------------------------------------
# Check whether compilation was performed
function Check_dex {
    local chdir=${1:-$ANDROID_DATA}
    list=`find "$chdir" -name "*classes.dex" | wc -l`
    [ $list -ge 1 ] && return 0
    return 1
}
#--------------------------------------------------------------------------------
# Run class Test from classes.dex on tested VM (either ART or Dalvik)
function RunVM {
    if [[ "$DEVICE_MODE" = "on" ]]
    then
        RunVM_device $@
        ret=$?
        return $ret
    fi
    prefix_="/tmp"
    [[ -d /export/ram ]] && prefix_="/export/ram/tmp"
    mkdir -p $prefix_ &> /dev/null
    export ANDROID_DATA=$(mktemp -d --tmpdir=$prefix_)
    echo "timeout $TIME_OUT $VM $VM_ARGS $@ -cp $(pwd)/$DEX_NAME $TEST_NAME" >> rt_cmd
    timeout $TIME_OUT $VM $VM_ARGS $@ -cp $(pwd)/$DEX_NAME $TEST_NAME
    RunVM_res=$?
    Check_dex "$ANDROID_DATA" || echo "NO DEX!"
    rm -r $ANDROID_DATA
    if [ $RunVM_res -eq 124 ]; then
        echo "TIMEOUT!"
    fi
    return $RunVM_res
}

#-------------------------------------------------------------------------------
# Check that JIT profile file has been created
function check_profile(){
    adb shell "ls -l /data/misc/profiles/cur/0/com.intel.fuzzer/primary.prof"
}

#--------------------------------------------------------------------------------
# Run class Test from classes.dex on device
function RunVM_device {
    [[ "$VM" = "dalvikvm32" ]] && VM="dalvikvm"
    pwd=$(pwd)
    testname=`basename $pwd`".dex"
    adb push "$(pwd)/classes.dex" /sdcard/$testname&>/dev/null
    adb logcat -c &>/dev/null
    adb logcat 1>&2 &
    pid=$!
    trap 'kill -9 $pid &> /dev/null; exit 1' SIGINT SIGTERM
    echo "timeout $TIME_OUT $ADB shell \"$VM $@ -cp /sdcard/$testname $TEST_NAME\"" >> rt_cmd
    prefix_="/tmp"
    [[ -d /export/ram ]] && prefix_="/export/ram/tmp"
    mkdir -p $prefix_ &> /dev/null
    export tmpout=$(mktemp --tmpdir=$prefix_)
    timeout $TIME_OUT adb shell $VM $@ -cp /sdcard/$testname $TEST_NAME > "$tmpout"
    RunVM_res=$?
    kill -9 $pid &> /dev/null
    wait $pid &> /dev/null
    cat "$tmpout" | tr -d '\r'
    rm -f "$tmpout"
    adb shell rm /sdcard/$testname &>/dev/null
    if [ $RunVM_res -eq 124 ]; then
        echo "TIMEOUT!"
    fi
    return $RunVM_res
}

#--------------------------------------------------------------------------------
# Run the Fuzzer apk. Args: $1 - path to apk. Keep it empty if the apk is installed and you don't want to reinstall. $2 - suffix to be added to the logs file
function Run_apk {
    local apk=${1:-}
    suffix=${2:-}
    seed=${3:-0}
    min_time=${4:-0}
    compile=${5:-}
    adb logcat -c
    adb logcat &> "rt_err$suffix" &
    pid=$!
    trap 'kill -9 $pid; return 1' SIGINT SIGTERM
    if [[ ${#apk} -gt 4 ]]
    then
        adb install -r "$apk" &> /dev/null || return 1
    fi
    if [[ ${#compile} -gt 4 ]]
    then
        ( check_profile ) &>> rt_cmd
        echo "adb shell cmd package compile -f -r bg-dexopt com.intel.fuzzer" >> rt_cmd
        adb shell cmd package compile -f -r bg-dexopt com.intel.fuzzer &> /dev/null

    fi

    echo "adb shell am start -a android.intent.action.VIEW -e seed $seed -e time $min_time com.intel.fuzzer/.MainActivity" >> rt_cmd
    adb shell am start -a android.intent.action.VIEW -e seed $seed -e time $min_time com.intel.fuzzer/.MainActivity &> /dev/null
    local passed=0
    while [[ $passed -le $TIME_OUT ]]
    do
        grep 'FUZZER_FINISHED' "rt_err$suffix" &> /dev/null
        if [[ $? -eq 0 ]]
        then
            outfile=`grep 'FUZZER_OUTFILE:' "rt_err$suffix" | awk -F'OUTFILE: ' '{print $2}'`
            adb pull "$outfile" rt_out$suffix &> /dev/null
            adb shell rm -f "$outfile" &> /dev/null
            adb shell am force-stop com.intel.fuzzer &> /dev/null
            kill -9 $pid &> /dev/null
            wait $pid &> /dev/null
            return 0
        fi
        passed=$(($passed + 1))
        sleep 1
    done
    kill -9 $pid
    wait $pid &> /dev/null
    adb shell am force-stop com.intel.fuzzer &> /dev/null
    return 124
}

#--------------------------------------------------------------------------------
# Run the Fuzzer apk by VM. Args: $1 - path to apk. $2 - suffix to be added to the logs file
function Run_apk_VM {
    local apk=${1:-Fuzzer.apk}
    shift
    suffix=${1:-}
    shift
    seed=${1:-0}
    shift
    [[ "$VM" = "dalvikvm32" ]] && VM="dalvikvm"
    pwd=$(pwd)
    testname=`basename $apk`
    adb push "$apk" /sdcard/${testname} &> /dev/null
    adb logcat -c &>/dev/null
    adb logcat &> "rt_err$suffix" &
    pid=$!
    trap 'kill -9 $pid &> /dev/null; exit 1' SIGINT SIGTERM
    echo "timeout $TIME_OUT adb shell $VM $@ -cp /sdcard/$testname com.intel.fuzzer.TestRunner $seed" >> rt_cmd
    timeout $TIME_OUT adb shell $VM $@ -cp /sdcard/$testname com.intel.fuzzer.TestRunner $seed &> rt_out$suffix
    RunVM_res=$?
    kill -9 $pid &> /dev/null
    wait $pid &> /dev/null
    cat rt_out$suffix | tr -d '\r' > rt_out_$suffix
    mv rt_out_$suffix rt_out$suffix
    adb shell rm /sdcard/$testname &>/dev/null
    return $RunVM_res
}

OPT_ARGS=""
NOPT_ARGS="-Xcompiler-option --compiler-filter=speed"
VM_INT_LIB="-XXlib:libart.so"
INT_ARGS=$VM_INT_LIB" -Xcompiler-option --compiler-filter=interpret-only"
VM_LIB="-XXlib:libartd.so"
PI_ARGS="-Xint:portable"

if [ `basename $0` != "nb.sh" -a `basename $0` != "rd.sh" -a `basename $0` != "mrt.sh" ]; then
    Set_build
fi
