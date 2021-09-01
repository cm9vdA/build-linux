#!/bin/bash

# Other Environment Variable
export XZ_DEFAULTS="-T 0"

WORKSPACE_PATH=${PWD}
UBOOT_SRC="${WORKSPACE_PATH}/uboot"

source_env(){
	SCRIPT_NAME=${0##*/}
	# SCRIPT_PATH=`S=\`readlink "$0"\`; [ -z "$S" ] && S=$0; dirname $S`
	SCRIPT_PATH=$(dirname $(readlink -f $0))
	ENV_FILE="${SCRIPT_PATH}/env/${SCRIPT_NAME}"

	source ${ENV_FILE}

	HOST_ARCH=`uname -m`

	# Common Variable
	export PATH="${TOOLCHAIN_DIR}/${TOOLCHAIN_NAME}/bin:$PATH"

	BUILD_PATH="${WORKSPACE_PATH}/.build_uboot"
	BUILD_ARGS="-j$(nproc) O=${BUILD_PATH}"

	cd "${UBOOT_SRC}"
	UBOOT_VERSION=`make ubootversion`
}

build_info(){
	echo "================ Build Info ================"
	echo -e "BOARD_NAME:       ${BOARD_NAME}"
	echo -e "CPU_INFO:         ${CPU_INFO}"
	echo -e "ARCH:             ${ARCH}"
	echo -e "UBOOT_VERSION:    ${UBOOT_VERSION}"
	echo -e "BUILD_ARGS:       ${BUILD_ARGS}"
	echo -e "CROSS_COMPILE:    ${CROSS_COMPILE}"
}

check_path(){
	if [ ! -e "${UBOOT_SRC}" ]; then
		echo "Please link the uboot source directory to 'uboot'."
		exit 1
	fi
}

process(){
	echo "process"
}

show_menu(){
	cd "${UBOOT_SRC}"

	echo "================ Menu Option ================"
	echo -e "\t[1]. Use Default Config"
	echo -e "\t[2]. Menu Config"
	echo -e "\t[3]. Build U-boot"
	echo -e "\t[4]. Process"
	echo -e "\t[5]. Clean"

	read -p "Please Select: >> " OPT
	case ${OPT} in
		"1")
			make ${DEVICE_CONFIG} ${BUILD_ARGS}
			;;
		"2")
			make menuconfig ${BUILD_ARGS}
			;;
		"3")
			TIME="Total Time: %E\tExit:%x" time make ${BUILD_ARGS}
			;;
		"4")
			process
			;;
		"5")
			make clean ${BUILD_ARGS}
			;;
		"mrproper")
			# Hide Option
			make mrproper
			;;
		"0")
			# Hide Option
			echo "apt install flex bison time bc kmod u-boot-tools libncurses5-dev libgmp-dev libmpc-dev libssl-dev"
			;;
		*)
			echo "Not Support Option: [${OPT}]"
			;;
	esac
}

main(){
	check_path
	source_env $0
	build_info
	show_menu
}

main