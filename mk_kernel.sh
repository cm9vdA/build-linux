#!/bin/bash

# Environment Variable File

# export BOARD_NAME=M2
# export CPU_INFO=Allwinner A20

# export PATH=$PATH:/home/overlay/opt/gcc-linaro-7.5.0-2019.12-x86_64_arm-linux-gnueabihf/bin/
# export ARCH=arm
# export KERNEL_TARGET="zImage modules dtbs"
# export CROSS_COMPILE=arm-linux-gnueabihf-
# export INSTALL_MOD_PATH=./install
# export DTB_FILE=sun7i-a20-m2

source_env(){
	SCRIPT_NAME=${0##*/}
	# SCRIPT_PATH=$(cd "$(dirname "$0")"; pwd -P)
	SCRIPT_PATH=`S=\`readlink "$0"\`; [ -z "$S" ] && S=$0; dirname $S`
	ENV_FILE=${SCRIPT_PATH}/env/${SCRIPT_NAME}

	source ${ENV_FILE}

	# Other Environment Variable
	export XZ_DEFAULTS="-T 0"
	export INSTALL_MOD_PATH=./install
	BUILD_DIR=${PWD}/.build
	BUILD_ARGS="-j$(nproc) O=${BUILD_DIR}"
	INSTALL_DIR=${BUILD_DIR}/${INSTALL_MOD_PATH}
}

build_info(){
	echo "================ Build Info ================"
	echo -e "BOARD_NAME:       ${BOARD_NAME}"
	echo -e "CPU_INFO:         ${CPU_INFO}"
	echo -e "DTB_FILE:         ${DTB_FILE}"
	echo -e "ARCH:             ${ARCH}"
	echo -e "KERNEL_TARGET:    ${KERNEL_TARGET}"
	echo -e "BUILD_ARGS:       ${BUILD_ARGS}"
	echo -e "CROSS_COMPILE:    ${CROSS_COMPILE}"
	echo -e "INSTALL_MOD_PATH: ${INSTALL_MOD_PATH}"
}

build_kernel(){
	make ${KERNEL_TARGET} ${BUILD_ARGS}
}

install_kernel(){
	# Install Modules
	make modules_install ${BUILD_ARGS}
	
	if [ $ARCH == "arm64" ]; then
		# Generate uImage
		mkimage -A ${ARCH} -O linux -T kernel -C none -a 0x1080000 -e 0x1080000 -n linux-next -d ${BUILD_DIR}/arch/${ARCH}/boot/Image ${INSTALL_DIR}/uImage
	elif [ $ARCH == "arm" ]; then
		# Copy zImage
		cp ${BUILD_DIR}/arch/${ARCH}/boot/zImage ${INSTALL_DIR}
	fi

	# Copy dtb
	cd ${BUILD_DIR}/arch/${ARCH}/boot/dts/
	echo $PWD
	cp ${DTB_FILE} ${INSTALL_DIR}
	cd -
	# Copy dts
	cd ./arch/${ARCH}/boot/dts/
	echo $PWD
	cp ${DTB_FILE} ${INSTALL_DIR}
	cd -
	# Copy .config
	cp ${BUILD_DIR}/.config ${INSTALL_DIR}/config
}

archive_kernel(){
	# Input log
	read -p "Input Package Log:" PACK_INFO
	echo $PACK_INFO > ${INSTALL_DIR}/info

	# Package
	#cd $KDIR
	PACK_DATE=`date +%Y%m%d_%H%M`
	PACK_NAME=linux-$(basename "$PWD")_${PACK_DATE}.tar.xz
	# mkdir ${PACK_DIR} > /dev/null 2>&1
	cd ${BUILD_DIR}
	tar cJfp ../${PACK_NAME} ${INSTALL_MOD_PATH}
	echo "Package To ${PACK_NAME}"
}

show_menu(){
	echo "================ Menu Option ================"
	echo -e "\t[1]. Use Default Config"
	echo -e "\t[2]. Menu Config"
	echo -e "\t[3]. Build Kernel"
	echo -e "\t[4]. Install Kernel"
	echo -e "\t[5]. Archive Kernel"
	echo -e "\t[6]. Clean"

	read -p "Please Select: >> " OPT
	case ${OPT} in
		"1")
			make defconfig ${BUILD_ARGS}
			;;
		"2")
			make menuconfig ${BUILD_ARGS}
			;;
		"3")
			build_kernel
			;;
		"4")
			install_kernel
			;;
		"5")
			archive_kernel
			;;
		"6")
			make clean ${BUILD_ARGS}
			rm ${INSTALL_MOD_PATH}/* -rf
			;;
		"mrproper")
			# Hide Option
			make mrproper
			;;
		*)
			echo "Not Support Option: [${OPT}]"
			;;
	esac
}

main(){
	source_env $0
	build_info
	show_menu
}

main
