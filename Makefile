BR_DIR=buildroot
LINUX_DIR=linux
ARTIFACTS=artifacts

all: notes kernel initrd

notes:
    pandoc notes.md -o $(ARTIFACTS)/notes.html

buildroot:
    cd $(BR_DIR) && make BR2_EXTERNAL=../configs defconfig && make

kernel:
    cd $(LINUX_DIR) && \
    make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- \
         orion5x_defconfig && \
    make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- uImage -j$(nproc)
    cp $(LINUX_DIR)/arch/arm/boot/uImage $(ARTIFACTS)/

initrd:
    cd $(BR_DIR)/output/images && \
    find . | cpio -H newc -o | gzip > rootfs.cpio.gz
    mkimage -A arm -O linux -T ramdisk -C gzip \
        -d $(BR_DIR)/output/images/rootfs.cpio.gz $(ARTIFACTS)/uInitrd

clean:
    rm -rf $(ARTIFACTS)/*

