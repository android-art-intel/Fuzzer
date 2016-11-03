#!/bin/bash

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
# Run the icFuzz tool to generate a series of tests; compile each of them with javac,
# make dex file, run the test by java and Dalvik in host mode and compare results.
# Parameter:
#    -b,-bw,-bb <value> - use given build defined by branch, ww, or/and bits.
#    -u <dir name>   - update Ruby files with those from $FILER_DIR/<dir name>
#    -r <path>       - directory to put results into
#    -p <prefix>     - prefix to add to the test dir names
#    -kd - keep old dirs with failures alive if they exist - don't require removing them
#    -co <opt> - compiler additional options
#    -oc - run optimizing compiler
#    -dp <pass> - disable optimization pass
#    -i  - compare test results with interpreter mode instead of Java
#    -no - run the tests without optimizations
#    -t <integer> - timeout in seconds
#    -tn <name>   - name of the test file and main class (Test by default)
#    -v <path>    - verify build with existing tests rather than generate new ones
#    -f <path>    - save summary of the run to the given file in the directory with results
#    -tl <integer>- time limit of the run in minutes
#    -sp - save the tests that passed (they are removed by default)
#    -arg <arg>   - pass an arbitrary argument to VM
#    -gc          - vary GC options during testing
#    -extreme     - Additional option to use with CG mode. Disables output comparison
#    -conf <file> - Pass config file to Fuzzer
#    -apk         - Enable apk mode
#    -st <number> - Number of subtests for apk-mode
#    -si <number> - Number of iterations for apk-mode
#    -mt <number> - Min milliseconds to execute apk
#    -o           - Pass -o option to Fuzzer and control the execution from outside
#    <integer>    - number of tests to generate
#--------------------------------------------------------------------------------

source common.sh

ORIG_RUBY_CODE_DIR="$FILER_DIR/rb"
RUBY_CODE_DIR="$RUN_DIR/rb"

FILES_OF_INTEREST="*.java *.class rt_cmd rt_apk rt_out* rt_err* core* tmp classes.dex src"
FILES_OF_INTEREST_PASSED="$FILES_OF_INTEREST"

GC_TYPES=("GSS" "CMS" "SS")
GC_HSPACE=("-XX:EnableHSpaceCompactForOOM" "-XX:DisableHSpaceCompactForOOM")
GC_VERIFICATION="-Xgc:preverify -Xgc:postverify -Xgc:preverify_rosalloc -Xgc:postverify_rosalloc -Xgc:presweepingverify -Xgc:verifycardtable"
GC_EXP=off
EXTREME=off

conf_file=config.yml

#--------------------------------------------------------------------------------
function Save_passed_res {
    test_dir_path=$res_path/$1/$prefix$2
    mkdir -p $test_dir_path
    chmod 775 "$res_path/$1" 2>&1 >> /dev/null
    chmod -R 775 "$test_dir_path" 2>&1 >> /dev/null
    cp -r $FILES_OF_INTEREST_PASSED $test_dir_path > /dev/null 2>&1
    [[ -n "$3" ]] && echo "    $3!"
}

#--------------------------------------------------------------------------------
function Save_res {
    test_dir_path=$res_path/$1/$prefix$2
    mkdir -p $test_dir_path
    chmod 775 "$res_path/$1" 2>&1 >> /dev/null
    chmod -R 775 "$test_dir_path" 2>&1 >> /dev/null
    cp -r $FILES_OF_INTEREST $test_dir_path > /dev/null 2>&1
    echo "    $3!"
}

