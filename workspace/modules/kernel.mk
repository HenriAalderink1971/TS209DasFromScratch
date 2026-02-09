# ============================================================
# Linux kernel module
# ============================================================

KERNEL_VERSION := 5.10.228
KERNEL_TARBALL := linux-$(KERNEL_VERSION).tar.xz
KERNEL_URL	 := https://cdn.kernel.org/pub/linux/kernel/v5.x/$(KERNEL_TARBALL)

KERNEL_SRC	 := $(SOURCES)/linux-$(KERNEL_VERSION)
KERNEL_BUILD   := $(BUILD)/kernel
KERNEL_DEFCONFIG := $(ROOT)/config/ts209pII_defconfig
DTS_DIR		:= $(ROOT)/config/dts

KERNEL_HEADERS_INSTALL=$(SYSROOT)/kernel-headers
KERNEL_HEADERS_STAMP := $(KERNEL_HEADERS_INSTALL)/.installed

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

$(KERNEL_HEADERS_STAMP): $(KERNEL_SRC) | $(SYSROOT)
	cd $(KERNEL_SRC) && \
		mkdir -p $(KERNEL_HEADERS_INSTALL) && \
		$(MAKE) mrproper && \
		cp $(KERNEL_DEFCONFIG) .config && \
		$(MAKE) ARCH=arm olddefconfig && \
		$(MAKE) ARCH=arm headers_install INSTALL_HDR_PATH=$(KERNEL_HEADERS_INSTALL)
	touch $(KERNEL_HEADERS_STAMP)

# ============================================================
# kernel image
# ============================================================

.PHONY: kernel-build
kernel-build: $(ARTIFACTS)/uImage

.PHONY: kernel-defconfig
kernel-defconfig: $(KERNEL_SRC)/arch/arm/configs/ts209pII_defconfig

$(KERNEL_SRC)/arch/arm/configs/ts209pII_defconfig: $(KERNEL_DEFCONFIG)
	mkdir -p $(KERNEL_SRC)/arch/arm/configs
	cp $< $@

$(ARTIFACTS)/uImage: kernel-defconfig $(KERNEL_SRC) | $(ARTIFACTS)
	cd $(KERNEL_SRC) && \
		$(MAKE) ARCH=arm CROSS_COMPILE=$(CROSS_COMPILE) ts209pII_defconfig && \
		$(MAKE) ARCH=arm CROSS_COMPILE=$(CROSS_COMPILE) LOADADDR=0x00008000 -j$$(nproc) uImage
	cp $(KERNEL_SRC)/arch/arm/boot/uImage $(ARTIFACTS)/uImage

# ============================================================
# clean / proper
# ============================================================

.PHONY: kernel-clean
kernel-clean:
	rm -rf $(KERNEL_BUILD) $(KERNEL_SRC)
	rm -f $(ARTIFACTS)/uImage
	rm -f $(KERNEL_HEADERS_STAMP)
	rm -rf $(SYSROOT)/kernel-headers

.PHONY: kernel-proper
kernel-proper: kernel-clean
	rm -f $(DOWNLOADS)/$(KERNEL_TARBALL)

# ============================================================
# test (dispatcher sanity check)
# ============================================================

.PHONY: kernel-test
kernel-test:
	@echo "[kernel] test OK"
	@echo "  ROOT=$(ROOT)"
	@echo "  SOURCES=$(SOURCES)"
	@echo "  DOWNLOADS=$(DOWNLOADS)"
	@echo "  BUILD=$(BUILD)"
	@echo "  ARTIFACTS=$(ARTIFACTS)"
	@echo "  SYSROOT=$(SYSROOT)"
	@echo "  CROSS_COMPILE=$(CROSS_COMPILE)"

# ============================================================
# help
# ============================================================

.PHONY: kernel-help
kernel-help:
	@echo "Kernel module targets:"
	@echo "  kernel-download	 - download kernel tarball"
	@echo "  kernel-headers	  - install kernel headers into sysroot"
	@echo "  kernel-build		- build uImage"
	@echo "  kernel-clean		- remove build + source + headers stamp"
	@echo "  kernel-proper	   - clean + remove tarball"
	@echo "  kernel-test		 - show environment info"
	@echo "  kernel-help		 - this help message"
