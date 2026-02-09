# ============================================================
# GCC module
# Provides: gcc-stage1, gcc-final
# ============================================================

GCC_VERSION		:= 8.5.0
GCC_TARBALL		:= gcc-$(GCC_VERSION).tar.xz
GCC_URL			:= https://ftp.gnu.org/gnu/gcc/gcc-$(GCC_VERSION)/$(GCC_TARBALL)

GCC_SRC			:= $(SOURCES)/gcc-$(GCC_VERSION)
GCC_STAGE1_BUILD   := $(BUILD)/gcc-stage1
GCC_FINAL_BUILD	:= $(BUILD)/gcc-final

# ============================================================
# download
# ============================================================

.PHONY: gcc-download
gcc-download: $(DOWNLOADS)/$(GCC_TARBALL)

$(DOWNLOADS)/$(GCC_TARBALL): | $(DOWNLOADS)
	[ -f $@ ] || wget -O $@ $(GCC_URL)

# ============================================================
# extract
# ============================================================

$(GCC_SRC): $(DOWNLOADS)/$(GCC_TARBALL) | $(SOURCES)
	rm -rf $(GCC_SRC)
	tar -xf $< -C $(SOURCES)

# ============================================================
# gcc stage1
# Requires: binutils (ar, ld, as, ranlib)
# ============================================================

.PHONY: gcc-stage1
gcc-stage1: $(TOOLCHAIN)/bin/$(TARGET)-gcc

$(TOOLCHAIN)/bin/$(TARGET)-gcc: $(GCC_SRC) $(TOOLCHAIN)/bin/$(TARGET)-ar | $(TOOLCHAIN) $(BUILD)
	rm -rf $(GCC_STAGE1_BUILD)
	mkdir -p $(GCC_STAGE1_BUILD)
	cd $(GCC_STAGE1_BUILD) && \
		$(GCC_SRC)/configure \
			--target=$(TARGET) \
			--prefix=$(TOOLCHAIN) \
			--without-headers \
			--enable-languages=c \
			--disable-nls \
			--disable-shared \
			--disable-threads \
			--disable-multilib && \
		$(MAKE) -j$$(nproc) all-gcc && \
		$(MAKE) install-gcc

# ============================================================
# gcc final
# Requires: kernel headers + musl libc
# ============================================================

.PHONY: gcc-final
gcc-final: $(TOOLCHAIN)/bin/$(TARGET)-gcc-final

$(TOOLCHAIN)/bin/$(TARGET)-gcc-final: $(GCC_SRC) $(SYSROOT)/usr/include $(SYSROOT)/usr/lib/libc.a | $(TOOLCHAIN) $(BUILD)
	rm -rf $(GCC_FINAL_BUILD)
	mkdir -p $(GCC_FINAL_BUILD)
	cd $(GCC_FINAL_BUILD) && \
		$(GCC_SRC)/configure \
			--target=$(TARGET) \
			--prefix=$(TOOLCHAIN) \
			--with-sysroot=$(SYSROOT) \
			--enable-languages=c \
			--disable-nls \
			--disable-multilib && \
		$(MAKE) -j$$(nproc) && \
		$(MAKE) install

	ln -sf $(TOOLCHAIN)/bin/$(TARGET)-gcc $(TOOLCHAIN)/bin/$(TARGET)-gcc-final

# ============================================================
# clean / proper
# ============================================================

.PHONY: gcc-clean
gcc-clean:
	rm -rf $(GCC_STAGE1_BUILD) $(GCC_FINAL_BUILD)
	rm -rf $(GCC_SRC)
	rm -f $(TOOLCHAIN)/bin/$(TARGET)-gcc
	rm -f $(TOOLCHAIN)/bin/$(TARGET)-gcc-final

.PHONY: gcc-proper
gcc-proper: gcc-clean
	rm -f $(DOWNLOADS)/$(GCC_TARBALL)

# ============================================================
# test (dispatcher sanity check)
# ============================================================

.PHONY: gcc-test
gcc-test:
	@echo "[gcc] test OK"
	@echo "  ROOT=$(ROOT)"
	@echo "  SOURCES=$(SOURCES)"
	@echo "  DOWNLOADS=$(DOWNLOADS)"
	@echo "  BUILD=$(BUILD)"
	@echo "  SYSROOT=$(SYSROOT)"
	@echo "  TOOLCHAIN=$(TOOLCHAIN)"
	@echo "  TARGET=$(TARGET)"
	@echo "  CROSS_COMPILE=$(CROSS_COMPILE)"

# ============================================================
# help
# ============================================================

.PHONY: gcc-help
gcc-help:
	@echo "GCC module targets:"
	@echo "  gcc-download   - download GCC tarball"
	@echo "  gcc-stage1	 - build stage1 compiler (no libc)"
	@echo "  gcc-final	  - build final compiler (with musl + headers)"
	@echo "  gcc-clean	  - remove build + source + toolchain binaries"
	@echo "  gcc-proper	 - clean + remove tarball"
	@echo "  gcc-test	   - show environment info"
	@echo "  gcc-help	   - this help message"
