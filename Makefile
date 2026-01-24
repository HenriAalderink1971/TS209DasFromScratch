PROJECT_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

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


