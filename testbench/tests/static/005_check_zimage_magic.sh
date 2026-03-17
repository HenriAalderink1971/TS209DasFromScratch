#!/bin/bash
set -e

ZIMAGE="/workspace/artifacts/qemu/zImage"

echo "[TEST] Checking zImage magic in artifacts: $ZIMAGE"

if [ ! -f "$ZIMAGE" ]; then
    echo "[FAIL] zImage not found at $ZIMAGE"
    exit 1
fi

# First 4 bytes of a valid ARM zImage: 0x016f2818
MAGIC=$(xxd -p -l 4 -s 0x24 "$ZIMAGE")

if [ "$MAGIC" != "18286f01" ]; then
    echo "[FAIL] zImage magic mismatch: expected 016f2818, got $MAGIC"
    exit 1
fi

echo "[PASS] zImage magic is correct"
