#!/bin/bash

PWD_DIR=${PWD}
TMP_DIR=/dev/shm/.tmp_install
TMP_KERNEL=${TMP_DIR}/kernel
TMP_RAMDISK=${TMP_DIR}/ramdisk

echo_usage() {
    echo "Usage: $0 KERNEL_PKG uInitrd"
    echo "eg: $0 linux_oes_5.15.185_20250621_1715.tar.xz ./uInitrd"
    exit
}

if [ $# -ne 2 ]; then
    echo_usage
fi

KERNEL_PKG=$(realpath $1)
RAMDISK_PKG=$(realpath $2)

if [ "${KERNEL_PKG}" == "" ] || [ "${RAMDISK_PKG}" == "" ]; then
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

rm -rf ${TMP_DIR}
mkdir -p ${TMP_KERNEL}
mkdir -p ${TMP_RAMDISK}

echo "Stage 1: Unpack kernel package..."
tar xmf ${KERNEL_PKG} -C ${TMP_KERNEL} --exclude="include"

echo "Stage 2: Unpack uInitrd..."
cd ${TMP_RAMDISK}
if [ "${RAMDISK_PKG#*.}" == "cpio.gz" ]; then
    gzip -dc ${RAMDISK_PKG} | cpio -i
else
    dd if=${RAMDISK_PKG} of=${TMP_DIR}/uInitrd.cpio.gz bs=64 skip=1
    gzip -dc ${TMP_DIR}/uInitrd.cpio.gz | cpio -i
fi

echo "Stage 3: Copy Module.."
cd ${TMP_RAMDISK}
rm -rf ./lib/modules
mkdir -p ./lib/modules

cp -dpr ${TMP_KERNEL}/lib/modules ./lib/modules

echo "Stage 4: Pack uInitrd..."
cd ${TMP_RAMDISK}
find . | cpio -o -H newc | gzip >${TMP_DIR}/uInitrd.cpio.gz
mkimage -A arm -T ramdisk -C gzip -n "uInitrd" -d ${TMP_DIR}/uInitrd.cpio.gz ${PWD_DIR}/new_uInitrd

echo "Stage 5: Clean file"
rm -rf ${TMP_DIR}

echo "Done"
