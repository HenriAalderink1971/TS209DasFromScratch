BR_DIR        := buildroot
LINUX_DIR     := linux
ARTIFACTS     := artifacts
CONFIG_DIR    := config

DTS_NAME      := orion5x-qnap-ts209pro2.dts
DTS_SRC       := $(CONFIG_DIR)/dts/$(DTS_NAME)
DTS_DST       := $(LINUX_DIR)/arch/arm/boot/dts/$(DTS_NAME)

ROOT          := $(shell pwd)
TOOLCHAIN     := $(ROOT)/$(BR_DIR)/output/host/usr/bin/arm-buildroot-linux-musleabi-

JOBS          := 1
KLOADADDR     := 0x00008000

ZIMAGE        := $(LINUX_DIR)/arch/arm/boot/zImage
DTB           := $(LINUX_DIR)/arch/arm/boot/dts/$(DTS_NAME)
ZIMAGE_DTB    := $(ARTIFACTS)/zImage-dtb
UIMAGE        := $(ARTIFACTS)/uImage

all: notes kernel initrd

notes:
	pandoc notes.md -o $(ARTIFACTS)/notes.html

buildroot:
	cd $(BR_DIR) && make BR2_EXTERNAL=../configs defconfig && make

.PHONY: dts-link
dts-link:
	@if [ ! -L "$(DTS_DST)" ]; then \
		echo "Creating symlink for DTS..."; \
		ln -sf /workspace/$(DTS_SRC) $(DTS_DST); \
	else \
		echo "DTS symlink already exists."; \
	fi

# ------------------------------------------------------------
# Kernel build with appended DTB
# ------------------------------------------------------------

kernel-build: buildroot dts-link
	cd $(LINUX_DIR) && \
	make ARCH=arm CROSS_COMPILE=$(TOOLCHAIN) orion5x_defconfig && \
	make ARCH=arm CROSS_COMPILE=$(TOOLCHAIN) LOADADDR=$(KLOADADDR) zImage -j$(JOBS) && \
	make ARCH=arm CROSS_COMPILE=$(TOOLCHAIN) dtbs -j$(JOBS)

append-dtb: kernel-build
	cat $(ZIMAGE) $(DTB) > $(ZIMAGE_DTB)

uimage-appended: append-dtb
	mkimage -A arm -O linux -T kernel -C none \
		-a $(KLOADADDR) -e $(KLOADADDR) \
		-n "Linux with appended DTB" \
		-d $(ZIMAGE_DTB) $(UIMAGE)

kernel: uimage-appended
	@echo "Kernel with appended DTB built at $(UIMAGE)"

# ------------------------------------------------------------
# Initrd
# ------------------------------------------------------------

initrd: buildroot
	cd $(BR_DIR)/output/images && \
	find . | cpio -H newc -o | gzip > rootfs.cpio.gz
	mkimage -A arm -O linux -T ramdisk -C gzip \
		-d $(BR_DIR)/output/images/rootfs.cpio.gz $(ARTIFACTS)/uInitrd

# ------------------------------------------------------------
# Cleanup
# ------------------------------------------------------------

clean:
	rm -rf $(ARTIFACTS)/*

