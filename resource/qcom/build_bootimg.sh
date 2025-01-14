#!/bin/bash

# some resource file from http://releases.linaro.org/96boards/
# referer:
# https://releases.linaro.org/96boards/dragonboard410c/linaro/debian/21.12/
# https://releases.linaro.org/96boards/dragonboard845c/linaro/debian/21.12/

PWD_DIR=${PWD}
TMP_DIR=/dev/shm/.tmp_install
TMP_KERNEL=${TMP_DIR}/kernel
TMP_RAMDISK=${TMP_DIR}/ramdisk
TMP_MODEM=${TMP_DIR}/modem
TMP_MODEM_IMG=${TMP_DIR}/NON-HLOS.bin

echo_usage() {
    echo "Usage: $0 KERNEL_PKG RAMDISK_PKG"
    echo "eg: $0 linux_mf601sl_6.10.0_20240926_1046.tar.xz ./ramdisk.cpio.gz ./NON-HLOS.bin.gz ./firmware/"
    exit
}

if [ $# -ne 4 ]; then
    echo_usage
fi

KERNEL_PKG=$(realpath $1)
RAMDISK_PKG=$(realpath $2)
MODEM_PKG=$(realpath $3)
FIRMWARE_DIR=$(realpath $4)

if [ "${KERNEL_PKG}" == "" ] || [ "${RAMDISK_PKG}" == "" ] || [ "${MODEM_PKG}" == "" ] || [ "${FIRMWARE_DIR}" == "" ]; then
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
if [ ! -f "${MODEM_PKG}" ]; then
    echo "File not found: ${MODEM_PKG}"
    exit
fi
if [ ! -d "${FIRMWARE_DIR}" ]; then
    echo "Dir not found: ${FIRMWARE_DIR}"
    exit
fi

rm -rf ${TMP_DIR}
mkdir -p ${TMP_KERNEL}
mkdir -p ${TMP_RAMDISK}
mkdir -p ${TMP_MODEM}

echo "Stage 1: Unpack kernel package..."
tar xmf ${KERNEL_PKG} -C ${TMP_KERNEL} --exclude="include"

echo "Stage 2: Unpack Modem..."
if [ "${MODEM_PKG#*.}" == "gz" ] || [ "${MODEM_PKG#*.}" == "bin.gz" ] || [ "${MODEM_PKG#*.}" == "img.gz" ]; then
    gzip -dc ${MODEM_PKG} >${TMP_MODEM_IMG}
elif [ "${MODEM_PKG#*.}" == "bin" ] || [ "${MODEM_PKG#*.}" == "img" ]; then
    cp ${MODEM_PKG} ${TMP_MODEM_IMG}
else
    echo "Invalid Modem File: ${MODEM_PKG}"
    exit
fi

echo "Stage 3: Unpack Ramdisk..."
cd ${TMP_RAMDISK}
if [ "${RAMDISK_PKG#*.}" == "cpio.gz" ]; then
    gzip -dc ${RAMDISK_PKG} | cpio -i
else
    echo "Invalid Ramdisk File: ${RAMDISK_PKG}"
    exit
fi

echo "Stage 4: Copy Module & Firmware.."
cd ${TMP_RAMDISK}
rm -rf ./lib/modules
mkdir -p ./lib/firmware
mkdir -p ./lib/modules

cp -dpr ${TMP_KERNEL}/lib/modules ./lib/modules
sudo mount -o ro ${TMP_MODEM_IMG} ${TMP_MODEM}
cp -dpr ${TMP_MODEM}/image/* ./lib/firmware
sudo umount ${TMP_MODEM}
cp -dpr ${FIRMWARE_DIR}/* ./lib/firmware

echo "Stage 5: Pack Ramdisk..."
cd ${TMP_RAMDISK}
find . | cpio -o -H newc | gzip >${TMP_DIR}/ramdisk.cpio.gz

echo "Stage 6: Build boot.img"
cd ${PWD_DIR}
cat ${TMP_KERNEL}/Image.gz ${TMP_KERNEL}/*.dtb >${TMP_DIR}/kernel.img
mkbootimg --base 0 --pagesize 2048 --kernel_offset 0x80080000 --ramdisk_offset 0x82000000 --second_offset 0x00000000 --tags_offset 0x81e00000 --cmdline 'earlycon root=/dev/mmcblk0p14 console=ttyMSM0,115200 rw' --kernel ${TMP_DIR}/kernel.img --ramdisk ${TMP_DIR}/ramdisk.cpio.gz -o ${PWD_DIR}/boot.img

echo "Stage 7: Clean file"
rm -rf ${TMP_DIR}

echo "Please run \"sudo dd if=./boot.img of=/dev/mmcblkXp12; sync\""