#--------------------------------------------------------------------------------
# returns: 0 - test complete, 1 - no JIT, 2 - VerifyError, 3 - Java crash, 4 - should never been returned, 5 - OOM, 6 - Interpreter/Java timeout, 7 - NPE during class initialization
function Run_test_apk {
    # Run in interpreter mode
    if [[ ${#outer_control} -ne 0 ]]
    then
        i=0
        while [[ $i -lt $subiters ]]
        do
            Run_apk_VM Fuzzer.apk "int$i" $i $INT_ARGS
            if [ $? -eq 124 ]; then
                echo "    Interpreter timeout!"
                return 6
            fi
            i=$(($i + 1))
        done
    else
        Run_apk_VM Fuzzer.apk 'int' 0 $INT_ARGS
        if [ $? -eq 124 ]; then
            echo "    Interpreter timeout!"
            return 6
        fi
    fi
    Run_apk Fuzzer.apk 0 0 $MIN_TIME
    empty=0
    timeouts=0
    i=0
    while [[ $i -lt $subiters ]]
    do
        Run_apk " " $i $i $MIN_TIME compile
        res=$?
        [[ $res -eq 124 ]] && timeouts=$(( $timeouts + 1 ))
        [[ ! -s rt_out$i ]] && empty=$(( $empty + 1 ))
        i=$(($i + 1))
    done
    if grep -E 'VerifyError' rt_out* rt_err* > /dev/null; then # workaround for DEX's bug
        let vrferr=vrferr+1
        return 2
    elif grep 'OutOfMemory' rt_out* rt_err* > /dev/null; then # workaround for OOM
        return 5
    elif [[ $timeouts -gt 0 ]] || grep TIMOUT rt_out* rt_err* &>/dev/null; then
        Save_res hangs $1 Timeout
        let timeouts=timeouts+1
    elif grep 'java.lang.ExceptionInInitializerError' rt_err* &> /dev/null; then # NPE during class initialization - too complex dependencies
        return 7
    elif [[ $empty -ne 0 ]]; then
        Save_res crashes $1 Crash
        let crashes=crashes+1
    elif grep "Fatal signal" rt_err* | grep -v 'libc' > /dev/null; then # compiler crash, filter out known bluetooth crashes
        Save_res crashes $1 Crash
        let crashes=crashes+1
    elif grep "fatal error" rt_outint* > /dev/null; then # Java crash
        let jcrash=jcrash+1
        return 3
    else
        ret=0
        i=0
        while [[ $i -lt $subiters ]]
        do
            [[ ${#outer_control} -eq 0 ]] && cp rt_outint rt_outint$i
            diff rt_outint$i rt_out$i &> /dev/null
            ret=$(( $ret + $? ))
            i=$(( $i + 1 ))
        done
        if [[ $ret -eq 0 ]]
        then
            [[ "$SAVE_PASSED" = "true" ]] && Save_passed_res passes $1
            return 0 # Passed 
        else
            Save_res fails $1 Failed
            let fails=fails+1
        fi
    fi
}

#--------------------------------------------------------------------------------
# returns: 0 - test complete, 1 - no JIT, 2 - VerifyError, 3 - Java crash, 4 - should never been returned, 5 - OOM, 6 - Interpreter/Java timeout, 7 - NPE during class initialization
function Run_test {
    gc_opts=""
    if [[ "$GC_EXP" == "on" ]]
    then
        back_gc=${GC_TYPES[$(($RANDOM % 3))]}
        gc=${GC_TYPES[$(($RANDOM % 3))]}
        gc_opts=$gc_opts" -Xgc:$gc -XX:BackgroundGC=$back_gc"
        gc_opts=$gc_opts" "${GC_HSPACE[$(($RANDOM % 2))]}
        [[ $(($RANDOM % 2)) -eq 0 ]] && gc_opts=$gc_opts" $GC_VERIFICATION"
        gc_thr1=$((($RANDOM % 11) + 1))
        gc_thr2=$((($RANDOM % 11) + 1))
        [[ $(($RANDOM % 2)) -eq 0 ]] && gc_opts=$gc_opts" -XX:ParallelGCThreads=$gc_thr1"
        [[ $(($RANDOM % 2)) -eq 0 ]] && gc_opts=$gc_opts" -XX:ConcGCThreads=$gc_thr2"
    fi

    if [[ "$EXTREME" != "on" ]]
    then
        if [ "$comp_fast" = "y" ]; then
            RunVM $INT_ARGS >rt_out_ref 2>rt_err_ref
            if [ $? -eq 124 ]; then
                echo "    Interpreter timeout!"
                return 6
            fi
        else
            timeout $TIME_OUT java $test_name >rt_out_ref 2>&1 # 2>rt_err_ref not working: java outputs err msgs to stdout
            if [ $? -eq 124 ]; then
                echo "    Java timeout!"
                return 6
            fi
        fi
    fi

    #echo "RunVM $VM_LIB $args $add_opts $gc_opts" > rt_cmd
    RunVM $VM_LIB $args $add_opts $gc_opts >rt_out 2>rt_err
    [[ "$EXTREME" == "on" ]] && cp rt_out rt_out_ref
    res_code=$?
    if grep -E 'VerifyError' rt_out rt_err > /dev/null; then # workaround for DEX's bug
        let vrferr=vrferr+1
        return 2
    elif grep 'OutOfMemory' rt_out rt_err > /dev/null; then # workaround for OOM
        return 5
    elif [ $res_code -eq 124 ] || grep 'TIMEOUT' rt_out &>/dev/null; then
        Save_res hangs $1 Timeout
        let timeouts=timeouts+1
    elif grep 'java.lang.ExceptionInInitializerError' rt_err &> /dev/null; then # NPE during class initialization - too complex dependencies
        return 7
    elif [ ! -s rt_out ]; then
        Save_res crashes $1 Crash
        let crashes=crashes+1
    elif grep "Fatal signal" rt_err > /dev/null; then # compiler crash
        Save_res crashes $1 Crash
        let crashes=crashes+1
    elif grep "fatal error" rt_out_ref > /dev/null; then # Java crash
        let jcrash=jcrash+1
        return 3
    elif diff rt_out_ref rt_out > /dev/null; then
        [[ "$SAVE_PASSED" = "true" ]] && Save_passed_res passes $1
        return 0 # Passed 
    else
        Save_res fails $1 Failed
        let fails=fails+1
    fi
    return 4 # the test did not pass
}
#--------------------------------------------------------------------------------
function Finish {
    cd ..
    rm -r $work_dir
    #rm -r $ANDROID_DATA
    [[ "$1" = "" ]] || Err $1
    exit
}
#--------------------------------------------------------------------------------
update=n
verify=n
res_dir=""
res_file=""
keep_dirs=n
prefix=""
comp_fast=n
test_name=Test
time_limit=0
total=0
new_build=n
add_opts=""
subtests=10
subiters=2
args=$OPT_ARGS
ulimit -c 0
apk=n
outer_control=""
MIN_TIME=20000

while [ "$1" != "" ]; do
    case $1 in
	-b|-bw|-bb|-bs)
        new_build=y
        New_build_args $1 $2
	    shift;;
	-u)
	    update=y
        ORIG_RUBY_CODE_DIR=$FILER_DIR/$2
        shift;;
	-v)
		[[ -d $2 ]] || Err "no directory to verify: $2"
	    verify=y
		source_dir=`pwd`/$2
	    shift;;
	-r)
	    res_dir=$2
		shift;;
	-kd) keep_dirs=y;;
	-p)
	    prefix=$2
	    shift;;
	-co)
	    if [ "$2" != "" ]; then
            add_opts="$add_opts -Xcompiler-option $2"
            shift
        fi
	    ;;
	-oc) add_opts="$add_opts -Xcompiler-option --compiler-backend=Optimizing";;
	-dp) add_opts="$add_opts -Xcompiler-option --disable-passes=$2"
		 shift;;
	-extreme) EXTREME=on;;
	-jit) add_opts="$add_opts -Xusejit:true -XOatFileManagerCompilerFilter:interpret-only -Xjit-block-mode";;
	-i)  comp_fast=y;;
	-no) args=$NOPT_ARGS;;
	-gc) GC_EXP=on;;
	-t)  SetTimeout $2
         shift;;
	-tn) test_name=$2
         shift;;
	-arg) add_opts="$add_opts $2"
         shift;;
	-f)  res_file=$2
		 shift;;
	-tl) time_limit=$2
		 shift;;
	-conf) conf_file=$2
	    shift;;
	-st) subtests=$2
	    shift;;
	-si) subiters=$2
	    shift;;
	-sp) SAVE_PASSED="true";;
	-mt) MIN_TIME=$2
    	    shift;;
    	-apk) apk=y;;
    	-o) outer_control="-o";;
	*)   total=$1;;
    esac
    shift
