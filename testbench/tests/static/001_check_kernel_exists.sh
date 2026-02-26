#!/bin/bash
set -e

KERNEL="/workspace/artifacts/ts209/uImage"

echo "[TEST] Checking that kernel image exists: $KERNEL"

if [ ! -f "$KERNEL" ]; then
    echo "[FAIL] Kernel image not found"
    exit 1
fi

echo "[PASS] Kernel image exists"

