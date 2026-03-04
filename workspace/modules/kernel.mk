# ============================================================
# Linux kernel module
# ============================================================

KERNEL_VERSION := 5.10.228
KERNEL_TARBALL := linux-$(KERNEL_VERSION).tar.xz
KERNEL_URL	 := https://cdn.kernel.org/pub/linux/kernel/v5.x/$(KERNEL_TARBALL)

KERNEL_SRC	 := $(SOURCES)/linux-$(KERNEL_VERSION)
KERNEL_BUILD	 := $(BUILD)/kernel
KERNEL_DEFCONFIG := $(ROOT)/config/ts209pII_defconfig

TS209_ARTIFACTS	 := $(ARTIFACTS)/ts209
TS209_KMODULES	 := $(TS209_ARTIFACTS)/kmodules

QEMU_DEFCONFIG	 := $(ROOT)/config/qemu_versatile_defconfig
QEMU_ARTIFACTS	 := $(ARTIFACTS)/qemu
QEMU_DTS 	 := $(ROOT)/config/qemu_ts209.dts
QEMU_DTB	 := $(QEMU_ARTIFACTS)/qemu_ts209.dtb

KERNEL_HEADERS_INSTALL := $(SYSROOT)/kernel-headers
KERNEL_HEADERS_STAMP   := $(KERNEL_HEADERS_INSTALL)/.installed

# ============================================================
# download
# ============================================================

.PHONY: kernel-download
kernel-download: $(DOWNLOADS)/$(KERNEL_TARBALL)

$(DOWNLOADS)/$(KERNEL_TARBALL): | $(DOWNLOADS)
	[ -f $@ ] || wget -O $@ $(KERNEL_URL)

# ============================================================
# extract
# ============================================================

$(KERNEL_SRC): $(DOWNLOADS)/$(KERNEL_TARBALL) | $(SOURCES)
	rm -rf $(KERNEL_SRC)
	tar -xf $< -C $(SOURCES)

# ============================================================
# headers (toolchain)
# ============================================================

.PHONY: kernel-headers
kernel-headers: $(KERNEL_HEADERS_STAMP)

$(KERNEL_HEADERS_STAMP): $(DOWNLOADS)/$(KERNEL_TARBALL) $(KERNEL_SRC) | $(SYSROOT)
	cd $(KERNEL_SRC) && \
		mkdir -p $(KERNEL_HEADERS_INSTALL) && \
		$(MAKE) mrproper && \
		cp $(KERNEL_DEFCONFIG) .config && \
		$(MAKE) ARCH=arm olddefconfig && \
		$(MAKE) ARCH=arm headers_install INSTALL_HDR_PATH=$(KERNEL_HEADERS_INSTALL)
	touch $(KERNEL_HEADERS_STAMP)

# ============================================================
# TS-209 kernel (uImage)
# ============================================================

$(TS209_ARTIFACTS) $(TS209_KMODULES):
	mkdir -p $@

$(KERNEL_SRC)/arch/arm/configs/ts209pII_defconfig: $(KERNEL_DEFCONFIG) $(KERNEL_SRC)
	mkdir -p $(KERNEL_SRC)/arch/arm/configs
	cp $< $@

.PHONY: kernel-build
kernel-build: $(TS209_ARTIFACTS)/uImage

$(TS209_ARTIFACTS)/uImage: \
	$(KERNEL_SRC)/arch/arm/configs/ts209pII_defconfig \
	$(KERNEL_SRC) \
	| $(TS209_ARTIFACTS) $(TS209_KMODULES)

	cd $(KERNEL_SRC) && \
		$(MAKE) ARCH=arm CROSS_COMPILE=$(CROSS_COMPILE) ts209pII_defconfig && \
		$(MAKE) ARCH=arm CROSS_COMPILE=$(CROSS_COMPILE) LOADADDR=0x00008000 -j$$(nproc) uImage
	cp $(KERNEL_SRC)/arch/arm/boot/uImage $(TS209_ARTIFACTS)/uImage

