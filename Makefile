PROJECT_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
ARTIFACTS := $(PROJECT_ROOT)/artifacts

all: publish

.PHONY: clean-os
clean-os: clean-kernel clean-busybox clean-musl

.PHONY: distclean
distclean: clean-toolchain clean-kernel clean-busybox clean-musl clean-musl-download
	rm -rf $(ARTIFACTS) $(INITRAMFS_DIR)

# ------------------------------------------------------------
# Artifacts folder to hold pubishable output
# ------------------------------------------------------------
$(ARTIFACTS):
	mkdir -p $(ARTIFACTS)

# ------------------------------------------------------------
# Toolchain source versions + URLs
# ------------------------------------------------------------
export CC := gcc-9
export CXX := g++-9

GCC_VERSION      := 8.5.0
BINUTILS_VERSION := 2.34

DOWNLOAD_DIR     := $(PROJECT_ROOT)/downloads
EXTERNAL_DIR     := $(PROJECT_ROOT)/external

GCC_TARBALL      := gcc-$(GCC_VERSION).tar.xz
BINUTILS_TARBALL := binutils-$(BINUTILS_VERSION).tar.xz

GCC_URL          := https://ftp.gnu.org/gnu/gcc/gcc-$(GCC_VERSION)/$(GCC_TARBALL)
BINUTILS_URL     := https://ftp.gnu.org/gnu/binutils/$(BINUTILS_TARBALL)

# Optional: SHA256 checksums (recommended)
GCC_SHA256       := 3f5c5d1e0d3f2b8c1f4a7d6e8b9c0a1d2e3f4b5c6d7e8f9a0b1c2d3e4f5a6b7
BINUTILS_SHA256  := f00b4c8c5e3d2a1f9b8c7d6e5f4a3b2c1d0e9f8a7b6c5d4e3f2a1b0c9d8e7f6


# ------------------------------------------------------------
# Cross-compiler toolchain (binutils + gcc)
# ------------------------------------------------------------

TARGET      := arm-none-linux-gnueabi
TC_PREFIX   := $(PROJECT_ROOT)/toolchain/arm926
BINUTILS    := $(PROJECT_ROOT)/external/binutils
GCC         := $(PROJECT_ROOT)/external/gcc
SYSROOT := $(TC_PREFIX)/$(TARGET)/sysroot

export PATH := $(TC_PREFIX)/bin:$(PATH)

toolchain: $(TC_PREFIX)/bin/$(TARGET)-gcc
	@echo "Toolchain built at $(TC_PREFIX)"

$(TC_PREFIX)/bin/$(TARGET)-gcc: $(TC_PREFIX)/built-gcc-final

# ------------------------------------------------------------
# Binutils
# ------------------------------------------------------------

$(TC_PREFIX)/built-binutils:
	mkdir -p $(PROJECT_ROOT)/build/binutils
	cd $(PROJECT_ROOT)/build/binutils && \
		$(BINUTILS)/configure \
			--target=$(TARGET) \
			--prefix=$(TC_PREFIX) \
			--disable-nls \
			--disable-werror
	$(MAKE) -C $(PROJECT_ROOT)/build/binutils
	$(MAKE) -C $(PROJECT_ROOT)/build/binutils install
	touch $@

# ------------------------------------------------------------
# GCC stage1 (C only)
# ------------------------------------------------------------

$(TC_PREFIX)/built-gcc-stage1: $(TC_PREFIX)/built-binutils
	mkdir -p $(PROJECT_ROOT)/build/gcc-stage1
	cd $(PROJECT_ROOT)/build/gcc-stage1 && \
		$(GCC)/configure \
			--target=$(TARGET) \
			--prefix=$(TC_PREFIX) \
			--enable-languages=c \
			--without-headers \
			--disable-shared \
			--disable-threads \
			--disable-libssp \
			--disable-libquadmath \
			--disable-libgomp \
			--disable-nls
	$(MAKE) -C $(PROJECT_ROOT)/build/gcc-stage1 all-gcc
	$(MAKE) -C $(PROJECT_ROOT)/build/gcc-stage1 install-gcc
	touch $@

