# ============================================================
# Initrd (uInitrd) module
# ============================================================

UINITRD	   := $(ARTIFACTS)/uInitrd
INITRAMFS_GZ  := $(ARTIFACTS)/initramfs.cpio.gz

# ============================================================
# build
# ============================================================

.PHONY: initrd-build
initrd-build: initrd-uinitrd

.PHONY: initrd-uinitrd
initrd-uinitrd: $(UINITRD)

$(UINITRD): $(INITRAMFS_GZ) | $(ARTIFACTS)
	# mkimage must be available inside the container
	mkimage -A arm -O linux -T ramdisk -C gzip \
		-d $(INITRAMFS_GZ) $(UINITRD)

# ============================================================
# clean / proper
# ============================================================

.PHONY: initrd-clean
initrd-clean:
	rm -f $(UINITRD)

.PHONY: initrd-proper
initrd-proper: initrd-clean
	@true   # nothing else to remove

# ============================================================
# test (dispatcher sanity check)
# ============================================================

.PHONY: initrd-test
initrd-test:
	@echo "[initrd] test OK"
	@echo "  ARTIFACTS=$(ARTIFACTS)"
	@echo "  INITRAMFS_GZ=$(INITRAMFS_GZ)"
	@echo "  UINITRD=$(UINITRD)"

# ============================================================
# help
# ============================================================

.PHONY: initrd-help
initrd-help:
	@echo "Initrd module targets:"
	@echo "  initrd-build	  - build uInitrd"
	@echo "  initrd-uinitrd	- generate uInitrd from initramfs.cpio.gz"
	@echo "  initrd-clean	  - remove uInitrd"
	@echo "  initrd-proper	 - full clean"
	@echo "  initrd-test	   - show environment info"
	@echo "  initrd-help	   - this help message"
