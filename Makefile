# ============================================================
# Container actions
# ============================================================
CONTAINER_ACTIONS := build clean proper download test help

%:
	@full="$@"; \
	ndashes=$$(echo "$$full" | tr -cd '-' | wc -c); \
	\
	if [ "$$ndashes" -eq 2 ]; then \
		action=$${full%%-*}; \
		tmp=$${full#*-}; \
		module=$${tmp%%-*}; \
		task=$${full##*-}; \
		echo "[3-seg] action=$$action module=$$module task=$$task"; \
	elif [ "$$ndashes" -eq 1 ]; then \
		action=$${full%%-*}; \
		module=$${full#*-}; \
		task=$$action; \
		echo "[2-seg] action=$$action module=$$module task=$$task"; \
	else \
		action=$$full; \
		module=all; \
		task=$$action; \
		echo "[1-seg] action=$$action module=$$module task=$$task"; \
	fi; \
	\
	if echo " $(CONTAINER_ACTIONS) " | grep -q " $$action "; then \
		echo "[container] action=$$action module=$$module task=$$task"; \
		echo "→ running in container: make -f modules.mk $$module-$$task"; \
		docker run --rm \
			-v "$$(pwd)/workspace":/workspace \
			-w /workspace \
			mycontainer \
			make -f modules.mk $$module-$$task; \
	else \
		echo "[host] action=$$action module=$$module task=$$task"; \
	fi

# ============================================================
# Container management
# ============================================================
CONTAINER_NAME := mycontainer
CONTAINER_IMAGE := mycontainer:latest
CONTAINER_DOCKERFILE := docker/Dockerfile
CONTAINER_CONTEXT := docker

.PHONY: container-up
container-up:
	@echo "[container] building image $(CONTAINER_IMAGE)"
	docker build -t $(CONTAINER_IMAGE) -f $(CONTAINER_DOCKERFILE) $(CONTAINER_CONTEXT)

.PHONY: container-down
container-down:
	@echo "[container] removing image $(CONTAINER_IMAGE)"
	-docker rmi $(CONTAINER_IMAGE)

.PHONY: container-update
container-update: container-down container-up

.PHONY: container-shell
container-shell:
	@echo "[container] starting interactive shell"
	docker run --rm -it \
		-v "$(PWD)/workspace":/workspace \
		-w /workspace \
		$(CONTAINER_IMAGE) \
		/bin/bash

# ============================================================
# Build stages
# ============================================================
# nas
#  ├── toolchain
#  │    ├── binutils-build
#  │    ├── gcc-stage1
#  │    ├── kernel-headers
#  │    ├── musl-build
#  │    └── gcc-final
#  ├── userspace
#  │    └── busybox-build
#  └── images
#       ├── initramfs-build
#       ├── initrd-build
#       └── kernel-build

.PHONY: toolchain userspace images nas
toolchain: build-binutils build-gcc-stage1 build-kernel-headers build-musl build-gcc-final
userspace: build-busybox build-busybox-install
images: build-initramfs build-initrd build-kernel
nas: toolchain userspace images
