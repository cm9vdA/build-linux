#!/bin/bash
#UDIR=$PWD
TFDEV=/dev/$1
#cd $UDIR
sudo dd if=u-boot.bin.sd.bin of=$TFDEV bs=1 count=442
sudo dd if=u-boot.bin.sd.bin of=$TFDEV bs=512 seek=1 skip=1
sync

