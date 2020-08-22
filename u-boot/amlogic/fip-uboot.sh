#!/bin/bash

SCRIPT_PATH=`S=\`readlink "$0"\`; [ -z "$S" ] && S=$0; dirname $S`
TMP_DIR=./.tmp_dir
FIP_DIR=${SCRIPT_PATH}/fip

init(){
	rm ${TMP_DIR} -rf
	mkdir ${TMP_DIR}

	cp ${FIP_DIR}/gxb/bl2.bin ${TMP_DIR}/
	cp ${FIP_DIR}/gxb/acs.bin ${TMP_DIR}/
	cp ${FIP_DIR}/gxb/bl21.bin ${TMP_DIR}/
	cp ${FIP_DIR}/gxb/bl30.bin ${TMP_DIR}/
	cp ${FIP_DIR}/gxb/bl301.bin ${TMP_DIR}/
	cp ${FIP_DIR}/gxb/bl31.img ${TMP_DIR}/
	cp $1 ${TMP_DIR}/bl33.bin
}

fip_uboot(){
	${FIP_DIR}/blx_fix.sh \
		${TMP_DIR}/bl30.bin \
		${TMP_DIR}/zero_tmp \
		${TMP_DIR}/bl30_zero.bin \
		${TMP_DIR}/bl301.bin \
		${TMP_DIR}/bl301_zero.bin \
		${TMP_DIR}/bl30_new.bin \
		bl30

	${FIP_DIR}/fip_create \
		--bl30 ${TMP_DIR}/bl30_new.bin \
		--bl31 ${TMP_DIR}/bl31.img \
		--bl33 ${TMP_DIR}/bl33.bin \
		${TMP_DIR}/fip.bin

	python ${FIP_DIR}/acs_tool.pyc ${TMP_DIR}/bl2.bin ${TMP_DIR}/bl2_acs.bin ${TMP_DIR}/acs.bin 0

	${FIP_DIR}/blx_fix.sh \
		${TMP_DIR}/bl2_acs.bin \
		${TMP_DIR}/zero_tmp \
		${TMP_DIR}/bl2_zero.bin \
		${TMP_DIR}/bl21.bin \
		${TMP_DIR}/bl21_zero.bin \
		${TMP_DIR}/bl2_new.bin \
		bl2

	cat ${TMP_DIR}/bl2_new.bin ${TMP_DIR}/fip.bin > ${TMP_DIR}/boot_new.bin

	${FIP_DIR}/gxb/aml_encrypt_gxb --bootsig \
				--input ${TMP_DIR}/boot_new.bin \
				--skipsector 1 \
				--output ${TMP_DIR}/u-boot.bin
}

main(){
	init u-boot-dtb.bin
	fip_uboot
}

main