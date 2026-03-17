#!/bin/bash -x
#set -e

QEMU_KERNEL="/workspace/artifacts/qemu/zImage"
QEMU_DTB="/workspace/artifacts/qemu/versatile-pb.dtb"
INITRD="/workspace/artifacts/initramfs.cpio.gz"

echo "[QEMU] Using kernel: $QEMU_KERNEL"
echo "[QEMU] Using initrd: $INITRD"
echo "[QEMU] Using DTB:    $QEMU_DTB"

# DTB must already be built by kernel.mk
#if [ ! -f "$QEMU_DTB" ]; then
#    echo "[QEMU] ERROR: DTB missing. Run: make kernel-#qemu-build"
#    exit 1
#fi

QEMU_DEBUG=""
QEMU_REDIRECT=""
if [ -n "$QEMU_GDB" ]; then
    QEMU_DEBUG="-S -gdb tcp::1234"

fi

UART_PREFIX="/testbench/uart"
rm -f "${UART_PREFIX}" "${UART_PREFIX}.in" "${UART_PREFIX}.out"
UART_FILE="${UART_PREFIX}.log"
if [ -n "$QEMU_SHELL" ]; then
    QEMU_UART="-chardev stdio,mux=on,id=uart0 \
               -mon chardev=uart0,mode=readline \
               -serial chardev:uart0"
else
    QEMU_UART="-serial chardev:uart0 -chardev file,id=uart0,path=$UART_FILE"
fi

exec qemu-system-arm \
    -M versatilepb \
    -cpu arm926 \
    -kernel "$QEMU_KERNEL" \
    -dtb $QEMU_DTB \
    -initrd "$INITRD" \
    -nographic \
    $QEMU_UART \
    -audio none \
    -semihosting-config enable=on,target=native \
    $QEMU_DEBUG \
    $QEMU_EXTRA \
    -append "console=ttyAMA0,115200 earlycon=pl011,0x101f1000 rdinit=/init"

