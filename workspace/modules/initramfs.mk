# ============================================================
# Initramfs module
# ============================================================

INITRAMFS_BUILD := $(BUILD)/initramfs
INITRAMFS_CPIO  := $(ARTIFACTS)/initramfs.cpio.gz

# ============================================================
# build
# ============================================================

.PHONY: initramfs-build
initramfs-build: $(INITRAMFS_CPIO)

$(INITRAMFS_CPIO): $(SYSROOT)/bin/busybox | $(ARTIFACTS)
	rm -rf $(INITRAMFS_BUILD)
	mkdir -p \
		$(INITRAMFS_BUILD)/bin \
		$(INITRAMFS_BUILD)/sbin \
		$(INITRAMFS_BUILD)/etc \
		$(INITRAMFS_BUILD)/proc \
		$(INITRAMFS_BUILD)/sys \
		$(INITRAMFS_BUILD)/usr/bin \
		$(INITRAMFS_BUILD)/usr/sbin \
		$(INITRAMFS_BUILD)/dev \
		$(INITRAMFS_BUILD)/tmp
	cp $(SYSROOT)/bin/busybox $(INITRAMFS_BUILD)/bin/
	for applet in sh mount echo clear ls; do \
		ln -sf busybox "$(INITRAMFS_BUILD)/bin/$$applet"; \
	done

	# Minimal init script
	echo '#!/bin/sh' > $(INITRAMFS_BUILD)/init
	echo 'mount -t proc none /proc' >> $(INITRAMFS_BUILD)/init
	echo 'mount -t sysfs none /sys' >> $(INITRAMFS_BUILD)/init
	echo 'echo "Initramfs booted"' >> $(INITRAMFS_BUILD)/init
	echo 'exec /bin/sh' >> $(INITRAMFS_BUILD)/init
	chmod +x $(INITRAMFS_BUILD)/init

	# Create CPIO archive
	cd $(INITRAMFS_BUILD) && \
		find . -print0 | cpio --null -ov --format=newc | gzip -9 > $(INITRAMFS_CPIO)

# ============================================================
# clean / proper
# ============================================================

.PHONY: initramfs-clean
initramfs-clean:
	rm -rf $(INITRAMFS_BUILD)
	rm -f $(INITRAMFS_CPIO)

.PHONY: initramfs-proper
initramfs-proper: initramfs-clean
	@true   # nothing else to remove

# ============================================================
# test (dispatcher sanity check)
# ============================================================

.PHONY: initramfs-test
initramfs-test:
	@echo "[initramfs] test OK"
	@echo "  BUILD=$(BUILD)"
	@echo "  ARTIFACTS=$(ARTIFACTS)"
	@echo "  SYSROOT=$(SYSROOT)"

# ============================================================
# help
# ============================================================

.PHONY: initramfs-help
initramfs-help:
	@echo "Initramfs module targets:"
	@echo "  initramfs-build   - build initramfs.cpio.gz"
	@echo "  initramfs-clean   - remove build directory + cpio"
	@echo "  initramfs-proper  - full clean"
	@echo "  initramfs-test	- show environment info"
	@echo "  initramfs-help	- this help message"
