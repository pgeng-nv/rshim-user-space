#!/bin/sh

test() {
  # local
  ssh root@bu-lab105-bmc "systemctl stop rshim"
  sleep 5
  sudo systemctl start rshim
  sleep 3
  time ./bfb-install -v --bfb $BFB --rshim rshim0

  # remote
  sudo systemctl stop rshim
  sleep 3
  ssh root@bu-lab105-bmc "systemctl start rshim"
  sleep 5
  # scp
  time ./bfb-install -v --bfb $BFB --rshim bu-lab105-bmc:rshim0
  # ncpipe
  time ./bfb-install -v --bfb $BFB --rshim bu-lab105-bmc:9707:rshim0 --remote-mode ncpipe
}

BFB=~/work/bins/default.bfb
test

BFB=~/work/bins/last_ubuntu_22.04_qp
test
