#!/bin/bash

WORKSPACE_PATH=${PWD}
KERNEL_SRC="${WORKSPACE_PATH}/linux"

SCRIPT_NAME=${0##*/}
# SCRIPT_PATH=`S=\`readlink "$0"\`; [ -z "$S" ] && S=$0; dirname $S`
SCRIPT_PATH=$(dirname $(readlink -f $0))
source ${SCRIPT_PATH}/common.sh

init() {
	# Check kernel source
	if [ ! -e "${KERNEL_SRC}" ]; then
		echo "Please link the kernel source directory to 'linux'."
		exit 1
	fi

	# Source env
	ENV_FILE="${SCRIPT_PATH}/env/${SCRIPT_NAME}"
	source ${ENV_FILE}

	HOST_ARCH=$(uname -m)
	if [ "${NO_CROSS_COMPILE}" == "1" ]; then
		# No use cross compile toolchain on same platform
		if ([ "${HOST_ARCH}" == "aarch64" ] && [ "${ARCH}" == "arm64" ]) || ([ "${HOST_ARCH:0:3}" == "arm" ] && [ "${ARCH}" == "arm" ]); then
			unset CROSS_COMPILE
		fi
	fi

	# Common Variable
	export PATH="${TOOLCHAIN_PATH}/${TOOLCHAIN_NAME}/bin:${PATH}"
	export INSTALL_MOD_PATH="${WORKSPACE_PATH}/install"

	BUILD_PATH="${WORKSPACE_PATH}/.build"
	BUILD_ARGS="-j$(nproc) O=${BUILD_PATH}"

	cd "${KERNEL_SRC}"
	KERNEL_VERSION=$(make kernelversion)
}

check_env() {
	# Check Env
	if [ "$ARCH" != "arm64" ] && [ "$ARCH" != "arm" ]; then
		echo "Invalid arch: ${ARCH}"
		exit 1
	fi

	if [ "$ARCH" == "arm64" ]; then
		check_var VENDOR "${VENDOR}"
	fi
	# if [ "$ARCH" == "arm" ]; then

	# fi
	check_var DT_PATH "${DT_PATH}"
}

build_info() {
	echo "================ Build Info ================"
	echo -e "BOARD_NAME:       ${BOARD_NAME}"
	echo -e "CPU_INFO:         ${CPU_INFO}"
	echo -e "DT_FILE:          ${DT_FILE}"
	echo -e "ARCH:             ${ARCH}"
	echo -e "KERNEL_VERSION:   ${KERNEL_VERSION}"
	echo -e "DEFCONFIG:        ${DEFCONFIG}"
	echo -e "BUILD_ARGS:       ${BUILD_ARGS}"
	echo -e "CROSS_COMPILE:    ${CROSS_COMPILE}"
	echo -e "INSTALL_MOD_PATH: ${INSTALL_MOD_PATH}"
}

build_kernel() {
	case $1 in
	"kernel")
		TIME="Total Time: %E\tExit:%x" time make ${KERNEL_TARGET} ${BUILD_ARGS}
		;;
	"modules")
		TIME="Total Time: %E\tExit:%x" time make modules ${BUILD_ARGS}
		;;
	"dtbs")
		if [ "${DT_FILE}" != "" ]; then
			TIME="Total Time: %E\tExit:%x" time make dtbs ${BUILD_ARGS}
		fi
		;;
	*)
		echo "Invalid Parmameter: [$1]"
		;;
	esac
	return $?
}

