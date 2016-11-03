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
# Prepare given test for filing a bug. Arguments:
# <path> - test directory or root dir for test results, in which case the test 
#          with the smallest Test.java is selected
# -c - if -c then copy the test to the destination directory
# -d - copy the test together with all oher tests in the same directory
#--------------------------------------------------------------------------------

FUZZER_ROOT_DIR=<Path to the Fuzzer>

source "$FUZZER_ROOT_DIR/common.sh"

# pre-defined:
DEST_ROOT="$FUZZER_ROOT_DIR/to_file"
RES_FILE="test.tgz"
TEST_DIR_NAME="fails"
RUN_SCRIPT="run.sh"
FILES_TO_REMOVE="*/rt_* */out* */err*"
FUZZER_UTILS="FuzzerUtils.java"
FUZZER_UTILS_PATH="$FUZZER_ROOT_DIR/rb/$FUZZER_UTILS"


to_copy=n
all_dir=n

while [ "$1" != "" ]; do
    case $1 in
	-c)
        to_copy=y;;
	-d)
        to_copy=y
		all_dir=y;;
	*)
	    test=$1;;
    esac
    shift
done

[[ -d $test ]] || Err "no test dir: $test"

if [ ! -f $test/Test.java ]; then
    root=$test
    minsz=1000000
    for tdir in `ls $root`; do
        sz=$(wc -c "$root/$tdir/Test.java" | cut -f 1 -d ' ')
        if [ $sz -lt $minsz ]; then
            minsz=$sz
            test=$root/$tdir
        fi
    done
fi

dest_dir=$DEST_ROOT/`basename $test`
if [ $to_copy = "y" ]; then
    [[ -e $dest_dir ]] && Err "destination dir exists: $dest_dir"
    cp -r $test $DEST_ROOT
    echo "Test $test copied to $DEST_ROOT"
elif [ ! -d $dest_dir ]; then
    Err "no test dir: $dest_dir - need to copy (-c)"
fi

if [ $all_dir = "y" ]; then
    echo -n "Copying test dir to $dest_dir ... "
    cp -r $root $dest_dir/$TEST_DIR_NAME
    cp $DEST_ROOT/$RUN_SCRIPT $dest_dir/$TEST_DIR_NAME
    echo Done
    echo -n "Creating archive $dest_dir/$TEST_DIR_NAME.tgz ... "
    cd $dest_dir/$TEST_DIR_NAME
    rm $FILES_TO_REMOVE &> /dev/null
    cd ..
    cp ${FUZZER_UTILS_PATH} ${FUZZER_UTILS}
    tar cf - "$TEST_DIR_NAME" ${FUZZER_UTILS} | gzip -9 > $TEST_DIR_NAME.tgz
    rm -f ${FUZZER_UTILS}  &> /dev/null
    echo Done
fi

echo -n "Creating archive $dest_dir/$RES_FILE ... "
cd $dest_dir > /dev/null 2>&1
rm $RES_FILE > /dev/null 2>&1
cp ${FUZZER_UTILS_PATH} ${FUZZER_UTILS}
tar cf - *.class *.dex *.java | gzip -9 > $RES_FILE
rm -f ${FUZZER_UTILS} &> /dev/null
echo Done