done
[[ $new_build = "y" ]] && Set_build
#--------------------------------------------------------------------------------

passes=0
vrferr=0
jcrash=0
crashes=0
fails=0
timeouts=0
invalids=0
res_path=$FILER_DIR/$res_dir

if [ "$update" = "y" ]; then
    if [ ! -d $ORIG_RUBY_CODE_DIR ]; then
        Err "rt.sh: dir to copy Ruby files from not found: $ORIG_RUBY_CODE_DIR"
    fi
    rm -r "$RUBY_CODE_DIR" &> /dev/null
    mkdir -p "$RUN_DIR"
    cp -r "$ORIG_RUBY_CODE_DIR" "$RUBY_CODE_DIR"
    echo "Ruby files updated"
fi

if [ -d $res_path/hangs -o -d $res_path/crashes -o -d $res_path/fails -o -d $res_path/errors ]; then
    if [ "$keep_dirs" = "n" ]; then
        Err "rt.sh: remove dirs: hangs, crashes, fails and errors from $res_path"
    fi
fi

echo --------------------------------------
echo Build under test: $BRANCH $BUILD $BITS
echo --------------------------------------

prefix_="/tmp"
[[ -d /export/ram ]] && prefix_="/export/ram/tmp"
mkdir -p $prefix_ &> /dev/null
work_dir=$(mktemp -d --tmpdir=$prefix_)
cd $work_dir

