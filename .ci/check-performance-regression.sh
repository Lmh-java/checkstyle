#!/bin/bash

set -x
MAX_DIFFERENCE=10

# parse benchmark result
parse_benchmark_result() {
  BENCHMARK_PATH=$1
  MEMORY=$(awk '/Average Memory Usage:/ {print $4}' "$BENCHMARK_PATH")
  EXECUTION_TIME=$(awk '/Average Execution Time:/ {print $4}' "$BENCHMARK_PATH")

  local RESULT_ARRAY=($MEMORY $EXECUTION_TIME)
  echo "${RESULT_ARRAY[@]}"
}

# compare baseline and patch benchmarks
compare_results() {
  # Calculate percentage difference for memory usage
  MEMORY_DIFFERENCE=$(echo "scale=4; ((${PATCH[0]} - ${BASELINE[0]}) / ${BASELINE[0]}) * 100" | bc)
  echo "Memory Usage Difference: $MEMORY_DIFFERENCE%"

  # Calculate percentage difference for execution time
  EXECUTION_TIME_DIFFERENCE=$(echo "scale=4; ((${PATCH[1]} - ${BASELINE[1]}) / ${BASELINE[1]}) * 100" | bc)
  echo "Execution Time Difference: $EXECUTION_TIME_DIFFERENCE%"

  # Check if differences exceed the maximum allowed difference
  if (( $(echo "$MEMORY_DIFFERENCE > $MAX_DIFFERENCE" | bc -l) )) || (( $(echo "$EXECUTION_TIME_DIFFERENCE > $MAX_DIFFERENCE" | bc -l) )); then
    echo "Differences exceed the maximum allowed difference (${MAX_DIFFERENCE}%)!"
    exit 1
  else
    echo "Differences are within the maximum allowed difference."
    exit 0
  fi
}

# parse baseline benchmark
BASELINE=($(parse_benchmark_result "./.ci/baseline_benchmark.txt"))

# package patch
JAR_VERSION=$(grep -oP '<version>\K[^<]+' pom.xml)
export MAVEN_OPTS='-Xmx2000m'
mvn -e --no-transfer-progress -Passembly,no-validations package

# run benchmark and parse result
sh ./.ci/run-benchmark.sh "./target/checkstyle-${JAR_VERSION}-all.jar"
PATCH=($(parse_benchmark_result "./patch_benchmark.txt"))

# compare two metrics
compare_results
