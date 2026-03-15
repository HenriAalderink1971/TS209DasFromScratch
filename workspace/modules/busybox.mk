# ============================================================
# BusyBox module
# ============================================================

BUSYBOX_VERSION	  := 1.36.1
BUSYBOX_TARBALL	  := busybox-$(BUSYBOX_VERSION).tar.bz2
BUSYBOX_URL		  := https://busybox.net/downloads/$(BUSYBOX_TARBALL)
BUSYBOX_SRC		  := $(SOURCES)/busybox-$(BUSYBOX_VERSION)
BUSYBOX_BUILD		:= $(BUILD)/busybox
BUSYBOX_CONFIG	   := $(ROOT)/config/busybox/busybox.config
BUSYBOX_MUSL_COMPAT  := $(ROOT)/config/busybox/musl-compat.h

# From kernel.mk
KERNEL_HEADERS_STAMP := $(SYSROOT)/usr/include/.kernel-headers-installed

# ============================================================
# download
# ============================================================

.PHONY: busybox-download
busybox-download: $(DOWNLOADS)/$(BUSYBOX_TARBALL)

$(DOWNLOADS)/$(BUSYBOX_TARBALL): | $(DOWNLOADS)
	[ -f $@ ] || wget -O $@ $(BUSYBOX_URL)

# ============================================================
# extract
# ============================================================

$(BUSYBOX_SRC): $(DOWNLOADS)/$(BUSYBOX_TARBALL) | $(SOURCES)
	rm -rf $(BUSYBOX_SRC)
	tar -xf $< -C $(SOURCES)

# ============================================================
# config workflow
# ============================================================

.PHONY: busybox-config.reset
busybox-config.reset: $(BUSYBOX_SRC)
	cd $(BUSYBOX_SRC) && \
		$(MAKE) ARCH=arm CROSS_COMPILE=$(TOOLCHAIN)/bin/$(TARGET)- allnoconfig
	cp $(BUSYBOX_SRC)/.config $(BUSYBOX_CONFIG)

.PHONY: busybox-config
busybox-config: $(BUSYBOX_SRC)
	cd $(BUSYBOX_SRC) && \
		$(MAKE) ARCH=arm CROSS_COMPILE=$(TOOLCHAIN)/bin/$(TARGET)- menuconfig
	cp $(BUSYBOX_SRC)/.config $(BUSYBOX_CONFIG)

.PHONY: busybox-patch-config
busybox-patch-config: $(BUSYBOX_CONFIG)
	sed -i 's|^CONFIG_CROSS_COMPILER_PREFIX=.*|CONFIG_CROSS_COMPILER_PREFIX="$(TARGET)-"|' $(BUSYBOX_CONFIG)
	sed -i 's|^# CONFIG_STATIC is not set|CONFIG_STATIC=y|' $(BUSYBOX_CONFIG)
	sed -i 's|^CONFIG_SYSROOT=.*|CONFIG_SYSROOT="$(SYSROOT)"|' $(BUSYBOX_CONFIG)
	sed -i 's|^CONFIG_EXTRA_CFLAGS=.*|CONFIG_EXTRA_CFLAGS="--sysroot=$(SYSROOT) -include $(BUSYBOX_MUSL_COMPAT)"|' $(BUSYBOX_CONFIG)
	sed -i 's|CONFIG_SHA256_SHA_NI=y|# CONFIG_SHA256_SHA_NI is not set|' $(BUSYBOX_CONFIG)

.PHONY: busybox-check-config
busybox-check-config:
	@if ! grep -q 'CONFIG_CROSS_COMPILER_PREFIX="$(TARGET)-"' $(BUSYBOX_CONFIG); then \
		echo "ERROR: BusyBox config missing correct CROSS_COMPILER_PREFIX"; exit 1; fi
	@if ! grep -q 'CONFIG_STATIC=y' $(BUSYBOX_CONFIG); then \
		echo "ERROR: BusyBox must be static"; exit 1; fi
	@if grep -q 'CONFIG_SHA256_SHA_NI=y' $(BUSYBOX_CONFIG); then \
		echo "ERROR: SHA-NI must be disabled for ARM"; exit 1; fi
	@if ! grep -q 'CONFIG_SYSROOT="$(SYSROOT)"' $(BUSYBOX_CONFIG); then \
		echo "ERROR: BusyBox SYSROOT mismatch"; exit 1; fi

# ============================================================
# build
# ============================================================

$(BUSYBOX_SRC)/.config: $(BUSYBOX_SRC) $(BUSYBOX_CONFIG)
	cp $(BUSYBOX_CONFIG) $(BUSYBOX_SRC)/.config
	cd $(BUSYBOX_SRC) && yes "" | $(MAKE) ARCH=arm oldconfig

.PHONY: busybox-build
busybox-build: $(BUSYBOX_SRC)/.config $(SYSROOT)/usr/lib/libc.a $(KERNEL_HEADERS_STAMP)
	 PATH=$(TOOLCHAIN)/bin:$$PATH && $(MAKE) -C $(BUSYBOX_SRC) KERNEL_HEADERS=$(SYSROOT)/kernel-headers/include  ARCH=arm -j$$(nproc) CROSS_COMPILE=$(TOOLCHAIN)/bin/$(TARGET)- CFLAGS_EXTRA="--sysroot=$(SYSROOT) -I$(SYSROOT)/kernel-headers/include" busybox

busybox-install: busybox-build
	$(MAKE) -C $(BUSYBOX_SRC) ARCH=arm CONFIG_PREFIX=$(SYSROOT) install

# ============================================================
# clean / proper
# ============================================================

.PHONY: busybox-clean
busybox-clean:
	rm -rf $(BUSYBOX_BUILD) $(BUSYBOX_SRC)
	rm -f $(SYSROOT)/bin/busybox

.PHONY: busybox-proper
busybox-proper: busybox-clean
	rm -f $(DOWNLOADS)/$(BUSYBOX_TARBALL)

# ============================================================
# test (dispatcher sanity check)
# ============================================================

.PHONY: busybox-test
busybox-test:
	@echo "[busybox] test OK"
	@echo "  ROOT=$(ROOT)"
	@echo "  SOURCES=$(SOURCES)"
	@echo "  DOWNLOADS=$(DOWNLOADS)"