install_kernel() {
	rm -rf ${INSTALL_MOD_PATH}
	# Install Modules
	TIME="Total Time: %E\tExit:%x" time make modules_install ${BUILD_ARGS}

	if [ "$ARCH" == "arm64" ]; then
		# Generate uImage
		mkimage -A "${ARCH}" -O linux -T kernel -C none -a 0x1080000 -e 0x1080000 -n linux-next -d "${BUILD_PATH}/arch/${ARCH}/boot/Image" "${INSTALL_MOD_PATH}/uImage"
	elif [ "$ARCH" == "arm" ]; then
		# Copy zImage
		cp -f "${BUILD_PATH}/arch/${ARCH}/boot/${KERNEL_TARGET}" "${INSTALL_MOD_PATH}"
	fi

	# Copy dts/dtb
	if [ "${DT_FILE}" != "" ]; then
		if [ "$ARCH" == "arm64" ]; then
			local _DT_PATH="arch/${ARCH}/boot/dts/${VENDOR}"
		elif [ "$ARCH" == "arm" ]; then
			local _DT_PATH="arch/${ARCH}/boot/dts/"
		fi

		cp -f "${KERNEL_SRC}/${_DT_PATH}/${DT_FILE}.dts" "${INSTALL_MOD_PATH}"
		cp -f "${BUILD_PATH}/${_DT_PATH}/${DT_FILE}.dtb" "${INSTALL_MOD_PATH}"
	fi

	cd "${WORKSPACE_PATH}"
	# Copy .config
	cp -f "${BUILD_PATH}/.config" "${INSTALL_MOD_PATH}/config"
}

archive_kernel() {
	# Input log
	read -p "Input Package Log:" PACK_INFO
	echo "$PACK_INFO" >"${INSTALL_MOD_PATH}/info"

	# Package
	#cd $KDIR
	local PACK_DATE=$(date +%Y%m%d_%H%M)
	local PACK_NAME="linux_${PACK_NAME}_${KERNEL_VERSION}_${PACK_DATE}.tar.xz"
	cd "${INSTALL_MOD_PATH}"
	TIME="Total Time: %E\tExit:%x" time tar cJfp "../${PACK_NAME}" *
	echo "Package To ${PACK_NAME}"
}

show_menu() {
	cd "${KERNEL_SRC}"

	echo "================ Menu Option ================"
	echo -e "\t[1]. Use Default Config"
	echo -e "\t[2]. Menu Config"
	echo -e "\t[3]. Build All"
	echo -e "\t[31] ├─Build Kernel"
	echo -e "\t[32] ├─Build Modules"
	echo -e "\t[33] └─Build DTB"
	echo -e "\t[4]. Install Kernel"
	echo -e "\t[5]. Archive Kernel"
	echo -e "\t[6]. Clean"

	read -p "Please Select: >> " OPT
	case ${OPT} in
	"1")
		if [ "${DEFCONFIG}" != "" ]; then
			make ${DEFCONFIG} ${BUILD_ARGS}
		else
			make defconfig ${BUILD_ARGS}
		fi
		;;
	"2")
		make menuconfig ${BUILD_ARGS}
		;;
	"3")
		build_kernel kernel
		if [ $? != 0 ]; then
			exit -1
		fi
		build_kernel modules
		if [ $? != 0 ]; then
			exit -1
		fi
		build_kernel dtbs
		;;
	"31")
		build_kernel kernel
		;;
	"32")
		build_kernel modules
		;;
	"33")
		build_kernel dtbs
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
	"0")
		# Hide Option
		echo "apt install flex bison time bc kmod u-boot-tools libncurses5-dev libgmp-dev libmpc-dev libssl-dev"
		;;
	*)
		echo "Not Support Option: [${OPT}]"
		;;
	esac
}

build_probe() {
	# link dts
	if [ "${DT_FILE}" != "" ]; then
		DT_PATH="${SCRIPT_PATH}/boot/dts/${VENDOR}/mainline/${DT_FILE}"
		if [ "$ARCH" == "arm64" ]; then
			DT_PATH_LINK="${KERNEL_SRC}/arch/${ARCH}/boot/dts/${VENDOR}/"
		elif [ "$ARCH" == "arm" ]; then
			DT_PATH_LINK="${KERNEL_SRC}/arch/${ARCH}/boot/dts/"
		fi
		check_path DTS "${DT_PATH}.dts"
		ln -s -f "${DT_PATH}.dts" ${DT_PATH_LINK}
	fi

	# link defconfig
	if [ "${DEFCONFIG}" != "" ]; then
		DEFCONFIG_PATH="${SCRIPT_PATH}/boot/configs/${DEFCONFIG}"
		check_path "DEFCONFIG" "${DEFCONFIG_PATH}"
		ln -s -f ${DEFCONFIG_PATH} "${KERNEL_SRC}/arch/${ARCH}/configs/"
	fi
}

main() {
	init
	build_info
	build_probe
	show_menu
}

main
