#!/bin/bash

#--------------------------------------------------------------------------
#
# Copyright (C) 2015 The Android Open Source Project
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
# run.sh  Version: 04/06/15    Dima Khukhro
#
# Runs all tests in it's own directory with ART in host mode. All the arguments are 
# optional.
# Arguments:
#    <path> - path to Android build (dir containing dir out). If not present, the env 
#             variable $ANDROID_BUILD_TOP is used.
#    -b <bits> - word width of the Android build: either 32 or 64 (default: 32)
#    -t <name> - name of the test to run. No name means to run all the tests
#    -comp - run the tests by Java and ART in host mode and compare results
#    -o  <option> - runtime additional option
#    -co <option> - compiler additional option
#    -dp <pass> - disable optimization pass (e.g. CopyPropagation). Equivalent to:
#                 -co --disable-passes=<pass>
#    -no  - run the test without optimizations (in speed mode w/o art-extension)
#    -i   - run the tests in interpreter mode. 
#--------------------------------------------------------------------------------

#--------------------------------------------------------------------------------
# Print error message and exit
function Err {
    echo "Error: $1"
    exit 1
}
#--------------------------------------------------------------------------------
function SetEnvironment {
    export ANDROID_BUILD_TOP=$build_dir
    export PATH=$ANDROID_BUILD_TOP/out/host/linux-x86/bin:$PATH
    export ANDROID_HOST_OUT="${ANDROID_BUILD_TOP}/out/host/linux-x86"
    export ANDROID_ROOT=$ANDROID_HOST_OUT
    NOPT_ARGS="-Xcompiler-option --compiler-filter=speed"
    INT_ARGS="-Xcompiler-option --compiler-filter=interpret-only"
    VM_ARGS="-XXlib:libartd.so -Ximage:${ANDROID_ROOT}/framework/core.art"
    [[ $int_mode = "y" ]] && VM_ARGS="$VM_ARGS $INT_ARGS"
    [[ $int_mode = "n" ]] && [[ $no_opt = "y" ]] && VM_ARGS="$VM_ARGS $NOPT_ARGS"
}
#--------------------------------------------------------------------------------
# Run class Test from classes.dex on tested ART
# (cannot use art script since IMIN Legacy and GMIN LDev branches lack it)
function RunVM {
    export ANDROID_DATA=`mktemp -d --tmpdir="$PWD" -t "android-dataXXXXXX"`
    mkdir -p "${ANDROID_DATA}"
    chmod -R 775 "${ANDROID_DATA}"
    $VM $VM_ARGS $@ -cp $(pwd)/classes.dex Test
    rm -rf $ANDROID_DATA
}
#--------------------------------------------------------------------------------
# Run one test. Argument $1 - test name
function RunTest {
    echo ----- Test $1 ----------------------------------------------------------------
    cd $1
    if [ $compare_flag = "y" ]; then
        tmpdir=`mktemp -d --tmpdir=$PWD`
        mkdir -p "$tmpdir"
        java Test >"$tmpdir/out_ref" 2>&1
        RunVM $add_opts >"$tmpdir/out" 2>"$tmpdir/err"
        diff "$tmpdir/out_ref" "$tmpdir/out"
        rm -rf "$tmpdir"
    else
        RunVM $add_opts
    fi
    cd ..
}
#--------------------------------------------------------------------------------

cd "$(dirname "$0")"

build_dir=$ANDROID_BUILD_TOP
VM=dalvikvm32
test_name=""
compare_flag=n
add_opts="-Xno-dex-file-fallback"
no_opt=n
int_mode=n

while [ "$1" != "" ]; do
    case $1 in
	-b)
        [[ "$2" = "32" ]] || [[ "$2" = "64" ]] || Err "Invalid word width (should be either 32 or 64)"
        [[ "$2" = "64" ]] && VM="dalvikvm64"
	    shift;;
	-t)
        test_name=$2
	    shift;;
	-comp)
	    compare_flag=y;;
	-o)
        add_opts="$add_opts $2"
        shift;;
	-co)
        add_opts="$add_opts -Xcompiler-option $2"
        shift;;
	-dp)
	    add_opts="$add_opts -Xcompiler-option --disable-passes=$2"
		shift;;
	-no)
	    no_opt=y;;
	-i)
	    int_mode=y;;
	*)
	    build_dir=$1;;
    esac
    shift
done
[[ -d $build_dir ]] || Err "No build directory: $build_dir"
[[ -d $build_dir/out ]] || Err "Invalid build directory (no dir out): $build_dir"
[[ "$test_name" != "" ]] && [[ ! -d $test_name ]] && Err "No test directory: $test_name"
if [ $compare_flag = "y" ]; then
    if ! which java > /dev/null; then
        Err "For comparing results java should be on the PATH"
    fi
fi

SetEnvironment

if [ "$test_name" != "" ]; then
    RunTest $test_name
    exit 0
fi

for dir in `ls`; do
    [[ -d $dir ]] || continue
    [[ -f $dir/classes.dex ]] || continue
    RunTest $dir
done
