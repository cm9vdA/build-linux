#!/bin/bash

# some resource file from http://releases.linaro.org/96boards/
# referer:
# https://releases.linaro.org/96boards/dragonboard410c/linaro/debian/21.12/
# https://releases.linaro.org/96boards/dragonboard845c/linaro/debian/21.12/
# https://releases.linaro.org/96boards/rb5/linaro/debian/21.12/

PWD_DIR=${PWD}
TMP_DIR=/dev/shm/.tmp_install
TMP_KERNEL=${TMP_DIR}/kernel
TMP_RAMDISK=${TMP_DIR}/ramdisk

echo_usage() {
    echo "Usage: $0 KERNEL_PKG RAMDISK_PKG"
    echo "eg: $0 linux_ai-kit_6.13.0_20250310_1017.tar.xz ./ramdisk.cpio.gz ./firmware/"
    exit
}

if [ $# -ne 3 ]; then
    echo_usage
fi

KERNEL_PKG=$(realpath $1)
RAMDISK_PKG=$(realpath $2)
FIRMWARE_DIR=$(realpath $3)

if [ "${KERNEL_PKG}" == "" ] || [ "${RAMDISK_PKG}" == "" ] || [ "${FIRMWARE_DIR}" == "" ]; then
    echo_usage
fi

set -e
if [ ! -f "${KERNEL_PKG}" ]; then
    echo "File not found: ${KERNEL_PKG}"
    exit
fi
if [ ! -f "${RAMDISK_PKG}" ]; then
    echo "File not found: ${RAMDISK_PKG}"
    exit
fi
if [ ! -d "${FIRMWARE_DIR}" ]; then
    echo "Dir not found: ${FIRMWARE_DIR}"
    exit
fi

rm -rf ${TMP_DIR}
mkdir -p ${TMP_KERNEL}
mkdir -p ${TMP_RAMDISK}

echo "Stage 1: Unpack kernel package..."
tar xmf ${KERNEL_PKG} -C ${TMP_KERNEL} --exclude="include"

echo "Stage 2: Unpack Ramdisk..."
cd ${TMP_RAMDISK}
if [ "${RAMDISK_PKG#*.}" == "cpio.gz" ]; then
    gzip -dc ${RAMDISK_PKG} | cpio -i
else
    echo "Invalid Ramdisk File: ${RAMDISK_PKG}"
    exit
fi

echo "Stage 3: Copy Module & Firmware.."
cd ${TMP_RAMDISK}
rm -rf ./lib/modules
mkdir -p ./lib/firmware
mkdir -p ./lib/modules

cp -dpr ${TMP_KERNEL}/lib/modules ./lib/modules
cp -dpr ${FIRMWARE_DIR}/* ./lib/firmware

echo "Stage 4: Pack Ramdisk..."
cd ${TMP_RAMDISK}
find . | cpio -o -H newc | gzip >${TMP_DIR}/ramdisk.cpio.gz

echo "Stage 5: Build boot.img"
cd ${PWD_DIR}
cat ${TMP_KERNEL}/Image.gz ${TMP_KERNEL}/*.dtb >${TMP_DIR}/kernel.img
#linaro
mkbootimg --base 0 --pagesize 4096 --kernel_offset 0x80008000 --ramdisk_offset 0x81000000 --second_offset 0x80f00000 --tags_offset 0x80000100 --cmdline 'earlycon root=PARTLABEL=rootfs rw console=tty0 console=ttyMSM0,115200n8 clk_ignore_unused pd_ignore_unused' --kernel ${TMP_DIR}/kernel.img --ramdisk ${TMP_DIR}/ramdisk.cpio.gz -o ${PWD_DIR}/boot.img
#posmarketos
#mkbootimg --base 0x0 --kernel_offset 0x8000 --ramdisk_offset 0x1000000 --tags_offset 0x100 --pagesize 4096 --second_offset 0xf00000  --cmdline 'earlycon=qcom_geni root=PARTLABEL=rootfs console=tty0 console=ttyMSM0,115200n8 clk_ignore_unused pd_ignore_unused' --kernel ${TMP_DIR}/kernel.img --ramdisk ${TMP_DIR}/ramdisk.cpio.gz -o ${PWD_DIR}/boot.img

echo "Stage 6: Clean file"
rm -rf ${TMP_DIR}

echo "Please run \"sudo dd if=./boot.img of=/dev/mmcblkXp12; sync\""