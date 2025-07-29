# BlueField-3 IRQ Routing Debug Summary

## Issue Description
- **Problem**: NIC FW reset request via scratchpad6 not acknowledged by rshim
- **Symptom**: NIC FW writes `RSHIM_PCIE_RST_STATE_REQUEST` to scratchpad6, expects ACK (value 1), but always reads 0
- **Root Cause**: INTx interrupt routing issue on specific server

## Key Findings

### Affected System (qalenovo-27)
- **Problematic Device**: 38:00.2 (rshim0) - mapped to IRQ 19
- **Working Device**: a8:00.1 (rshim1) - mapped to IRQ 16  
- **BIOS Date**: April 2025 (cutting-edge)
- **Issue**: IRQ 19 never fires, but IRQ 16 does during reset

### Working System (bu-lab105)
- All BlueField devices share IRQ 18 - all working

## Technical Analysis

### Interrupt Flow Breakdown
1. NIC FW writes reset request to scratchpad6 ✓
2. NIC FW asserts INTA signal ✓
3. **BROKEN**: INTA routed to IRQ 16 instead of expected IRQ 19
4. rshim waiting on IRQ 19 via `/dev/uio0` - never fires
5. `read(dev->intr_fd)` blocks forever at `rshim_pcie.c:915`

### Root Cause
- **Platform-level** INTx routing issue
- BIOS ACPI tables say: 38:00.2 INTA → IRQ 19
- Actual hardware routes: 38:00.2 INTA → IRQ 16
- Likely due to PCIe bridge or motherboard chipset limitation

### Backend Modes
- **UIO mode**: Uses INTx only (problematic on this server)
- **Direct mode**: Uses polling (works but poor performance)
- **VFIO mode**: Supports MSI/MSI-X (would fix the issue)

## Solutions

### Immediate Workarounds
1. Use direct mode: `backend = direct`
2. Move card to different PCIe slot
3. Switch to VFIO for MSI support

### Long-term Fix
```bash
# Switch to VFIO backend for MSI support
modprobe vfio-pci
echo 0000:38:00.2 > /sys/bus/pci/drivers/uio_pci_generic/unbind
echo 15b3 c2d5 > /sys/bus/pci/drivers/vfio-pci/new_id
systemctl restart rshim
```

## Debug Commands Used

```bash
# Check IRQ assignments
cat /proc/interrupts | grep -E "16:|19:"
lspci -vvv -s 38:00.2 | grep "Interrupt:"

# Check UIO mapping
for i in /sys/class/uio/uio*/device; do 
    echo -n "$(basename $(dirname $i)): "
    readlink $i | grep -o '[0-9a-f]*:[0-9a-f]*:[0-9a-f]*\.[0-9a-f]*'
done

# Monitor IRQ activity
watch -n1 'cat /proc/interrupts | grep "^ *19:"'
```

## Code Locations
- Interrupt thread stuck: `src/rshim_pcie.c:915`
- Reset state machine: `src/rshim_pcie.c:830-870`
- scratchpad6 definitions: `src/rshim_pcie.c:76-100`

## Conclusion
This is a **platform hardware issue**, not an rshim or NIC FW bug. The newest servers (April 2025 BIOS) may have poor INTx support as the industry moves to MSI/MSI-X. Using VFIO backend would completely avoid this issue by using modern MSI interrupts instead of legacy INTx.