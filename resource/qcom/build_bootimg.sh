#!/bin/bash

PWD_DIR=${PWD}
TMP_DIR=/dev/shm/.tmp_install
TMP_KERNEL=${TMP_DIR}/kernel
TMP_RAMDISK=${TMP_DIR}/ramdisk

KERNEL_PKG=$(realpath $1)
RAMDISK_IMG=$(realpath $2)

if [ "${KERNEL_PKG}" == "" ] || [ "${RAMDISK_IMG}" == "" ]; then
    echo "Usage: $0 KERNEL_PKG RAMDISK_IMG"
    echo "eg: $0 linux_mf601sl_v07_6.10.0_20240921_1155.tar.xz ramdisk.cpio.gz"
    exit
fi

if [ ! -f "${KERNEL_PKG}" ]; then
    echo "File not found: ${KERNEL_PKG}"
    exit
fi
if [ ! -f "${RAMDISK_IMG}" ]; then
    echo "File not found: ${RAMDISK_IMG}"
    exit
fi

rm -rf ${TMP_DIR}
mkdir -p ${TMP_KERNEL}
mkdir -p ${TMP_RAMDISK}

echo "Stage 1: Unpack kernel package..."
tar xmf ${KERNEL_PKG} -C ${TMP_KERNEL} --exclude="include"

echo "Stage 2: Install kernel modules"
rm -rf /lib/modules
cp -pr ${TMP_KERNEL}/lib/modules /lib/

echo "Stage 3: Unpack Ramdisk..."
cd ${TMP_RAMDISK}
gzip -dc ${RAMDISK_IMG} | cpio -i

echo "Stage 4: Copy Module & Firmware.."
cd ${TMP_RAMDISK}
rm -rf ./lib/modules
cp -pr /lib/modules/ ./lib/
cp -pr /lib/firmware/ ./lib/

echo "Stage 5: Pack Ramdisk..."
cd ${TMP_RAMDISK}
find . | cpio -o -H newc | gzip >${TMP_DIR}/ramdisk.cpio.gz

echo "Stage 6: Build boot.img"
cd ${PWD_DIR}
cat ${TMP_KERNEL}/Image.gz ${TMP_KERNEL}/*.dtb >${TMP_DIR}/kernel.img
mkbootimg --base 0 --pagesize 2048 --kernel_offset 0x80080000 --ramdisk_offset 0x82000000 --second_offset 0x00000000 --tags_offset 0x81e00000 --cmdline 'earlycon root=PARTUUID=a7ab80e8-e9d1-e8cd-f157-93f69b1d141e console=ttyMSM0,115200 no_framebuffer=true rw' --kernel ${TMP_DIR}/kernel.img --ramdisk ${TMP_DIR}/ramdisk.cpio.gz -o ${PWD_DIR}/boot.img

rm -rf ${TMP_DIR}

echo "Please run \"sudo dd if=./boot.img of=/dev/mmcblkXp12; sync\""
