#!/bin/bash
set -e

echo "[RUNNER] Starting static tests"

for test in tests/static/*.sh; do
    echo "----------------------------------------"
    echo "[RUNNER] Running $test"
    bash "$test"
done

echo "----------------------------------------"
echo "[RUNNER] Static tests completed"

echo "[RUNNER] Starting QEMU tests"

for test in tests/qemu/*.exp; do
    echo "----------------------------------------"
    echo "[RUNNER] Running $test"
    expect "$test"
done

echo "----------------------------------------"
echo "[RUNNER] All tests completed"
