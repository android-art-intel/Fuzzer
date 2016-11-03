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
# Run given test or multiple tests in various configurations. Print only those when the test passes
# Arguments:
#    -b, -bw, -bb <value> - use given build.
#    -v       - verbose mode: print all the configs with PASS/FAIL indication
#    -vf      - verbose full mode: as for -v plus output of the test in each config
#    -x       - extra runs: try current and previous builds
#    -t <int> - time limit in seconds (default: 60)
#    -i       - use FI result as a golden one
#    -co      - compiler option to run the test with
#    -o <option> - runtime additional option
#    -oc      - run optimizer compiler
#    <path>   - path to the dir containing the test or multiple test dirs
#--------------------------------------------------------------------------------

source common.sh

FAKE_TEST="." # to run for listing opt passes

time_limit=30
root_dir=""
new_build=n
verbose=no
extra=no
interp_comp=""
add_opt=""
one_test="no"
spec_arg=""

while [ "$1" != "" ]; do
    case $1 in
        -b|-bw|-bb|-bs)
            New_build_args $1 $2
            shift;;
        -v)  verbose=short;;
        -vf) verbose=full;;
        -x)  extra=yes;;
        -i)  interp_comp=-i;;
        -oc) add_opt="$add_opt -oc";;
        -co|-o) add_opt="$add_opt $1 $2"
             shift;;
        -t)  time_limit=$2
             shift;;
        -sp) shift;;
        *)  root_dir=$1;;
    esac
    shift
done
[[ "$SPEC" != "" ]] && spec_arg="-bs $SPEC"
[[ -d $root_dir ]] || Err "e.sh: test dir not found: $root_dir"
[[ -f $root_dir/Test.java ]] && one_test="yes"

#--------------------------------------------------------------------------------
# Run one test with one set of options
# $1 - name of run
# $2 - options
function Run_test {
    if [ "$verbose" = "full" ]; then
        echo -e "\n--------${1}-------------------------------"
    fi
    result=done
    prefix_="/tmp"
    [[ -d /export/ram ]] && prefix_="/export/ram/tmp"
    mkdir -p $prefix_ &> /dev/null
    export res_file=$(mktemp --tmpdir=$prefix_)
    bash c.sh $test_dir -t $time_limit -comp $interp_comp -b $BRANCH -bw $BUILD -bb $BITS $spec_arg $2 $add_opt > $res_file
    [[ $? -eq 124 ]] && result=timeout
    if [ "$verbose" = "full" ]; then
        cat $res_file
        # if [ "$result" = "timeout" ]; then
            # echo "Timeout!"
        # fi
	elif [ "$verbose" = "short" ]; then
        if [ "$result" = "timeout" ]; then
            echo -e "$1\t- timeout"
        elif [ -s $res_file ]; then
            echo -e "$1\t- fail"
        else
            echo -e "$1\t-   PASS"
        fi
    elif [ ! -s $res_file ]; then
        echo $1
    fi
    rm $res_file 2>/dev/null
}
#--------------------------------------------------------------------------------
# Run one test with each of all options defined for disabling optimization passes
# $1 - test dir path
function Run_series {
    test_dir=$1
    if [ "$extra" = "yes" ]; then
        Run_test "Current build 32bit: $BRANCH $BUILD 32" "-bb 32"
        Run_test "Current build 64bit: $BRANCH $BUILD 64" "-bb 64"
        Run_test "Current build w/o opt: $BRANCH $BUILD $BITS" "-no"
    fi

    # don't exclude passes:
    required="loop_formation find_ivs"
    for opt in $pass_list; do
        [[ $required =~ $opt ]] && continue
        Run_test $opt "-dp $opt"
    done

    Run_test "Compare with interpreter"      "-i"
    LIBTMP="$VM_LIB"
    export VM_LIB="-XXlib:libart.so"
    Run_test "Non-debug"
    export VM_LIB="$LIBTMP"

    if [ "$extra" = "yes" ]; then
        case $BRANCH in
            aosp-stable)       check_builds=$AOSP_STABLE_BUILDS;;
        esac
        for bld in $check_builds; do
            ulimit -c 0
            Run_test "Build $bld" "-bw $bld"
        done
    fi
}
#--------------------------------------------------------------------------------

[[ "$verbose" = "no" ]] || tabs 52

pass_list=`bash c.sh $FAKE_TEST $spec_arg -o "-Xcompiler-option --print-pass-names" 2>&1 | grep -E ']\s+\-' | tr -d '\r' | awk -F '- ' '{print $2}' | sort -u | grep -v SideEffects`
if [[ -z "$pass_list" ]]
then
echo "Warning! Could not detect passes list. Using hardcoded one"
pass_list="BCE
GVN
GVN_after_form_bottom_loops
aur
constant_calculation_sinking
constant_folding
constant_folding_after_bce
constant_folding_after_inlining
dead_code_elimination
dead_code_elimination_final
devirtualization
devirtualization_after_inlining
find_ivs
form_bottom_loops
induction_var_analysis
inliner
instruction_simplifier
instruction_simplifier_after_bce
instruction_simplifier_before_codegen
intrinsics_recognition
licm
load_store_elimination
loadhoist_storesink
loop_formation
loop_formation_before_bottom_loops
loop_formation_before_peeling
loop_full_unrolling
loop_peeling
non_temporal_move
phi_cleanup
pure_invokes_analysis
remove_loop_suspend_checks
remove_unused_loops
select_generator
sharpening
sharpening_after_inlining
trivial_loop_evaluator
value_propagation_through_heap"
fi
if [ "$one_test" = "yes" ]; then
    Run_series $root_dir
else
    for tdir in `ls $root_dir`; do
        echo "-------------------------------------------------------- Test $tdir"
        Run_series $root_dir/$tdir
    done
fi

echo ""
echo "Experiments done for $root_dir" >&2