# ------------------------------------------------------------
# GCC final (C + C++)
# ------------------------------------------------------------

$(TC_PREFIX)/built-gcc-final: $(TC_PREFIX)/built-gcc-stage1
	mkdir -p $(PROJECT_ROOT)/build/gcc-final
	cd $(PROJECT_ROOT)/build/gcc-final && \
		$(GCC)/configure \
			--target=$(TARGET) \
			--prefix=$(TC_PREFIX) \
			--with-sysroot=$(TC_PREFIX)/$(TARGET)/sysroot \
			--enable-languages=c \
			--disable-nls \
			--disable-threads \
			--disable-shared \
			--disable-libatomic \
			--disable-libgomp \
			--disable-libquadmath \
			--disable-libsanitizer \
			--disable-libvtv \
			--disable-libssp \
			--disable-libssp-override \
			--disable-libstdcxx \
			--disable-libstdc++-v3 \
			--disable-libgcov \
			--with-newlib

	$(MAKE) -C $(PROJECT_ROOT)/build/gcc-final all
	$(MAKE) -C $(PROJECT_ROOT)/build/gcc-final install
	touch $@

# ------------------------------------------------------------
# Cleanup toolchain
# ------------------------------------------------------------

# ------------------------------------------------------------
# Download + extract GCC and Binutils
# ------------------------------------------------------------

get-toolchain: $(EXTERNAL_DIR)/gcc $(EXTERNAL_DIR)/binutils
	@echo "Toolchain sources downloaded and prepared."

$(DOWNLOAD_DIR):
	mkdir -p $(DOWNLOAD_DIR)

$(EXTERNAL_DIR):
	mkdir -p $(EXTERNAL_DIR)

# ------------------------------
# Download GCC
# ------------------------------
$(DOWNLOAD_DIR)/$(GCC_TARBALL): | $(DOWNLOAD_DIR)
	@if [ ! -f $@ ]; then \
		echo "Downloading GCC $(GCC_VERSION)..."; \
		wget -O $@ $(GCC_URL); \
	fi
	@if [ -n "$(GCC_SHA256)" ]; then \
		echo "$(GCC_SHA256)  $@" | sha256sum -c -; \
	fi

$(EXTERNAL_DIR)/gcc: $(DOWNLOAD_DIR)/$(GCC_TARBALL) | $(EXTERNAL_DIR)
	rm -rf $(EXTERNAL_DIR)/gcc
	tar -xf $(DOWNLOAD_DIR)/$(GCC_TARBALL) -C $(EXTERNAL_DIR)
	mv $(EXTERNAL_DIR)/gcc-$(GCC_VERSION) $(EXTERNAL_DIR)/gcc

# ------------------------------
# Download Binutils
# ------------------------------
$(DOWNLOAD_DIR)/$(BINUTILS_TARBALL): | $(DOWNLOAD_DIR)
	@if [ ! -f $@ ]; then \
		echo "Downloading Binutils $(BINUTILS_VERSION)..."; \
		wget -O $@ $(BINUTILS_URL); \
	fi
	@if [ -n "$(BINUTILS_SHA256)" ]; then \
		echo "$(BINUTILS_SHA256)  $@" | sha256sum -c -; \
	fi

$(EXTERNAL_DIR)/binutils: $(DOWNLOAD_DIR)/$(BINUTILS_TARBALL) | $(EXTERNAL_DIR)
	rm -rf $(EXTERNAL_DIR)/binutils
	tar -xf $(DOWNLOAD_DIR)/$(BINUTILS_TARBALL) -C $(EXTERNAL_DIR)
	mv $(EXTERNAL_DIR)/binutils-$(BINUTILS_VERSION) $(EXTERNAL_DIR)/binutils


clean-toolchain:
	rm -rf $(PROJECT_ROOT)/build $(PROJECT_ROOT)/toolchain 

