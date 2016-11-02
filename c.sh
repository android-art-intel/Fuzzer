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
# Run given test with ART in host mode or with Java
# Arguments:
#    <path> - path to directory of a test
#    -b  <branch name> - use the build of the given branch with curr WW and bits. Example: aosp-master
#    -bw <WW> - use the build of the curr branch with given WW and same bits. Example: WW35
#    -bb <bits> - use the build of the curr branch with curr WW and given bits. Values: 32 or 64
#    -t <integer> - timeout in seconds
#    -c  - compile test Java source files before running the test
#    -comp - run the test by Java and ART in host mode and compare results
#    -j  - run the test with Java
#    -i  - run the test in interpreter mode. In -comp mode:
#          compare test results with interpreter mode instead of Java
#    -co <option> - compiler additional options
#    -dp <pass> - disable optimization pass
#    -pr - print compiler traces for all passes
#    -oc - run optimizing compiler
#    -qc - run quick compiler
#    -o <option> - runtime additional option
#    -n <int> - run the test <int> times
#    -dbg - run debug version of Android VM (-XXlib:libartd.so)
#    -no  - run the test without optimizations
#--------------------------------------------------------------------------------

source common.sh

test_dir="missed"
run_mode=-dj
num_iters=1
compile_flag=n
compare_flag=n
add_opts=""
new_build=n
args=$OPT_ARGS

while [ "$1" != "" ]; do
    case $1 in
	-b|-bw|-bb|-bs)
        new_build=y
        New_build_args $1 $2
	    shift;;
	-t)  SetTimeout $2
         shift;;
	-c)  compile_flag=y;;
	-co)
	    if [ "$2" != "" ]; then
            add_opts="$add_opts -Xcompiler-option $2"
            shift
        fi
	    ;;
	-oc) add_opts="$add_opts -Xcompiler-option --compiler-backend=Optimizing";;
	-qc) add_opts="$add_opts -Xcompiler-option --compiler-backend=Quick";;
	-dp) add_opts="$add_opts -Xcompiler-option --disable-passes=$2"
		 shift;;
	-pr) add_opts="$add_opts -Xcompiler-option --print-all-passes";;
	-o)  add_opts="$add_opts $2"
		 shift;;
	-n)  num_iters=$2
		 shift;;
	-j|-i) run_mode=$1;;
	-comp) compare_flag=y;;
	-dbg)  add_opts="$add_opts -XXlib:libartd.so";;
	-ndbg)  add_opts="$add_opts -XXlib:libart.so";;
	-no)   args=$NOPT_ARGS;;
	*)     test_dir=$1;;
    esac
    shift
done
[[ $new_build = "y" ]] && Set_build
[[ -d $test_dir ]] || Err "no test to run: $test_dir"
[[ $num_iters -lt 1 ]] && Err "invalid number of iterations: $num_iters"
#--------------------------------------------------------------------------------

cd $test_dir

if [ "$compile_flag" = "y" ]; then
    javac *.java
    $DX --dex --output=classes.dex *.class
fi

if [ "$compare_flag" = "y" ]; then
    if [ "$run_mode" = "-i" ]; then
        RunVM $INT_ARGS >out_ref 2>err_ref #2>/dev/null
    else
        java Test >out_ref 2>&1
    fi
fi

iter=0
while [ $iter != $num_iters ]; do
    let iter=iter+1
    if [ "$run_mode" = "-j" ]; then
        java Test
        continue
    fi
    if [ "$compare_flag" = "y" ]; then
        RunVM $args $add_opts >out 2>err
        #if grep "Fatal signal" err > /dev/null; then # compiler crash
        grep "Fatal signal" err # search for compiler crash
        diff out_ref out
    else
        if [ "$run_mode" = "-i" ]; then
            args=$INT_ARGS
        fi
        RunVM $args $add_opts
    fi
done

#rm -r $ANDROID_DATA
exit $RunVM_res
