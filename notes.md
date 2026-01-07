# Build Environment for Marvell 88F5182 (Feroceon / Orion5x)

This repository provides a fully reproducible build environment for
developing and maintaining Linux images for Marvell 88F5182–based
systems (e.g., QNAP TS‑209/TS‑409 and other Orion5x boards).

The environment is containerized using Docker and includes:

- Buildroot (as a git submodule)
- Mainline Linux kernel (as a git submodule)
- A Debian‑based build container with all required tools
- A top‑level Makefile to build
