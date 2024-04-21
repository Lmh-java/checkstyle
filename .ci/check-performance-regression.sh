#!/bin/bash

set -e

# max difference tolerance in %
THRESHOLD_PERCENTAGE=10
# baseline of execution time in seconds
BASELINE_SECONDS=415.72

# sample project path
SAMPLE_PROJECT="./.ci-temp/jdk17"
CONFIG_FILE="./config/benchmark-config.xml"

# execute a command and time it
# $TEST_COMMAND: command being timed
time_command() {
  # execute the command with time
  local EXECUTION_SECONDS=$(command time -f "%e" "$@" 1>result.tmp 2>&1) 2>&1

  echo "${EXECUTION_SECONDS}"
}

# execute the benchmark a few times to calculate the average metrics
# $JAR_PATH: path of the jar file being benchmarked
execute_benchmark() {
  local JAR_PATH=$1
  if [ -z "$JAR_PATH" ]; then
      echo "Missing JAR_PATH as an argument."
      exit 1
  fi

  local TOTAL_SECONDS=0
  local NUM_EXECUTIONS=1

  [ ! -d "$SAMPLE_PROJECT" ] &&
    echo "Directory $SAMPLE_PROJECT DOES NOT exist." | exit 1

  for ((i = 0; i < NUM_EXECUTIONS; i++)); do
    local CMD=(java -jar "$JAR_PATH" -c "$CONFIG_FILE" \
      -x .git -x module-info.java "$SAMPLE_PROJECT")
    local BENCHMARK=($(time_command "${CMD[@]}"))
    TOTAL_SECONDS=$(echo "$TOTAL_SECONDS + $BENCHMARK" | bc)
  done

  # average execution time in patch
  local AVERAGE_IN_SECONDS=$(echo "scale=2; $TOTAL_SECONDS / $NUM_EXECUTIONS" | bc)
  echo "$AVERAGE_IN_SECONDS"
}

# compare baseline and patch benchmarks
# $EXECUTION_TIME_SECONDS execution time of the patch
compare_results() {
  local EXECUTION_TIME_SECONDS=$1
  if [ -z "$EXECUTION_TIME_SECONDS" ]; then
        echo "Missing EXECUTION_TIME_SECONDS as an argument."
        exit 1
    fi
  # Calculate percentage difference for execution time
  local DEVIATION_IN_SECONDS=$(echo "scale=4; \
    ((${EXECUTION_TIME_SECONDS} - ${BASELINE_SECONDS}) / ${BASELINE_SECONDS}) * 100" | bc)
  echo "Execution Time Difference: $DEVIATION_IN_SECONDS%"

  # Check if differences exceed the maximum allowed difference
  if (( $(echo "$DEVIATION_IN_SECONDS > $THRESHOLD_PERCENTAGE" | bc -l) )); then
    echo "Difference exceeds the maximum allowed difference (${DEVIATION_IN_SECONDS}% \
     > ${THRESHOLD_PERCENTAGE}%)!"
    exit 1
  else
    echo "Difference is within the maximum allowed difference (${DEVIATION_IN_SECONDS}% \
     <= ${THRESHOLD_PERCENTAGE}%)."
    exit 0
  fi
}

# package patch
export MAVEN_OPTS='-Xmx2000m'
mvn -e --no-transfer-progress -Passembly,no-validations package

# start benchmark
echo "Benchmark launching..."
AVERAGE_IN_SECONDS="$(execute_benchmark "$(find "./target/" -type f -name "checkstyle-*-all.jar")")"
echo "===================== BENCHMARK SUMMARY ===================="
echo "Execution Time Baseline: ${BASELINE_SECONDS} s"
echo "Average Execution Time: ${AVERAGE_IN_SECONDS} s"
echo "============================================================"

# show the command execution result
cat result.tmp

# compare result with baseline
compare_results "AVERAGE_IN_SECONDS"
exit $?