if [ "$verify" = "y" ]; then
    ulimit -c 0
    for dir in `ls $source_dir`; do
        [[ -d $source_dir/$dir ]] || continue
        rm $FILES_OF_INTEREST > /dev/null 2>&1
        cp $source_dir/$dir/*.java $source_dir/$dir/*.class $source_dir/$dir/*.dex .
        Run_test $dir
        echo test $dir done
    done
    Finish
fi

if [ $total -lt 1 -a $time_limit -lt 1 ]; then
    Finish "invalid number of iterations: $total or time limit: $time_limit"
fi

iters=0
fails_in_a_row=0
while [ $iters != $total ]; do
    problem=no
    let iters=iters+1
    let perc=$iters*100/$total
    rm $FILES_OF_INTEREST > /dev/null 2>&1
    if [[ "$apk" == "y" ]]
    then
        rm -f `find "$APK_DIR/Fuzzer/src/com/intel/fuzzer" -name 'Test*java' | grep -E 'Test[0-9]*.java'` &>> rt_apk
        lines=0
        counter=0
        while [[ $counter -lt $subtests ]]
        do
            counter=$(($counter + 1))
            echo "ruby -I$RUBY_CODE_DIR $RUBY_CODE_DIR/Fuzzer.rb -f $RUBY_CODE_DIR/$conf_file" -p 'com.intel.fuzzer' -n "Test$counter" >> rt_cmd
            ruby -I$RUBY_CODE_DIR $RUBY_CODE_DIR/Fuzzer.rb -f $RUBY_CODE_DIR/$conf_file -p 'com.intel.fuzzer' -n "Test$counter" $outer_control > "$APK_DIR/Fuzzer/src/com/intel/fuzzer/Test$counter.java"
            cntr=`cat "$APK_DIR/Fuzzer/src/com/intel/fuzzer/Test$counter.java" | wc -l`
            lines=$(( $lines + $cntr ))
        done
        cp -r "$APK_DIR/Fuzzer/src/com/intel/fuzzer" ./src
        bash "$FILER_DIR/build-apk.sh" "$FILER_DIR" &>> rt_apk
        if [ $? -ne 0 ]; then
            Save_res errors $iters Invalid
            let invalids=invalids+1
            run_res=1
        else
            Run_test_apk $iters
            run_res=$?
            if [ $run_res -eq 2 ]; then  # invalid test run: VerifyError
                problem="VerifyError"
            elif [ $run_res -eq 3 ]; then  # invalid test run: Java crash
                problem="Java crash"
            elif [ $run_res -eq 5 ]; then  # invalid test run: OOM
                problem="OOM"
            elif [ $run_res -eq 6 ]; then  # invalid test run: Timeout
                problem="Reference run timeout"
            elif [ $run_res -eq 7 ]; then  # invalid test run: java.lang.ExceptionInInitializerError
                problem="NPE during initialization"
            fi
        fi
    else
        echo "ruby -I$RUBY_CODE_DIR $RUBY_CODE_DIR/Fuzzer.rb -f $RUBY_CODE_DIR/$conf_file" >> rt_cmd
        ruby -I$RUBY_CODE_DIR $RUBY_CODE_DIR/Fuzzer.rb -f $RUBY_CODE_DIR/$conf_file > $test_name.java
        lines=`cat $test_name.java | wc -l`
        cp $RUBY_CODE_DIR/FuzzerUtils*.class .
        javac $test_name.java
        if [ $? -ne 0 ]; then
            Save_res errors $iters Invalid
            let invalids=invalids+1
            run_res=1
        else
            $DX --dex --output=classes.dex *.class
            Run_test $iters
            run_res=$?
            if [ $run_res -eq 2 ]; then  # invalid test run: VerifyError
                problem="VerifyError"
            elif [ $run_res -eq 3 ]; then  # invalid test run: Java crash
                problem="Java crash"
            elif [ $run_res -eq 5 ]; then  # invalid test run: OOM
                problem="OOM"
            elif [ $run_res -eq 6 ]; then  # invalid test run: Timeout
                problem="Reference run timeout"
            elif [ $run_res -eq 7 ]; then  # invalid test run: java.lang.ExceptionInInitializerError
                problem="NPE during initialization"
            fi
        fi
    fi
    if [ $run_res -eq 0 ]; then
        fails_in_a_row=0
    else
        let fails_in_a_row=fails_in_a_row+1
        [[ $fails_in_a_row -eq 10 ]] && Finish "10 failures in a row"
    fi
    if [ "$problem" != "no" ]; then
        echo "     $prefix$iters: $problem ($lines) [$vrferr VerifyError, $jcrash Java crashes]"
        let iters=iters-1
    else
        echo "$prefix$iters ($lines) [$crashes crashes, $fails fails, $timeouts hangs, $invalids errors] - ${perc}%/$total"
    fi
done

if [ "$res_file" != "" ]; then
    echo "$prefix $total: $crashes crashes, $fails fails, $timeouts hangs, $invalids errors, $vrferr VerifyError, $jcrash Java crashes" >>$res_path/$res_file
fi

Finish
