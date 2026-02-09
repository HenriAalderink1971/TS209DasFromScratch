# ============================================================
# Common workspace paths (shared by all modules)
# ============================================================
SHELL = /bin/bash -x

ROOT	  ?= /workspace
SOURCES   ?= $(ROOT)/sources
DOWNLOADS ?= $(ROOT)/downloads
BUILD	 ?= $(ROOT)/build
SYSROOT   ?= $(ROOT)/sysroot
TOOLCHAIN ?= $(ROOT)/toolchain
ARTIFACTS ?= $(ROOT)/artifacts

TARGET		?= arm-linux-musleabihf
CROSS_COMPILE ?= $(TOOLCHAIN)/bin/$(TARGET)-
# ============================================================
# Auto-discover modules
# ============================================================

# Find all module .mk files
MODULE_FILES := $(wildcard modules/*.mk)

# Strip directory + extension → module names
#   modules/binutils.mk → binutils
#   modules/busybox.mk  → busybox
#   ...
MODULES := $(basename $(notdir $(MODULE_FILES)))

# ============================================================
# Include all module files
# ============================================================

include $(MODULE_FILES)

# ============================================================
# all-% dispatcher
# ============================================================
# Usage:
#   make all-build
#   make all-clean
#   make all-proper
#   make all-test
#
# Expands to:
#   binutils-build busybox-build kernel-build ...
# ============================================================

.PHONY: all-%
all-%:
	@echo "[modules] running $* on all modules"
	@echo "$(addsuffix -$*, $(MODULES))"
	@$(MAKE) -f modules.mk $(addsuffix -$*, $(MODULES))

	# ============================================================
# Optional task guard
# ============================================================

# If a module does not implement <module>-<task>, ignore it
%:
	@echo "Nothing defined for $@"