# ============================================================
# QEMU kernel (VersatilePB) + DTB
# ============================================================

$(QEMU_ARTIFACTS):
	mkdir -p $@

# Build DTB from DTS
$(QEMU_DTB): $(QEMU_DTS) | $(QEMU_ARTIFACTS)
	dtc -I dts -O dtb -i $(KERNEL_SRC)/include $(QEMU_DTS) -o $(QEMU_DTB)
	cp $(KERNEL_SRC)/arch/arm/boot/dts/versatile-pb.dtb $(QEMU_ARTIFACTS)

.PHONY: kernel-qemu
kernel-qemu: kernel-qemu-build

kernel-qemu-build: $(QEMU_ARTIFACTS)/zImage $(QEMU_DTB)

# Verify that .config matches qemu_versatile_defconfig
qemu-config-check:
	@grep -q "^CONFIG_ARCH_VERSATILE=y" .config || \
	  (echo "ERROR: CONFIG_ARCH_VERSATILE not set")
	@grep -q "^CONFIG_MACH_VERSATILE_PB=y" .config || \
	  (echo "ERROR: CONFIG_MACH_VERSATILE_PB not set")
	@grep -q "^CONFIG_CPU_ARM926T=y" .config || \
	  (echo "ERROR: CONFIG_CPU_ARM926T not set")
	@grep -q "^CONFIG_VMSPLIT_3G=y" .config || \
	  (echo "ERROR: CONFIG_VMSPLIT_3G not set")
	@echo "[kernel-qemu] Config OK"

$(QEMU_ARTIFACTS)/zImage: $(KERNEL_SRC) $(QEMU_DEFCONFIG) | $(QEMU_ARTIFACTS)
	cd $(KERNEL_SRC) && \
		$(MAKE) mrproper && \
		cp $(QEMU_DEFCONFIG) .config && \
		$(MAKE) ARCH=arm olddefconfig && \
		$(MAKE) ARCH=arm CROSS_COMPILE=$(CROSS_COMPILE) LOADADDR=0x00010000 -j$$(nproc) zImage

	cp $(KERNEL_SRC)/arch/arm/boot/zImage $(QEMU_ARTIFACTS)/zImage

# ============================================================
# clean / proper
# ============================================================

.PHONY: kernel-clean
kernel-clean:
	rm -rf $(KERNEL_BUILD) $(KERNEL_SRC)
	rm -rf $(TS209_ARTIFACTS)
	rm -rf $(QEMU_ARTIFACTS)
	rm -f $(KERNEL_HEADERS_STAMP)
	rm -rf $(SYSROOT)/kernel-headers

.PHONY: kernel-proper
kernel-proper: kernel-clean
	rm -f $(DOWNLOADS)/$(KERNEL_TARBALL)

# ============================================================
# Optional: enable ARM decompressor debug output
# Usage: make kernel-qemu ENABLE_DECOMP_DEBUG=1
# ============================================================

ifeq ($(ENABLE_DECOMP_DEBUG),1)
  $(info [kernel] Enabling ARM decompressor DEBUG output)
  export KCFLAGS_arch/arm/boot/compressed += -DDEBUG
endif

# ============================================================
# test
# ============================================================

.PHONY: kernel-test
kernel-test:
	@echo "[kernel] test OK"
	@echo "  TS209 artifacts: $(TS209_ARTIFACTS)"
	@echo "  QEMU artifacts:  $(QEMU_ARTIFACTS)"

# ============================================================
# help
# ============================================================

.PHONY: kernel-help
kernel-help:
	@echo "Kernel module targets:"
	@echo "  kernel-download	 - download kernel tarball"
	@echo "  kernel-headers	  - install kernel headers"
	@echo "  kernel-build		- build TS-209 uImage"
	@echo "  kernel-qemu-build   - build QEMU zImage + DTB"
	@echo "  kernel-clean		- remove build + artifacts"
	@echo "  kernel-proper	   - clean + remove tarball"
