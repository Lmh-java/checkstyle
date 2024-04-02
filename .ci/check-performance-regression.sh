#!/bin/bash

set -e

# max difference tolerance in %
MAX_DIFFERENCE=10
# baseline of execution time in second
EXECUTION_TIME_BASELINE=415.72

# sample project path
SAMPLE_PROJECT="./.ci-temp/jdk17"
CONFIG_FILE="./config/benchmark-config.xml"

# run a command and time it
# $TEST_COMMAND: command being timed
time_command() {
  # Run the command with time
  local TIME_OUTPUT=$(command time -p "$@" 2>&1)
  # Extract execution time
  local EXECUTION_TIME=$(echo "$TIME_OUTPUT" | awk '/real/ {print $2}')

  echo "${EXECUTION_TIME}"
}

# run the benchmark a few times to calculate the average metrics
# $JAR_PATH: path of the jar file being benchmarked
run_benchmark() {
  local JAR_PATH=$1
  if [ -z "$JAR_PATH" ]; then
      echo "Missing JAR_PATH as an argument."
      exit 1
  fi

  local TOTAL_TIME=0
  local NUM_RUNS=3

  [ ! -d "$SAMPLE_PROJECT" ] &&
    echo "Directory $SAMPLE_PROJECT DOES NOT exists." | exit 1

  for ((i = 1; i <= NUM_RUNS; i++)); do
    local CMD=(java -jar "$JAR_PATH" -c "$CONFIG_FILE" \
      -x .git -x module-info.java "$SAMPLE_PROJECT")
    local BENCHMARK=($(time_command "${CMD[@]}"))
    TOTAL_TIME=$(echo "$TOTAL_TIME + ${BENCHMARK}" | bc)
  done

  # average execution time in patch
  local AVG_TIME=$(echo "scale=2; $TOTAL_TIME /   $NUM_RUNS" | bc)
  echo "$AVG_TIME"
}

# compare baseline and patch benchmarks
# $EXECUTION_TIME execution time of the patch
compare_results() {
  local EXECUTION_TIME=$1
  if [ -z "$EXECUTION_TIME" ]; then
        echo "Missing EXECUTION_TIME as an argument."
        exit 1
    fi
  # Calculate percentage difference for execution time
  local EXECUTION_TIME_DIFFERENCE=$(echo "scale=4; \
    ((${EXECUTION_TIME} - ${EXECUTION_TIME_BASELINE}) / ${EXECUTION_TIME_BASELINE}) * 100" | bc)
  echo "Execution Time Difference: $EXECUTION_TIME_DIFFERENCE%"

  # Check if differences exceed the maximum allowed difference
  if (( $(echo "$EXECUTION_TIME_DIFFERENCE > $MAX_DIFFERENCE" | bc -l) )); then
    echo "Difference exceeds the maximum allowed difference (${EXECUTION_TIME_DIFFERENCE}% \
     > ${MAX_DIFFERENCE}%)!"
    exit 1
  else
    echo "Difference is within the maximum allowed difference (${EXECUTION_TIME_DIFFERENCE}% \
     <= ${MAX_DIFFERENCE}%)."
    exit 0
  fi
}

# package patch
export MAVEN_OPTS='-Xmx2000m'
mvn -e --no-transfer-progress -Passembly,no-validations package

# run benchmark
echo "Benchmark launching..."
AVG_TIME="$(run_benchmark "$(find "./target/" -type f -name "checkstyle-*-all.jar")")"
echo "===================== BENCHMARK SUMMARY ===================="
echo "Execution Time Baseline: ${EXECUTION_TIME_BASELINE} s"
echo "Average Execution Time: ${AVG_TIME} s"
echo "============================================================"

# compare result with baseline
compare_results "$AVG_TIME"
exit $?
