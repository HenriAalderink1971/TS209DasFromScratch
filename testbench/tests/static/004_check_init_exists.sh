#!/bin/bash
set -e

INITRAMFS="/workspace/artifacts/initramfs.cpio.gz"

echo "[TEST] Checking that /init exists inside initramfs: $INITRAMFS"

if [ ! -f "$INITRAMFS" ]; then
    echo "[FAIL] initramfs.cpio.gz not found"
    exit 1
fi

# List contents and search for /init
if ! lsinitramfs "$INITRAMFS" | grep -q "^init$"; then
    echo "[FAIL] /init not found inside initramfs"
    exit 1
fi

echo "[PASS] /init exists inside initramfs"
