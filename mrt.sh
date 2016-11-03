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
# Run the Fuzzer tool through rt.sh script in multiple processes.
# Parameters:
#    -NP <int>  - number of processes to launch (default: 5)
#    -NT <int>  - number of tests to generate and run
#    -R <path>  - path to a dir for storing results
#    -P <str>   - string for forming test name prefix like this: <str>$<number of process>-.
#                 For example, "-P a" leads to prefixes a1-, a2-, ... (default: n|o|"")
#    -A <rest>  - the rest of arguments are passed to rt.sh
#    -S <int>   - generate statistics for the test runs on <int> hosts
#    -APK       - APK mode, disables multithreading
#--------------------------------------------------------------------------------

RUN_SCRIPT="bash rt.sh"
RB_UPDATE="-u rb"
SUMMARY_NAME=summary.txt
TRACE_FILE=trace
ADDRESS=<email address>

pref="r"
num_of_proc=5
tests_count=5
res_dir="mrt_unknown"
rt_args=""
rb_update=""
gen_stat=no
host_count=1
apk=""

while [ "$1" != "" ]; do
    case $1 in
	-P)	 pref=$2
	     shift;;
	-R)	 res_dir=$2
		 shift;;
	-NP) num_of_proc=$2
	     shift;;
	-NT) tests_count=$2
	     shift;;
	-A)  shift
	     rt_args=$@
	     break;;
	-APK) apk="-apk"
	      num_of_proc=1;;
    -S)  host_count=$2
		 gen_stat=yes
		 shift;;
	*)
	    echo Unexpected argument: $1
        exit;;
    esac
    shift
done

#-------------------------------------------------------------------------------- Prepare for the run
source common.sh
echo "Installing build"
./install_build.sh "${BRANCH}" "${BUILD}${SPEC}"

[[ -d $res_dir ]] || ( mkdir -p $res_dir && chmod -R 775 $res_dir )
res_file="$pref-$SUMMARY_NAME"

echo Updating Ruby files:
$RUN_SCRIPT $RB_UPDATE 2 -r $res_dir -kd $rt_args $apk

echo $tests_count tests will be run in each of $num_of_proc processes 
echo Prefix: $pref Res dir: $res_dir Arguments: $rt_args
read -p "Continue?(y/n): " ans
if [ "$ans" != "y" ]; then
    echo "The run is cancelled"
    exit
fi

#-------------------------------------------------------------------------------- Run the tool
start_time=`date`
host=`uname -n`
echo "Host:     $host
Tests:    $num_of_proc x $tests_count
Args:     $rt_args

Started  at: $start_time

" >> $res_dir/$res_file
pids=""
iters=0
while [ $iters != $num_of_proc ]; do
    let iters=iters+1
    $RUN_SCRIPT $tests_count -r $res_dir -f $res_file -p ${pref}${iters}- -kd $apk $rt_args &
    pids="$pids $!"
done
trap 'kill $pids' SIGINT SIGTERM
wait

pids=""

touch "$res_dir/$TRACE_FILE"
chmod 777 "$res_dir/$TRACE_FILE"
echo "$pref runs complete" >> $res_dir/$TRACE_FILE

end_time=`date`
echo All the test runs are complete: $num_of_proc x $tests_count, Args: $rt_args
echo Results are in $res_dir
echo -e "\n\nStarted  at: $start_time"
echo -e "\nFinished at: $end_time\n" | tee -a $res_dir/$res_file

#-------------------------------------------------------------------------------- Process results
if [ "$gen_stat" = "yes" ]; then
    echo -n "Waiting for other hosts runs to finish ... "
    while true; do
        complete=`cat $res_dir/$TRACE_FILE | wc -l`
        [[ $complete -ge $host_count ]] && break
        sleep 30s
    done
    rm $res_dir/$TRACE_FILE
    echo "all done"

    echo "Processing results ... "
    for res in $res_dir/crashes $res_dir/fails; do
        [[ -d $res ]] || continue
        let chunk_cnt=$num_of_proc #/2
        let chunk=`ls -1 $res | wc -l`/$chunk_cnt+1
        for i in $(seq 2 $chunk_cnt); do
            printf -v id "%02d" $i
            mkdir $res$id
            chmod -R 775 $res$id
            ls $res | head -$chunk | while read file; do
                mv $res/$file $res$id
            done
            bash e.sh $res$id $rt_args > $res$id-ex-$pref.txt &
            pids="$pids $!"
        done
        bash e.sh $res $rt_args > $res-ex-$pref.txt &
        pids="$pids $!"
        trap 'kill $pids' SIGINT SIGTERM
        wait
        pids=""
        for i in $(seq 2 $chunk_cnt); do
            printf -v id "%02d" $i
            bash stat.sh $res$id > $res$id-st-$pref.txt &
            pids="$pids $!"
        done
        bash stat.sh $res > $res-st-$pref.txt &
        pids="$pids $!"
        trap 'kill $pids' SIGINT SIGTERM
        wait

        cat $res[0-9][0-9]-ex-$pref.txt >> $res-ex-$pref.txt        2>/dev/null
        cat $res[0-9][0-9]-st-$pref.txt >> $res-st-$pref.txt        2>/dev/null
        rm  $res[0-9][0-9]-ex-$pref.txt $res[0-9][0-9]-st-$pref.txt 2>/dev/null
        mv  $res[0-9][0-9]/* $res 2>/dev/null
        rm  -r $res[0-9][0-9] 2>/dev/null
        perl sort.pl -pf $res-ex-$pref.txt -bf $res-st-$pref.txt > $res-sorted-$pref.txt
    done
    echo Done. Results are in $res_dir
    end_time=`date`
    echo -e "\nProcessing finished at: $end_time\n" | tee -a $res_dir/$res_file

    if [[ -d $res_dir/crashes ]] || [[ -d $res_dir/fails ]]
    then
        echo "LEGEND;Test ID;Result
TEST;generated;FAILED
TOTAL;1" > $res_dir/test-results.csv
    else
        echo "LEGEND;Test ID;Result
TEST;generated;PASSED
TOTAL;1" > $res_dir/test-results.csv
    fi
fi

#-------------------------------------------------------------------------------- Send notification
host=`uname -n`
echo "All the test runs are complete.
Results: $res_dir, $res_file

`cat $res_dir/$res_file`" | mail -s "mrt.sh: Fuzzer test run complete on $host" $ADDRESS

rm -f `find "$res_dir" -name core`
