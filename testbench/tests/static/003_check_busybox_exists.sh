#!/bin/bash
set -e

BUSYBOX="/workspace/sysroot/bin/busybox"

echo "[TEST] Checking BusyBox binary: $BUSYBOX"

if [ ! -f "$BUSYBOX" ]; then
    echo "[FAIL] BusyBox binary not found"
    exit 1
fi

if [ ! -x "$BUSYBOX" ]; then
    echo "[FAIL] BusyBox binary is not executable"
    exit 1
fi

echo "[PASS] BusyBox binary exists and is executable"