print-root:
	@echo PROJECT_ROOT is: \"$(PROJECT_ROOT)\"
	@echo CURDIR is: $(CURDIR)
	@echo "pwd is $(pwd)"

# ------------------------------------------------------------
# Device Tree integration
# ------------------------------------------------------------

DTS_SRC := $(PROJECT_ROOT)/config/dts/orion5x-qnap-ts209pro2.dts
DTS_DST := $(KERNEL_DIR)/arch/arm/boot/dts/orion5x-qnap-ts209pro2.dts

$(DTS_DST): $(DTS_SRC) $(KERNEL_DIR)/.config
	cp $(DTS_SRC) $(DTS_DST)

add-dtb-entry:
	@grep -q "orion5x-qnap-ts209pro2.dtb" $(KERNEL_DIR)/arch/arm/boot/dts/Makefile || \
	echo "dtb-\$$(CONFIG_ARCH_ORION5X) += orion5x-qnap-ts209pro2.dtb" >> $(KERNEL_DIR)/arch/arm/boot/dts/Makefile


#-----------------------------------------------------
# Kernel
#-----------------------------------------------------

ARCH          := arm
CROSS_COMPILE := $(TC_PREFIX)/bin/$(TARGET)-

export ARCH
export CROSS_COMPILE

KERNEL_VERSION := 5.10.228
KERNEL_TARBALL := linux-$(KERNEL_VERSION).tar.xz
KERNEL_URL     := https://cdn.kernel.org/pub/linux/kernel/v5.x/$(KERNEL_TARBALL)
KERNEL_DIR     := $(PROJECT_ROOT)/kernel/linux-$(KERNEL_VERSION)

# ------------------------------------------------------------
# Download + extract kernel
# ------------------------------------------------------------

$(DOWNLOAD_DIR)/$(KERNEL_TARBALL): | $(DOWNLOAD_DIR)
	@if [ ! -f $@ ]; then \
		echo "Downloading Linux $(KERNEL_VERSION)..."; \
		wget -O $@ $(KERNEL_URL); \
	fi

$(KERNEL_DIR): $(DOWNLOAD_DIR)/$(KERNEL_TARBALL)
	mkdir -p $(PROJECT_ROOT)/kernel
	tar -xf $< -C $(PROJECT_ROOT)/kernel

# ------------------------------------------------------------
# Kernel configuration
# ------------------------------------------------------------

$(KERNEL_DIR)/.config: $(KERNEL_DIR)
	cd $(KERNEL_DIR) && \
		$(MAKE) orion5x_defconfig

# ------------------------------------------------------------
# Kernel build
# ------------------------------------------------------------

kernel: toolchain $(KERNEL_DIR) $(KERNEL_DIR)/.config $(DTS_DST) add-dtb-entry
	cd $(KERNEL_DIR) && \
		$(MAKE) -j$$(nproc) zImage dtbs

KERNEL_HEADERS_STAMP := $(SYSROOT)/usr/include/linux/kd.h

.PHONY: kernel-headers
kernel-headers: $(KERNEL_HEADERS_STAMP)

$(KERNEL_HEADERS_STAMP): $(KERNEL_DIR)
	cd $(KERNEL_DIR) && \
		$(MAKE) mrproper && \
		$(MAKE) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) \
			headers_install \
			INSTALL_HDR_PATH=$(SYSROOT)/usr

.PHONY: clean-kernel
clean-kernel:
	rm -rf $(KERNEL_DIR)
	rm -f  $(DOWNLOAD_DIR)/$(KERNEL_TARBALL)

# ------------------------------------------------------------
# Musl build
# ------------------------------------------------------------
MUSL_VERSION := 1.2.5
MUSL_TARBALL := musl-$(MUSL_VERSION).tar.gz
MUSL_URL := https://musl.libc.org/releases/$(MUSL_TARBALL)
MUSL_DIR := $(PROJECT_ROOT)/external/musl-$(MUSL_VERSION)
MUSL_PREFIX := $(TC_PREFIX)/$(TARGET)/sysroot/usr


