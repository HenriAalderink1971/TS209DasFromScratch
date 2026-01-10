# Build Environment for Marvell 88F5182 (Feroceon / Orion5x)

This repository provides a fully reproducible build environment for
developing and maintaining Linux images for Marvell 88F5182–based
systems (e.g., QNAP TS‑209/TS‑409 and other Orion5x boards).

The environment is containerized using Docker and includes:

- Buildroot (as a git submodule)
- Mainline Linux kernel (as a git submodule)
- A Debian‑based build container with all required tools
- A top‑level Makefile to build:
  - `uImage` (kernel)
  - `uInitrd` (initramfs)
  - `notes.html` (this file converted to HTML)
- A shared `artifacts/` directory for TFTP‑ready output
- Host scripts for updating, building, and entering the container

The goal is to provide a clean, deterministic, and repeatable workflow
for ARMv5 / Feroceon development.

---

## 1. Repository Structure

{
├── artifacts
├── buildroot
├── docker
│   ├── Dockerfile
│   └── packages.txt
├── docker-compose.yml
├── linux
├── Makefile
├── notes.md
└── scripts
    ├── build.sh
    ├── shell.sh
    └── update.sh

}
---

## 2. Prerequisites

You need the following installed on the host:

- Docker
- Docker Compose
- Git

No toolchains or build dependencies are required on the host. Everything
runs inside the container.

---

## 3. Initial Setup

Add the Submodules
{
git submodule add https://github.com/buildroot/buildroot.git buildroot
git submodule add https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git linux
}

Clone the repository and initialize the submodules:

```sh
git submodule update --init --recursive

# QNAP TS-209 Pro II Bring-up Notes

## 4. Hardware Overview
- SoC: Marvell 88F5182 (Orion5x)
- CPU: ARMv5TE, 500 MHz
- RAM: 256 MB DDR2
- Flash: 8 MB NOR
- SATA: 2× SATA II
- Ethernet: Marvell 88E1111 PHY (Gigabit)
- USB: 3× USB 2.0
- UART: 3.3V TTL, 115200 baud
- Bootloader: U-Boot (QNAP customized)
- LEDs: Power, Status, HDD1, HDD2
- Buttons: Power, Reset
- Other: Fan controller, RTC, buzzer

## 5. Kernel Build Results
- Kernel version: Linux 4.14.336
- Toolchain: Buildroot internal (arm-buildroot-linux-musleabi-)
- Load address: 0x00008000
- Output: `uImage` (3.28 MiB)
- Build environment: Docker (cpus=2, mem_limit=4g)
- Build command:
{
make ARCH=arm CROSS_COMPILE=... LOADADDR=0x00008000 uImage -j1
}

## 6. Bootloader Expectations
- Kernel load address: 0x00008000
- Initrd load address: 0x01100000 (tentative)
- Boot command:
{
bootm 0x00800000 0x01100000
}

## 7. DTS Work (to be created)
- Base: orion5x reference DTS
- Nodes:
- /cpus
- /memory
- /soc
  - uart0
  - eth0 + phy
  - sata
  - gpio
  - timers
  - interrupt controller
- LEDs
- Buttons
- Fan controller (later)
- Buzzer (later)

## DTS Management

The DTS lives in:
- `config/dts/orion5x-qnap-ts209pro2.dts`

The Linux kernel tree contains only a symlink:
- `linux/arch/arm/boot/dts/orion5x-qnap-ts209pro2.dts`

The symlink is created automatically by the Makefile target `dts-link`.

Makefile snippet:
```make
dts-link:
    if [ ! -L "$(DTS_DST)" ]; then \
        ln -sf ../../../../$(DTS_SRC) $(DTS_DST); \
    fi
