#!/bin/sh
set -e

INITRAMFS="/workspace/artifacts/initramfs.cpio.gz"

# Check archive exists
[ -f "$INITRAMFS" ] || {
    echo "FAIL: initramfs.cpio.gz not found"
    exit 1
}

# Create temp dir
TMPDIR=$(mktemp -d)
cd "$TMPDIR"

# Extract
gzip -dc "$INITRAMFS" | cpio -id --quiet

# Check required files
[ -f "./init" ] || { echo "FAIL: /init missing"; exit 1; }
[ -f "./bin/busybox" ] || { echo "FAIL: /bin/busybox missing"; exit 1; }
[ -L "./bin/sh" ] || { echo "FAIL: /bin/sh symlink missing"; exit 1; }

# Check symlink target
TARGET=$(readlink ./bin/sh)
[ "$TARGET" = "busybox" ] || { echo "FAIL: /bin/sh does not point to busybox"; exit 1; }

echo "PASS: initramfs contains busybox, sh, and init"
