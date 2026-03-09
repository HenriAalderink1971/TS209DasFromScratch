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
# Workspace (build) container
# ============================================================

WORKSPACE_NAME := workspace
WORKSPACE_IMAGE := workspace:latest
WORKSPACE_DOCKERFILE := workspace.config/Dockerfile
WORKSPACE_CONTEXT := workspace.config

.PHONY: workspace-up
workspace-up:
	@echo "[workspace] building image $(WORKSPACE_IMAGE)"
	docker build -t $(WORKSPACE_IMAGE) -f $(WORKSPACE_DOCKERFILE) $(WORKSPACE_CONTEXT)

.PHONY: workspace-down
workspace-down:
	@echo "[workspace] removing image $(WORKSPACE_IMAGE)"
	-docker rmi $(WORKSPACE_IMAGE)

.PHONY: workspace-update
workspace-update: workspace-down workspace-up

.PHONY: workspace-shell
workspace-shell:
	@echo "[workspace] starting interactive shell"
	docker run --rm -it \
		-v "$(PWD)/workspace":/workspace \
		-w /workspace \
		$(WORKSPACE_IMAGE) \
		/bin/bash

# ============================================================
# Build stages
# ============================================================
# nas
#  ├── toolchain
#  │	├── binutils-build
#  │	├── gcc-stage1
#  │	├── kernel-headers
#  │	├── musl-build
#  │	└── gcc-final
#  ├── userspace
#  │	└── busybox-build
#  └── images
#	   ├── initramfs-build
#	   ├── initrd-build
#	   └── kernel-build

.PHONY: toolchain userspace images nas
toolchain: build-binutils build-gcc-stage1 build-kernel-headers build-musl build-gcc-final
userspace: build-busybox build-busybox-install
images: build-initramfs build-initrd build-kernel
nas: toolchain userspace images

# ============================================================
# Testbench container
# ============================================================

TESTBENCH_NAME := testbench
TESTBENCH_IMAGE := testbench:latest
TESTBENCH_DOCKERFILE := testbench.config/Dockerfile
TESTBENCH_CONTEXT := testbench.config

.PHONY: testbench-up
testbench-up:
	@echo "[testbench] building image $(TESTBENCH_IMAGE)"
	docker build -t $(TESTBENCH_IMAGE) -f $(TESTBENCH_DOCKERFILE) $(TESTBENCH_CONTEXT)

.PHONY: testbench-down
testbench-down:
	@echo "[testbench] removing image $(TESTBENCH_IMAGE)"
	-docker rmi $(TESTBENCH_IMAGE)

.PHONY: testbench-update
testbench-update: testbench-down testbench-up

.PHONY: testbench-shell
testbench-shell:
	@if [ "$$(docker ps -q -f name=$(TESTBENCH_NAME))" ]; then \
		echo "→ Attaching to running container $(TESTBENCH_NAME)"; \
		docker exec -it $(TESTBENCH_NAME) bash; \
	else \
		echo "→ Starting container $(TESTBENCH_NAME)"; \
		docker run --name $(TESTBENCH_NAME) -it --rm \
			-v "$(PWD)/workspace":/workspace:ro \
			-v "$(PWD)/testbench":/testbench \
			-w /testbench \
			$(TESTBENCH_IMAGE) bash; \
	fi
## ============================================================
# Testbench container
# ============================================================
.PHONY: test
test: build-initramfs build-kernel build-kernel-qemu build-initramfs build-initrd
	@echo "[test] running tests in testbench container"
	docker run --rm \
		-v "$(PWD)/workspace":/workspace:ro \
		-v "$(PWD)/testbench":/testbench \
		-w /testbench \
		testbench:latest \
		./run-tests.sh