```

## 8. Serial Console
- Baud: 115200
- 3.3V TTL
- Connected and working
- First boot logs: (to be added)

## 9. Next Steps
- Create minimal DTS
- Enable early printk
- Build uInitrd
- TFTP boot kernel + initrd
- Capture serial output

# TFTP Deployment

## Overview

After building the kernel, device tree, and initrd inside the Docker container, the resulting boot artifacts are placed in:

```
./artifacts/
```

To boot the TS-209 Pro II over the network, these files must be copied to the host’s TFTP directory:

```
/srv/tftp
```

A helper script (`scripts/deploy_tftp.sh`) automates this process.

## Deployment Script

Run the script on the host (not inside Docker):

```
sudo ./scripts/deploy_tftp.sh
```

The script performs the following actions:

- Copies the required boot files:
  - `uImage`
  - `uInitrd`
  - `orion5x-qnap-ts209pro2.dtb`
- Places them into `/srv/tftp`
- Sets ownership to `tftp:tftp`
- Sets permissions to `644`

## Verifying Deployment

After running the script, verify the files:

```
ls -l /srv/tftp
```

Expected files:

```
uImage
uInitrd
orion5x-qnap-ts209pro2.dtb
```

These three files form the complete boot set for U-Boot.

# U-Boot Boot Commands (TS-209 Pro II)

Interrupt the boot process on the serial console to enter the U-Boot prompt.

Set the device IP and TFTP server IP:

```
setenv ipaddr 192.168.2.50
setenv serverip 192.168.2.10
```

Load the kernel:

```
tftp 0x00800000 uImage
```

Load the device tree:

```
tftp 0x00c00000 orion5x-qnap-ts209pro2.dtb
```

Load the initrd:

```
tftp 0x01100000 uInitrd
```

Boot the system:

```
bootm 0x00800000 0x01100000 0x00c00000
```

## Memory Layout Notes

- `0x00800000` → kernel load address  
- `0x00c00000` → device tree  
- `0x01100000` → initrd  
- These addresses are safe for 256 MB RAM on the 88F5182 platform.

## Saving the Environment (optional)

If everything works, persist the settings:

```
saveenv
```
# Network Boot Progress Notes

## Overview

The TS-209 Pro II now successfully boots a custom Linux 4.14 kernel and initramfs via TFTP using the appended-DTB method. This bypasses the legacy machine ID passed by the original QNAP U-Boot and ensures the kernel always uses the correct device tree.

This section documents the working setup, including firewall configuration, TFTP deployment, and the updated Makefile rules for building an appended-DTB uImage.

---

# Firewall Configuration (UFW)

The host system uses UFW with a default `deny (incoming)` policy. TFTP requires:

- UDP port 69 for the initial request (RRQ)
- A random high UDP port for the data channel

To allow TFTP from the local network:

```
sudo ufw allow 69/udp
sudo ufw allow from 192.168.2.0/24 proto udp
sudo ufw reload
```

Verify UFW status:

```
sudo ufw status verbose
```

---

# TFTP Deployment

Boot artifacts are generated inside the Docker container and placed in:

```
./artifacts/
```

To deploy them to the host TFTP directory:

```
sudo ./scripts/deploy_tftp.sh
```

This copies:

- `uImage` (kernel with appended DTB)
- `uInitrd` (initramfs)
- `orion5x-qnap-ts209pro2.dtb` (kept for reference, not used at boot)

Files are placed in:

```
/srv/tftp
```

Verify:

```
ls -l /srv/tftp
```

Expected files:

```
uImage
uInitrd
orion5x-qnap-ts209pro2.dtb
```

---

# U-Boot Boot Procedure

Interrupt the boot process and load the kernel and initrd:

```
tftp 0x00800000 uImage
tftp 0x01100000 uInitrd
bootm 0x00800000 0x01100000
```

Notes:

- No DTB is loaded separately.
- The DTB is appended to the kernel image.
- The machine ID passed by U-Boot is ignored by the kernel.

---

# Appended-DTB Kernel Build

The kernel is built normally, but the final bootable image is created by concatenating:

```
[zImage][DTB]
```

and wrapping it as a uImage.

This ensures the kernel always uses the correct DTB, regardless of the machine ID passed by U-Boot.

---

# Updated Makefile Targets

Add the following to the project Makefile:

```
# Paths
ZIMAGE      := linux/arch/arm/boot/zImage
DTB         := linux/arch/arm/boot/dts/orion5x-qnap-ts209pro2.dtb
ZIMAGE_DTB  := artifacts/zImage-dtb
UIMAGE      := artifacts/uImage

# Build kernel (unchanged)
kernel-build:
    cd linux && \
    make ARCH=arm CROSS_COMPILE=/workspace/buildroot/output/host/usr/bin/arm-buildroot-linux-musleabi- orion5x_defconfig && \
    make ARCH=arm CROSS_COMPILE=/workspace/buildroot/output/host/usr/bin/arm-buildroot-linux-musleabi- LOADADDR=0x00008000 uImage -j1

# Create appended zImage+dtb
append-dtb: kernel-build
    cat $(ZIMAGE) $(DTB) > $(ZIMAGE_DTB)

# Wrap appended image into uImage
uimage-appended: append-dtb
    mkimage -A arm -O linux -T kernel -C none \
        -a 0x00008000 -e 0x00008000 \
        -n "Linux with appended DTB" \
        -d $(ZIMAGE_DTB) $(UIMAGE)

# Main kernel target
kernel: uimage-appended
```

Ensure the top-level `all` target depends on `kernel`.

---

# Current Status

- TFTP boot works reliably.
- Firewall configuration is correct.
- Appended-DTB kernel boots past decompression.
- Machine ID mismatch is resolved.
- System is ready for early kernel bring-up and DTS expansion.





