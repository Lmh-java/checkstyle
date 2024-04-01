#!/bin/bash

# Check if jar path is provided
JAR_PATH=$1
if [ -z "$JAR_PATH" ]; then
    echo "Usage: $0 <target jar path>"
    exit 1
fi

# Sample project path
SAMPLE_PROJECT="./.ci/jdk21"

# run a command and time it
time_command() {
  # Run the command with time
  TEST_COMMAND=$1
  TIME_OUTPUT=$(/usr/bin/time -l $TEST_COMMAND 2>&1)
  # Extract memory usage and execution time
  MEMORY=$(echo "$TIME_OUTPUT" | awk '/maximum resident set size/ {print $1}')
  EXECUTION_TIME=$(echo "$TIME_OUTPUT" | awk '/real/ {print $1}')

  local RESULT_ARRAY=($MEMORY $EXECUTION_TIME)
  echo "${RESULT_ARRAY[@]}"
}

# run the benchmark
#run_benchmark() {
#  local BENCHMARK=($(time_command "java -jar $JAR_PATH -c default_config.xml $SAMPLE_PROJECT"))
#  echo "===================== BENCHMARK RESULT ====================="
#  echo "Memory Usage: ${BENCHMARK[0]} bytes"
#  echo "Execution Time: ${BENCHMARK[1]} s"
#  echo "============================================================"
#}
run_benchmark() {
  local TOTAL_MEMORY=0
  local TOTAL_TIME=0
  local NUM_RUNS=3

  for ((i = 1; i <= NUM_RUNS; i++)); do
    echo "Running benchmark ${i}/${NUM_RUNS}..."
    local BENCHMARK=($(time_command "java -jar $JAR_PATH -c ./.ci/benchmark-config.xml $SAMPLE_PROJECT"))
    TOTAL_MEMORY=$((TOTAL_MEMORY + BENCHMARK[0]))
    TOTAL_TIME=$(echo "$TOTAL_TIME + ${BENCHMARK[1]}" | bc)
    echo "================== BENCHMARK RESULT #${i} =================="
    echo "Memory Usage: ${BENCHMARK[0]} bytes"
    echo "Execution Time: ${BENCHMARK[1]} s"
    echo "============================================================"
  done

  local AVG_MEMORY=$((TOTAL_MEMORY / NUM_RUNS))
  local AVG_TIME=$(echo "scale=2; $TOTAL_TIME / $NUM_RUNS" | bc)

  echo "===================== BENCHMARK SUMMARY ===================="
  echo "Average Memory Usage: ${AVG_MEMORY} bytes"
  echo "Average Execution Time: ${AVG_TIME} s"
  echo "============================================================"
}

# save the benchmark result
run_benchmark | tee ./patch_benchmark.txt

