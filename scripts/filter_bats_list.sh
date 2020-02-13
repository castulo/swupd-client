#!/bin/bash
# Filter a list of jobs
# Parameter 1: Job number
# Parameter 2: Number of jobs
#
# To test if any test is missing:
# for i in $(seq $NUM_JOBS); do
#    ./scripts/filter_bats_list2.sh $i $NUM_JOBS >> list;
# done
#
# Average test time per group of tests (rounding up or down to the closer value):
#  3rd-party = 4.5 ~ 4 s/t
#  repair = 3.4 ~ 3 s/t
#  diagnose = 3 s/t
#  signature = 2.5 ~ 2 s/t
#  update = 2.3	~ 2 s/t
#  bundleremove = 2.1 ~ 2 s/t
#  verify-legacy = 2 s/t
#  checkupdate = 1.9 ~ 2 s/t
#  bundlelist = 1.8 ~ 2 s/t
#  bundleadd = 1.5 ~ 1 s/t
#  bundleinfo = 1.4 ~ 1 s/t
#  os-install = 1.4 ~ 1 s/t
#  autoupdate = 1 s/t
#  usability = 0.9 ~ 1 s/t
#  search = 0.8 ~ 1 s/t
#  info = 0.8 ~ 1 s/t
#  mirror = 0.3 s/t ~ 1 s/t
#  hashdump = 0.3 ~ 1 s/t
#

JOB_NUM=$(($1 - 1))
NUM_JOBS=$2

average() {
    i=$1
    TESTS=$2

	# start with the special cases
	if [[ $i == *'UPD025'* ]]; then
		TESTS=$((TESTS * 120))
	elif [[ $i == *'/3rd-party/'* ]]; then
		TESTS=$((TESTS * 4))
	elif [[ $i == *'/repair/'* || $i == *'/diagnose/'* ]]; then
		TESTS=$((TESTS * 3))
	elif [[ $i == *'/signature/'* || $i == *'/update/'* || $i == *'/bundleremove/'* || $i == *'/verify-legacy/'* || $i == *'/checkupdate/'* || $i == *'/bundlelist/'* ]]; then
		TESTS=$((TESTS * 2))
	fi
    echo $TESTS
}

# calculate average time of running all tests serially
TOTAL_TEST_TIME=0
for i in $(find test/functional/ -name *.bats ); do
    TESTS_NUM=$(grep "^@test" $i | wc -l)
    TEST_TIME_AVG=$(average $i $TESTS_NUM)
    TOTAL_TEST_TIME=$((TOTAL_TEST_TIME + TEST_TIME_AVG))
done

# average time a job should run
TIME_PER_JOB="$((TOTAL_TEST_TIME/NUM_JOBS))"

# range for the current job
START="$(((JOB_NUM * TIME_PER_JOB) + 1))"
END="$(((JOB_NUM + 1) * TIME_PER_JOB))"

# build the list of tests for the job
TIME_SPENT=0
for i in $(find test/functional/ -name *.bats | sort ); do
    TESTS_NUM=$(grep "^@test" $i | wc -l)
    TEST_TIME_AVG=$(average $i $TESTS_NUM)

    TIME_SPENT=$((TIME_SPENT + TEST_TIME_AVG))

    if [ $TIME_SPENT -gt $END ]; then
        break
    fi

    if [ $TIME_SPENT -ge $START ]; then
        echo -n "$i "
    fi

done
