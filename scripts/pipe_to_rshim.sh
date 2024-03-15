#!/bin/sh
#
# This script reads from a named pipe and writes to the rshim device.
#
# It is intended to be run on BMC to forward data from the host to the BMC RSHIM
# device. 
#
# Known Issues:
#  - This script must be copied over to the BMC and run from there. We need to 
#    change it to SSH-run this script from the host.

RSHIM_PIPE=$(RSHIM_PIPE:-"/tmp/rshim_pipe")
RSHIM_BOOT_NODE=$(RSHIM_NODE:-"/dev/rshim")/boot
BLOCK_SIZE=2048000  # smaller block size performs worse

if [ -p "$RSHIM_PIPE" ]; then
  echo "Named pipe already exists. Deleting it..."
  rm $RSHIM_PIPE
fi

mkfifo $RSHIM_PIPE

echo "Continuously read from pipe and write to rshim device..."
if dd if=$RSHIM_PIPE of=$RSHIM_BOOT_NODE bs=$BLOCK_SIZE; then
    echo "Successfully forwarded data from $RSHIM_PIPE to $RSHIM_NODE"
else
    echo "Error occurred in dd command"
    exit 1
fi
