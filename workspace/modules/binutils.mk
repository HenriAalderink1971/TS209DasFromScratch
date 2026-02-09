# ============================================================
# Binutils module
# ============================================================

BINUTILS_VERSION := 2.34
BINUTILS_TARBALL := binutils-$(BINUTILS_VERSION).tar.xz
BINUTILS_URL	 := https://ftp.gnu.org/gnu/binutils/$(BINUTILS_TARBALL)

BINUTILS_SRC	 := $(SOURCES)/binutils-$(BINUTILS_VERSION)
BINUTILS_BUILD   := $(BUILD)/binutils
BINUTILS_STAMP   := $(TOOLCHAIN)/.binutils-installed

# ============================================================
# download
# ============================================================

.PHONY: binutils-download
binutils-download: $(DOWNLOADS)/$(BINUTILS_TARBALL)

$(DOWNLOADS)/$(BINUTILS_TARBALL): | $(DOWNLOADS)
	[ -f $@ ] || wget -O $@ $(BINUTILS_URL)

# ============================================================
# extract
# ============================================================

$(BINUTILS_SRC): $(DOWNLOADS)/$(BINUTILS_TARBALL) | $(SOURCES)
	rm -rf $(BINUTILS_SRC)
	tar -xf $< -C $(SOURCES)

# ============================================================
# build
# ============================================================

.PHONY: binutils-build
binutils-build: $(BINUTILS_STAMP)

$(BINUTILS_STAMP): $(BINUTILS_SRC) | $(TOOLCHAIN) $(BUILD)
	rm -rf $(BINUTILS_BUILD)
	mkdir -p $(BINUTILS_BUILD)
	cd $(BINUTILS_BUILD) && \
		$(BINUTILS_SRC)/configure \
			--target=$(TARGET) \
			--prefix=$(TOOLCHAIN) \
			--disable-nls \
			--disable-werror \
			--enable-gold \
			--enable-ld=default \
			--enable-plugins \
			--enable-lto \
			--enable-deterministic-archives
	$(MAKE) -C $(BINUTILS_BUILD) -j$$(nproc)
	$(MAKE) -C $(BINUTILS_BUILD) install
	touch $(BINUTILS_STAMP)

# ============================================================
# clean / proper
# ============================================================

.PHONY: binutils-clean
binutils-clean:
	rm -rf $(BINUTILS_BUILD) $(BINUTILS_SRC)
	rm -f $(BINUTILS_STAMP)
	rm -f $(TOOLCHAIN)/bin/$(TARGET)-*

.PHONY: binutils-proper
binutils-proper: binutils-clean
	rm -f $(DOWNLOADS)/$(BINUTILS_TARBALL)

# ============================================================
# test (dispatcher sanity check)
# ============================================================

.PHONY: binutils-test
binutils-test:
	@echo "[binutils] test OK"
	@echo "  ROOT=$(ROOT)"
	@echo "  SOURCES=$(SOURCES)"
	@echo "  DOWNLOADS=$(DOWNLOADS)"
	@echo "  BUILD=$(BUILD)"
	@echo "  TOOLCHAIN=$(TOOLCHAIN)"
	@echo "  TARGET=$(TARGET)"

# ============================================================
# help
# ============================================================

.PHONY: binutils-help
binutils-help:
	@echo "Binutils module targets:"
	@echo "  binutils-download   - download tarball"
	@echo "  binutils-build	  - configure, build, install"
	@echo "  binutils-clean	  - remove build + source + stamp"
	@echo "  binutils-proper	 - clean + remove tarball"
	@echo "  binutils-test	   - show environment info"
	@echo "  binutils-help	   - this help message"
