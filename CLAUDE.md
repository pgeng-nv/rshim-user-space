# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

RShim (Remote System Management Interface) is a host driver providing access to BlueField DPU/NIC resources from external host machines. It supports boot image delivery, virtual console access, virtual networking, and register access across USB, PCIe, and PCIe Livefish backends.

## Build System

### Initial Setup
- Run `./bootstrap.sh` first to generate configure script (requires autoconf/automake/pkg-config)
- Configure with `./configure` (see configure.ac for build options)
- Build with `make` and install with `make install`
- FreeBSD: Use `gmake` instead of `make`

### Build Configuration Options
- `--enable-usb` / `--disable-usb`: USB backend (default: enabled)  
- `--enable-pcie` / `--disable-pcie`: PCIe backend (default: enabled)
- `--enable-fuse` / `--disable-fuse`: FUSE/CUSE support (default: enabled)

### Common Commands
```bash
# Clean build from scratch
make clean
./configure
make

# Build for debugging  
./configure CFLAGS="-g -O0"
make

# Install to system
sudo make install
```

## Architecture Overview

### Core Components
- **rshim.c**: Main daemon and device management
- **rshim.h**: Central header with backend interface definitions
- **rshim_regs.h**: Hardware register definitions for BF1/BF2/BF3
- **rshim_regs.c**: Platform-specific register mappings

### Backend Implementations  
- **rshim_pcie.c**: PCIe backend (direct memory mapping, VFIO, UIO support)
- **rshim_pcie_lf.c**: PCIe Livefish backend for recovery scenarios
- **rshim_usb.c**: USB backend using libusb
- **rshim_fuse.c**: FUSE filesystem interface (/dev/rshimN/)

### Communication & Protocol
- **rshim_net.c**: Virtual network interface (tmfifo)
- **rshim_cmdmode.c**: Command mode operations
- **rshim_log.c**: Logging and debug output

### Device Interface
Creates `/dev/rshimN/` directories with:
- `boot`: Boot image delivery
- `console`: Serial console access  
- `rshim`: Register access
- `misc`: Key/value configuration

## BlueField Reset Protocol (BF3 Issue Context)

The PCIe reset state machine in `rshim_pcie.c:820-870` handles NIC firmware reset requests:

### Reset States (scratchpad6 register)
- `RSHIM_PCIE_RST_STATE_REQUEST`: NIC FW requests reset
- `RSHIM_PCIE_RST_STATE_START`: Reset execution begins  
- `RSHIM_PCIE_RST_STATE_ABORT`: Reset cancelled

### Expected Protocol Flow
1. NIC FW writes `RSHIM_PCIE_RST_STATE_REQUEST` to scratchpad6
2. Driver responds with `RSHIM_PCIE_RST_REPLY_ACK` (sets bit to 1)
3. NIC FW should read acknowledgment from scratchpad6

### Key Reset Handling Code
- Reset state decode: `rshim_pcie.c:103-130` (scratchpad6 bit layout)
- Interrupt handler: `rshim_pcie.c:830-836` (ACK response)
- Register definitions: `rshim_regs.h` and `rshim_regs.c`

## BlueField Hardware Support

### Supported Devices
- **BlueField-1**: Device ID 0xc2d2 (RSHIM_BLUEFIELD_1)
- **BlueField-2**: Device ID 0xc2d3 (RSHIM_BLUEFIELD_2)  
- **BlueField-3**: Device IDs 0xc2d4, 0xc2d5 (RSHIM_BLUEFIELD_3)

### Register Mappings
- BF1/BF2: Use `bf1_bf2_rshim_regs` structure
- BF3: Use `bf3_rshim_regs` structure with different register offsets

## Key Data Structures

### rshim_backend_t
Central backend structure containing device state, FIFO buffers, threading primitives, and function pointers for backend-specific operations.

### rshim_regs  
Platform-specific register offset definitions, including the critical `scratchpad6` register used for reset coordination.

## Debugging the BF3 Reset Issue

When debugging why scratchpad6 always reads 0 instead of 1:

1. Check register offset definitions in `rshim_regs.c:47` (BF3_RSH_SCRATCHPAD6)
2. Verify write operation in `rshim_pcie.c:835-836` 
3. Examine memory mapping and access patterns in PCIe backend
4. Add debug logging around scratchpad6 read/write operations
5. Confirm NIC FW and driver are using same register interpretation

## Development Notes

- All backends implement the same interface defined in rshim.h
- Register access always goes through backend-specific read_rshim/write_rshim functions
- FIFO operations are multiplexed between console and network channels
- Reset coordination requires precise timing and register synchronization