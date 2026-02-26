# ============================================================
# GDB module
# ============================================================

# Use a GDB version compatible with gcc-9 era
GDB_VERSION := 10.2
GDB_TARBALL := gdb-$(GDB_VERSION).tar.xz
GDB_URL	 := https://ftp.gnu.org/gnu/gdb/$(GDB_TARBALL)

GDB_SRC	 := $(SOURCES)/gdb-$(GDB_VERSION)
GDB_BUILD   := $(BUILD)/gdb
GDB_STAMP   := $(TOOLCHAIN)/.gdb-installed

# ============================================================
# download
# ============================================================

.PHONY: gdb-download
gdb-download: $(DOWNLOADS)/$(GDB_TARBALL)

$(DOWNLOADS)/$(GDB_TARBALL): | $(DOWNLOADS)
	[ -f $@ ] || wget -O $@ $(GDB_URL)

# ============================================================
# extract
# ============================================================

$(GDB_SRC): $(DOWNLOADS)/$(GDB_TARBALL) | $(SOURCES)
	rm -rf $(GDB_SRC)
	tar -xf $< -C $(SOURCES)

# ============================================================
# build
# ============================================================

.PHONY: gdb-build
gdb-build: $(GDB_STAMP)

$(GDB_STAMP): $(GDB_SRC) | $(TOOLCHAIN) $(BUILD)
	rm -rf $(GDB_BUILD)
	mkdir -p $(GDB_BUILD)
	cd $(GDB_BUILD) && \
		CPPFLAGS="-I/usr/include" \
		LDFLAGS="-L/usr/lib/x86_64-linux-gnu" \
		$(GDB_SRC)/configure \
			--target=$(TARGET) \
			--prefix=$(TOOLCHAIN) \
			--with-socket

	$(MAKE) -C $(GDB_BUILD) -j$$(nproc)
	$(MAKE) -C $(GDB_BUILD) install
	touch $(GDB_STAMP)

# ============================================================
# clean / proper
# ============================================================

.PHONY: gdb-clean
gdb-clean:
	rm -rf $(GDB_BUILD) $(GDB_SRC)
	rm -f $(GDB_STAMP)
	rm -f $(TOOLCHAIN)/bin/$(TARGET)-gdb

.PHONY: gdb-proper
gdb-proper: gdb-clean
	rm -f $(DOWNLOADS)/$(GDB_TARBALL)

# ============================================================
# test
# ============================================================

.PHONY: gdb-test
gdb-test:
	@echo "[gdb] test OK"
	@echo "  ROOT=$(ROOT)"
	@echo "  SOURCES=$(SOURCES)"
	@echo "  DOWNLOADS=$(DOWNLOADS)"
	@echo "  BUILD=$(BUILD)"
	@echo "  TOOLCHAIN=$(TOOLCHAIN)"
	@echo "  TARGET=$(TARGET)"

# ============================================================
# help
# ============================================================

.PHONY: gdb-help
gdb-help:
	@echo "GDB module targets:"
	@echo "  gdb-download   - download tarball"
	@echo "  gdb-build	  - configure, build, install"
	@echo "  gdb-clean	  - remove build + source + stamp"
	@echo "  gdb-proper	 - clean +
