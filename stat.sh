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
# Collect statistics on how given test runs on various configurations. Arguments:
# -t <int> - time limit in seconds (default: 30)
# -v       - verbose mode:
# -x       - extra runs: try older builds
# <path>   - path to the dir containing the test or multiple test dirs
#--------------------------------------------------------------------------------

source common.sh

one_test="no"

time_limit=30
root_dir=""
verbose=no
extra=no
test_count=0

while [ "$1" != "" ]; do
    case $1 in
    -v) verbose=yes;;
    -x) extra=yes;;
    -t) time_limit=$2
        shift;;
    *)  root_dir=$1;;
    esac
    shift
done

[[ -d $root_dir ]] || Err "test dir not found: $root_dir"
[[ -f $root_dir/Test.java ]] && one_test="yes"

#--------------------------------------------------------------------------------
function Run_test {
    prefix_="/tmp"
    [[ -d /export/ram ]] && prefix_="/export/ram/tmp"
    mkdir -p $prefix_ &> /dev/null
    export res_file=$(mktemp --tmpdir=$prefix_)
    bash c.sh $test_dir -t $time_limit -comp -b $1 -bw $2 -bb $3 $4 > $res_file 2>&1
    if [ "$verbose" = "yes" ]; then
        echo ========================================================= $@
        cat $res_file
    elif [ -s $res_file ]; then
        echo $@
    fi
    rm $res_file 2>/dev/null
}
#--------------------------------------------------------------------------------
# $1 - branch name
# $2 - builds list
# $3 ... - list of argument sets
function Run_branch {
    [[ "$verbose" = "yes" ]] && echo -e "\n                *** $1 ***\n"
    br=$1
    blist="$2"
    shift; shift
    alist=$@
    if [ "$extra" = "no" ]; then
        set -- $blist
        blist="$1 $2 $3 $4"
    fi
    for build in $blist; do
        for arg_str in $alist; do
            args=`echo $arg_str | sed 's/\./ /g'`
            ulimit -c 0
            Run_test $br $build $args
        done
    done
}
#--------------------------------------------------------------------------------
# Run one test with each of all options defined for disabling optimization passes
# $1 - test dir path
function Run_series {
    test_dir=$1

    Run_branch aosp-master "$AOSP_MASTER_BUILDS"       "32.-oc" "64.-oc" "32.-qc" "64.-qc"
#   Run_branch aosp-master-other "$AOSP_MASTER_OTHER_BUILDS"       "32.-oc" "64.-oc" "32.-qc" "64.-qc"

    let test_count=test_count+1
}
#--------------------------------------------------------------------------------

if [ "$one_test" = "yes" ]; then
    Run_series $root_dir
else
    for tdir in `ls $root_dir`; do
        echo " "
        echo "---------------------------------------------------------------------- Test $tdir"
        Run_series $root_dir/$tdir
    done
fi
echo "Statistics collected for $test_count tests in $root_dir" >&2