.PHONY: musl
musl: $(MUSL_PREFIX)/lib/libc.a

$(DOWNLOAD_DIR)/$(MUSL_TARBALL): | $(DOWNLOAD_DIR)
	wget -O $@ $(MUSL_URL)

$(MUSL_DIR): $(DOWNLOAD_DIR)/$(MUSL_TARBALL) | $(EXTERNAL_DIR)
	rm -rf $(MUSL_DIR)
	tar -xf $< -C $(EXTERNAL_DIR)


$(MUSL_PREFIX)/lib/libc.a: $(MUSL_DIR) $(TC_PREFIX)/bin/$(TARGET)-gcc
	cd $(MUSL_DIR) && \
		CC=$(CROSS_COMPILE)gcc ./configure --prefix=$(MUSL_PREFIX) --target=$(TARGET) --disable-shared --enable-static && \
		$(MAKE) && \
		$(MAKE) install
# ------------------------------------------------------------
# Musl cleanup
# ------------------------------------------------------------

.PHONY: clean-musl
clean-musl:
	rm -rf $(MUSL_DIR)
	rm -rf $(MUSL_PREFIX)/include
	rm -rf $(MUSL_PREFIX)/lib
	rm -rf $(MUSL_PREFIX)/bin
	rm -rf $(MUSL_PREFIX)/sbin

.PHONY: clean-musl-download
clean-musl-download:
	rm -f $(DOWNLOAD_DIR)/$(MUSL_TARBALL)

.PHONY: clean-musl-all
clean-musl-all: clean-musl clean-musl-download

# ------------------------------------------------------------
# Busybox build
# ------------------------------------------------------------
BUSYBOX_VERSION := 1.36.1
BUSYBOX_TARBALL := busybox-$(BUSYBOX_VERSION).tar.bz2
BUSYBOX_URL := https://busybox.net/downloads/$(BUSYBOX_TARBALL)
BUSYBOX_DIR := $(PROJECT_ROOT)/external/busybox-$(BUSYBOX_VERSION)
BUSYBOX_CONFIG := $(PROJECT_ROOT)/config/busybox/busybox.config

.PHONY: busybox
busybox: kernel-headers $(BUSYBOX_DIR)/busybox

$(BUSYBOX_DIR)/.config: $(BUSYBOX_DIR) $(BUSYBOX_CONFIG)
	cp $(BUSYBOX_CONFIG) $(BUSYBOX_DIR)/.config
	cd $(BUSYBOX_DIR) && \
		sed -i 's/^# CONFIG_STATIC is not set/CONFIG_STATIC=y/' .config && \
		sed -i 's|^CONFIG_SYSROOT=.*|CONFIG_SYSROOT="$(TC_PREFIX)/$(TARGET)/sysroot"|' .config && \
		sed -i 's|^CONFIG_EXTRA_CFLAGS=.*|CONFIG_EXTRA_CFLAGS="--sysroot=$(SYSROOT) -include $(PROJECT_ROOT)/config/busybox/musl-compat.h"|' .config && \
		yes "" | $(MAKE) oldconfig

$(DOWNLOAD_DIR)/$(BUSYBOX_TARBALL): | $(DOWNLOAD_DIR)
	wget -O $@ $(BUSYBOX_URL)

$(BUSYBOX_DIR): $(DOWNLOAD_DIR)/$(BUSYBOX_TARBALL)
	tar -xf $< -C $(PROJECT_ROOT)/external
	patch -d $(BUSYBOX_DIR) -p1 < $(PROJECT_ROOT)/config/busybox/musl-byteswap.patch

# Build BusyBox for ARM against Musl
$(BUSYBOX_DIR)/busybox: $(BUSYBOX_DIR)/.config $(MUSL_PREFIX)/lib/libc.a
	cd $(BUSYBOX_DIR) && \
		$(MAKE) -j$$(nproc) CROSS_COMPILE=$(CROSS_COMPILE)

# ------------------------------------------------------------
# BusyBox cleanup
# ------------------------------------------------------------

