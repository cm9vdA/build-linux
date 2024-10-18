#!/bin/bash

TMP_DIR=/dev/shm/.tmp_install
TMP_RAMDISK=${TMP_DIR}/ramdisk
SPLIT_TOOL=$(realpath ${0%/*}/../split_bootimg.pl)

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
RAMDISK_PKG=${TMP_DIR}/$(basename ${BOOT_IMG})-ramdisk.gz
KERNEL_PKG=${TMP_DIR}/$(basename ${BOOT_IMG})-kernel
if [ "${BOOT_IMG}" == "" ]; then
    echo_usage
fi

if [ ! -f "${BOOT_IMG}" ]; then
    echo "File not found: ${BOOT_IMG}"
    exit
fi

rm -rf ${TMP_DIR}
mkdir -p ${TMP_RAMDISK}

echo "Stage 1: Unpack Boot Image..."
cd ${TMP_DIR}
perl ${SPLIT_TOOL} ${BOOT_IMG}

echo "Stage 2: Unpack Ramdisk..."
cd ${TMP_RAMDISK}
gzip -dc ${RAMDISK_PKG} | cpio -i

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
mkbootimg --base 0 --pagesize 2048 --kernel_offset 0x80080000 --ramdisk_offset 0x81000000 --second_offset 0x80f00000 --tags_offset 0x80000100 --cmdline 'console=ttyHSL0,115200,n8 androidboot.console=ttyHSL0 androidboot.hardware=qcom user_debug=31 msm_rtb.filter=0x237 ehci-hcd.park=3 androidboot.bootdevice=7824900.sdhci earlyprintk' --kernel ${KERNEL_PKG} --ramdisk ${TMP_DIR}/ramdisk.cpio.gz -o ${BOOT_IMG}-root

echo "Stage 6: Clean file"
rm -rf ${TMP_DIR}

echo "done"
