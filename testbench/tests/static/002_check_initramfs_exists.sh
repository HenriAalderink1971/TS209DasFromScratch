#!/bin/bash
set -e

INITRAMFS="/workspace/artifacts/initramfs.cpio.gz"

echo "[TEST] Checking initramfs exists: $INITRAMFS"

if [ ! -f "$INITRAMFS" ]; then
    echo "[FAIL] initramfs.cpio.gz not found"
    exit 1
fi

# Validate gzip integrity
if ! gzip -t "$INITRAMFS" 2>/dev/null; then
    echo "[FAIL] initramfs.cpio.gz is corrupted"
    exit 1
fi

echo "[PASS] initramfs.cpio.gz exists and is valid"
