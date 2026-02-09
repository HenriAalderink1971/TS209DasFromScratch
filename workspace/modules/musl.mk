# ============================================================
# musl libc module
# ============================================================

MUSL_VERSION := 1.2.5
MUSL_TARBALL := musl-$(MUSL_VERSION).tar.gz
MUSL_URL	 := https://musl.libc.org/releases/$(MUSL_TARBALL)

MUSL_SRC	 := $(SOURCES)/musl-$(MUSL_VERSION)
MUSL_BUILD   := $(BUILD)/musl
MUSL_STAMP   := $(SYSROOT)/usr/lib/libc.a

# ============================================================
# download
# ============================================================

.PHONY: musl-download
musl-download: $(DOWNLOADS)/$(MUSL_TARBALL)

$(DOWNLOADS)/$(MUSL_TARBALL): | $(DOWNLOADS)
	[ -f $@ ] || wget -O $@ $(MUSL_URL)

# ============================================================
# extract
# ============================================================

$(MUSL_SRC): $(DOWNLOADS)/$(MUSL_TARBALL) | $(SOURCES)
	rm -rf $(MUSL_SRC)
	tar -xf $< -C $(SOURCES)

# ============================================================
# build
# ============================================================

.PHONY: musl-build
musl-build: $(MUSL_STAMP)

# musl installs libc.a into $(SYSROOT)/usr/lib
$(MUSL_STAMP): $(MUSL_SRC) $(KERNEL_HEADERS_STAMP) | $(SYSROOT)
	rm -rf $(MUSL_BUILD)
	mkdir -p $(MUSL_BUILD)
	cd $(MUSL_SRC) && \
		CC=$(CROSS_COMPILE)gcc \
		AR=$(CROSS_COMPILE)ar \
		RANLIB=$(CROSS_COMPILE)ranlib \
		./configure \
			--prefix=/usr \
			--disable-shared \
			--target=$(TARGET) \
			--syslibdir=/usr/lib

	$(MAKE) -C $(MUSL_SRC) -j$$(nproc)
	DESTDIR=$(SYSROOT) $(MAKE) -C $(MUSL_SRC) install

	touch $(MUSL_STAMP)

# ============================================================
# clean / proper
# ============================================================

.PHONY: musl-clean
musl-clean:
	rm -rf $(MUSL_BUILD) $(MUSL_SRC)
	rm -f $(MUSL_STAMP)

.PHONY: musl-proper
musl-proper: musl-clean
	rm -f $(DOWNLOADS)/$(MUSL_TARBALL)

# ============================================================
# test (dispatcher sanity check)
# ============================================================

.PHONY: musl-test
musl-test:
	@echo "[musl] test OK"
	@echo "  ROOT=$(ROOT)"
	@echo "  SOURCES=$(SOURCES)"
	@echo "  DOWNLOADS=$(DOWNLOADS)"
	@echo "  BUILD=$(BUILD)"
	@echo "  SYSROOT=$(SYSROOT)"
	@echo "  TARGET=$(TARGET)"
	@echo "  CROSS_COMPILE=$(CROSS_COMPILE)"

# ============================================================
# help
# ============================================================

.PHONY: musl-help
musl-help:
	@echo "musl module targets:"
	@echo "  musl-download   - download musl tarball"
	@echo "  musl-build	  - configure, build, install musl"
	@echo "  musl-clean	  - remove build + source + stamp"
	@echo "  musl-proper	 - clean + remove tarball"
	@echo "  musl-test	   - show environment info"
	@echo "  musl-help	   - this help message"