.PHONY: clean-busybox
clean-busybox:
	rm -rf $(BUSYBOX_DIR)
	rm -f  $(DOWNLOAD_DIR)/$(BUSYBOX_TARBALL)

# ------------------------------------------------------------
# Initramfs generation
# ------------------------------------------------------------

INITRAMFS_DIR := $(PROJECT_ROOT)/build/initramfs
INITRAMFS_CPIO := $(ARTIFACTS)/initramfs.cpio.gz

$(INITRAMFS_DIR):
	mkdir -p $(INITRAMFS_DIR)/bin
	mkdir -p $(INITRAMFS_DIR)/sbin
	mkdir -p $(INITRAMFS_DIR)/etc
	mkdir -p $(INITRAMFS_DIR)/proc
	mkdir -p $(INITRAMFS_DIR)/sys
	mkdir -p $(INITRAMFS_DIR)/usr/bin
	mkdir -p $(INITRAMFS_DIR)/usr/sbin

$(INITRAMFS_DIR)/bin/busybox: $(BUSYBOX_DIR)/busybox | $(INITRAMFS_DIR)
	cp $(BUSYBOX_DIR)/busybox $(INITRAMFS_DIR)/bin/
	chmod +x $(INITRAMFS_DIR)/bin/busybox
	ln -sf busybox $(INITRAMFS_DIR)/bin/sh

# Create /init script
$(INITRAMFS_DIR)/init: $(INITRAMFS_DIR)
	echo '#!/bin/sh' > $(INITRAMFS_DIR)/init
	echo 'echo "*** INITRAMFS: /init has started ***"' >> $(INITRAMFS_DIR)/init
	echo 'mount -t proc none /proc' >> $(INITRAMFS_DIR)/init
	echo 'mount -t sysfs none /sys' >> $(INITRAMFS_DIR)/init
	echo 'exec /bin/sh' >> $(INITRAMFS_DIR)/init
	chmod +x $(INITRAMFS_DIR)/init

# Pack initramfs
$(INITRAMFS_CPIO): $(INITRAMFS_DIR)/bin/busybox $(INITRAMFS_DIR)/init
	cd $(INITRAMFS_DIR) && find . | cpio -H newc -o | gzip > $@

.PHONY: initramfs
initramfs: $(INITRAMFS_CPIO)
	@echo "Initramfs built at $(INITRAMFS_CPIO)"

# ------------------------------------------------------------
# U-Boot image generation
# ------------------------------------------------------------
ZIMAGE_DTB := $(KERNEL_DIR)/arch/arm/boot/zImage+dtb
DTB := $(KERNEL_DIR)/arch/arm/boot/dts/orion5x-qnap-ts209pro2.dtb

$(ZIMAGE_DTB): $(KERNEL_DIR)/arch/arm/boot/zImage $(DTB)
	cat $(KERNEL_DIR)/arch/arm/boot/zImage $(DTB) > $(ZIMAGE_DTB)

UIMAGE := $(ARTIFACTS)/uImage
UINITRD := $(ARTIFACTS)/uInitrd

$(UIMAGE): $(ZIMAGE_DTB) | $(ARTIFACTS)
	mkimage -A arm -O linux -T kernel -C none \
		-a 0x00008000 -e 0x00008000 \
		-n "Linux $(KERNEL_VERSION) for TS-209 Pro II (DT)" \
		-d $(ZIMAGE_DTB) $@

$(UINITRD): $(ARTIFACTS)/initramfs.cpio.gz | $(ARTIFACTS)
	mkimage -A arm -O linux -T ramdisk -C gzip \
		-n "Initramfs" \
		-d $(ARTIFACTS)/initramfs.cpio.gz $@
		
publish: $(UIMAGE) $(UINITRD)
	@echo "Artifacts ready in $(ARTIFACTS)"
	
deploy: publish
	./scripts/deploy_tftp.sh

boot: deploy
	@echo "Ready to boot TS-209 Pro II via TFTP"



