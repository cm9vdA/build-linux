#!/bin/bash

TMP_DIR=/dev/shm/.tmp_install
TMP_RAMDISK=${TMP_DIR}/ramdisk
IMG_TOOL=${PWD}/android-unpackbootimg

echo_usage() {
    echo "Usage: $0 BOOT_IMG"
    echo "eg: $0 boot.img"
    exit
}

replace_prop() {
    local file=$1
    local key=$2
    local value=$3

    sed -i "/^$key=/d" $file 2>/dev/null
    if [ "$value" != "" ]; then
        echo $key=$value >>$file
    fi
}

if [ $# -ne 1 ]; then
    echo_usage
fi

BOOT_IMG=$(realpath $1)
UNPACK_PREIX=${TMP_DIR}/unpack/$(basename ${BOOT_IMG})
if [ "${BOOT_IMG}" == "" ]; then
    echo_usage
fi

if [ ! -f "${BOOT_IMG}" ]; then
    echo "File not found: ${BOOT_IMG}"
    exit
fi

rm -rf ${TMP_DIR}
mkdir -p ${TMP_RAMDISK}

# bootimg tool
if [ ! -d ${IMG_TOOL} ]; then
    echo "Stage 0: Build Boot Image Tool..."
    # backup fork: https://github.com/cm9vdA/android-unpackbootimg
    git clone https://github.com/anestisb/android-unpackbootimg -o ${IMG_TOOL}
    cd ${IMG_TOOL}
    make
fi

echo "Stage 1: Unpack Boot Image..."
cd ${TMP_DIR}
${IMG_TOOL}/unpackbootimg -i ${BOOT_IMG} -o ./unpack

echo "Stage 2: Unpack Ramdisk..."
cd ${TMP_RAMDISK}
gzip -dc ${UNPACK_PREIX}-ramdisk.gz | cpio -i

echo "Stage 3: Replace Properties..."
cd ${TMP_RAMDISK}
replace_prop default.prop ro.secure 0
replace_prop default.prop ro.allow.mock.location 1
replace_prop default.prop ro.debuggable 1
replace_prop default.prop persist.service.adb.enable 1
replace_prop default.prop persist.sys.usb.config diag,serial_smd,rmnet_bam,adb

echo "Stage 4: Pack Ramdisk..."
cd ${TMP_RAMDISK}
find . | cpio -o -H newc | gzip >${TMP_DIR}/ramdisk.cpio.gz

echo "Stage 5: Build boot.img"
cd ${TMP_DIR}
${IMG_TOOL}/mkbootimg \
    --kernel ${UNPACK_PREIX}-zImage \
    --ramdisk ${TMP_DIR}/ramdisk.cpio.gz \
    --cmdline "$(cat ${UNPACK_PREIX}-cmdline)" \
    --board "$(cat ${UNPACK_PREIX}-board)" \
    --base "$(cat ${UNPACK_PREIX}-base)" \
    --pagesize "$(cat ${UNPACK_PREIX}-pagesize)" \
    --dt ${UNPACK_PREIX}-dtb \
    --kernel_offset "$(cat ${UNPACK_PREIX}-kerneloff)" \
    --ramdisk_offset "$(cat ${UNPACK_PREIX}-ramdiskoff)" \
    --second_offset "$(cat ${UNPACK_PREIX}-secondoff)" \
    --tags_offset "$(cat ${UNPACK_PREIX}-tagsoff)" \
    --os_version "0.0.0" \
    --os_patch_level "2023-05" \
    --hash "$(cat ${UNPACK_PREIX}-hash)" \
    --output ${BOOT_IMG}-root

echo "Stage 6: Clean file"
# rm -rf ${TMP_DIR}

echo "done"
