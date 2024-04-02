#!/bin/bash

set -e

# Check if jar path is provided
JAR_PATH=$1
if [ -z "$JAR_PATH" ]; then
    echo "Usage: $0 <target jar path>"
    exit 1
fi

# Sample project path
SAMPLE_PROJECT="./.ci/jdk22"

# run a command and time it
time_command() {
  # Run the command with time
  TEST_COMMAND=$1
  TIME_OUTPUT=$(command time -p $TEST_COMMAND 2>&1)
  # Extract execution time
  EXECUTION_TIME=$(echo "$TIME_OUTPUT" | awk '/real/ {print $2}')

  local RESULT_ARRAY=($EXECUTION_TIME)
  echo "${RESULT_ARRAY[@]}"
}

run_benchmark() {
#  local TOTAL_MEMORY=0
  local TOTAL_TIME=0
  local NUM_RUNS=3

  [ ! -d "$SAMPLE_PROJECT" ] && echo "Directory $SAMPLE_PROJECT DOES NOT exists." && exit 1
  for ((i = 1; i <= NUM_RUNS; i++)); do
    echo "Running benchmark ${i}/${NUM_RUNS}..."
    local BENCHMARK=($(time_command "java -jar $JAR_PATH -c ./.ci/benchmark-config.xml $SAMPLE_PROJECT"))
    TOTAL_TIME=$(echo "$TOTAL_TIME + ${BENCHMARK[0]}" | bc)
    echo "================== BENCHMARK RESULT #${i} =================="
    echo "Execution Time: ${BENCHMARK[0]} s"
    echo "============================================================"
  done

  local AVG_TIME=$(echo "scale=2; $TOTAL_TIME / $NUM_RUNS" | bc)

  echo "===================== BENCHMARK SUMMARY ===================="
  echo "Average Execution Time: ${AVG_TIME} s"
  echo "============================================================"
}

# save the benchmark result
run_benchmark | tee ./patch_benchmark.txt
exit $?

