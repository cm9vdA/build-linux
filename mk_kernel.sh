#!/bin/bash

set -euo pipefail

WORKSPACE_PATH="${PWD}"
SCRIPT_NAME="${0##*/}"
# SCRIPT_PATH=`S=\`readlink "$0"\`; [ -z "$S" ] && S=$0; dirname $S`
SCRIPT_PATH="$(dirname $(readlink -f $0))"

# Load common functions
if [ -f "${SCRIPT_PATH}/common.sh" ]; then
	source "${SCRIPT_PATH}/common.sh"
else
	echo "Missing common.sh script!"
	exit 1
fi

# Check dependencies
required_bins=(make git dpkg mkimage tar gzip time)
for bin in "${required_bins[@]}"; do
	command -v "$bin" >/dev/null || {
		echo "$bin not found. Please install it."
		exit 1
	}
done

init() {
	# Source env
	ENV_FILE="${SCRIPT_PATH}/env/${SCRIPT_NAME}"
	source "${ENV_FILE}"

	for var in BOARD_NAME PACK_NAME CPU_INFO VENDOR DT_FILE; do
		check_param "$var"
	done

	if [ "${NO_CROSS_COMPILE:-}" == "1" ]; then
		# No use cross compile toolchain on same platform
		if ([ "${HOST_ARCH:-}" == "aarch64" ] && [ "${ARCH}" == "arm64" ]) ||
			([ "${HOST_ARCH:0:3}" == "arm" ] && [ "${ARCH}" == "arm" ]); then
			unset CROSS_COMPILE
		fi
	fi

	# Common Variable
	export PATH="${TOOLCHAIN_PATH}/${TOOLCHAIN_NAME}/bin:${PATH}"
	export INSTALL_MOD_PATH="${WORKSPACE_PATH}/install"
	export INSTALL_HDR_PATH="${INSTALL_MOD_PATH}"
	export INSTALL_MOD_STRIP=1

	if [ "${DT_TYPE}" != "mainline" ]; then
		KERNEL_SRC="${WORKSPACE_PATH}/linux-${DT_TYPE}"
		BUILD_PATH="${WORKSPACE_PATH}/.build-${DT_TYPE}"
	else
		KERNEL_SRC="${WORKSPACE_PATH}/linux"
		BUILD_PATH="${WORKSPACE_PATH}/.build"
	fi

	# Check kernel source
	if [ ! -e "${KERNEL_SRC}" ]; then
		echo "Please link the kernel source directory to '${KERNEL_SRC}'."
		exit 1
	fi

	KERNEL_VERSION=$(make -s -C ${KERNEL_SRC} kernelversion)
	export KERNELRELEASE="${KERNEL_VERSION}-${KERNEL_BRANCH}-${ARCH}"
	BUILD_ARGS="-j$(nproc) O=${BUILD_PATH} KERNELRELEASE=${KERNELRELEASE}"

	DEFCONFIG="${ARCH_DEFCONFIG:-}"
	if [ -n "${BOARD_DEFCONFIG:-}" ]; then
		DEFCONFIG="${BOARD_DEFCONFIG}"
	fi

	ADDITIONAL_CONFIG="${SCRIPT_PATH}/boot/configs/${VENDOR}/${DT_TYPE}/${DT_FILE}.config"
	if [ -f "${ADDITIONAL_CONFIG}" ]; then
		DEFCONFIG="${DEFCONFIG} ${DT_FILE}.config"
	fi

	KERNEL_CURRENT=$(git -C ${KERNEL_SRC} config remote.origin.url 2>/dev/null || echo "Archive File")
}

build_info() {
	echo "================ Build Info ================"
	echo -e "BOARD_NAME:       ${BOARD_NAME}"
	echo -e "CPU_INFO:         ${CPU_INFO}"
	echo -e "DT_FILE:          ${DT_FILE}.dts"
	echo -e "ARCH:             ${ARCH}"
	echo -e "KERNEL_VERSION:   ${KERNEL_VERSION}"
	echo -e "KERNEL_CURRENT:   ${KERNEL_CURRENT}"
	echo -e "KERNEL_RECOMMEND: ${KERNEL_RECOMMEND}"
	echo -e "DEFCONFIG:        ${DEFCONFIG}"
	echo -e "BUILD_ARGS:       ${BUILD_ARGS}"
	echo -e "CROSS_COMPILE:    ${CROSS_COMPILE}"
	echo -e "INSTALL_MOD_PATH: ${INSTALL_MOD_PATH}"
	echo -e "INSTALL_HDR_PATH: ${INSTALL_HDR_PATH}"
}

build_kernel() {
	cd ${KERNEL_SRC}
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
	local dts_path kernel_img

	cd "${KERNEL_SRC}"
	rm -rf "${INSTALL_MOD_PATH}"

	# Install Modules
	TIME="Total Time: %E\tExit:%x" time make modules_install ${BUILD_ARGS}

	# Copy Kernel
	if [ "$ARCH" == "arm64" ]; then
		kernel_img="${BUILD_PATH}/arch/${ARCH}/boot/Image"
		if [ "${KERNEL_FMT}" == "gzip" ]; then
			gzip -9cnk "${kernel_img}" > "${INSTALL_MOD_PATH}/Image.gz"
		else
			# Generate uImage
			mkimage -A "${ARCH}" -O linux -T kernel -C none -a 0x1080000 -e 0x1080000 -n linux-next -d "${kernel_img}" "${INSTALL_MOD_PATH}/uImage"
		fi
	elif [ "$ARCH" == "arm" ]; then
		# Copy zImage
		cp -f "${BUILD_PATH}/arch/${ARCH}/boot/${KERNEL_TARGET}" "${INSTALL_MOD_PATH}"
	fi

	# Copy dts/dtb
	if [ "$ARCH" == "arm64" ]; then
		dts_path="arch/${ARCH}/boot/dts/${VENDOR}"
	elif [ "$ARCH" == "arm" ]; then
		dts_path="arch/${ARCH}/boot/dts"
	fi

	cp -f "${KERNEL_SRC}/${dts_path}/${DT_FILE}.dts" "${INSTALL_MOD_PATH}/"
	cp -f "${BUILD_PATH}/${dts_path}/${DT_FILE}.dtb" "${INSTALL_MOD_PATH}/"

	if [ -n "${DT_INC_FILE}" ]; then
		cp -f "${KERNEL_SRC}/${dts_path}/${DT_INC_FILE}.dtsi" "${INSTALL_MOD_PATH}/"
	fi

	# Copy .config
	cp -f "${BUILD_PATH}/.config" "${INSTALL_MOD_PATH}/config"

	cd "${WORKSPACE_PATH}"
}

install_headers() {
	cd "${KERNEL_SRC}"
	# Install Headers
	TIME="Total Time: %E\tExit:%x" time make headers_install ${BUILD_ARGS} INSTALL_HDR_PATH="${INSTALL_HDR_PATH}"
}

archive_kernel() {
	local pack_info
	# Input log
	read -p "Input Package Log:" pack_info
	echo "${pack_info}" >"${INSTALL_MOD_PATH}/info"

	# Package
	#cd $KDIR
	local PACK_NAME="linux_${PACK_NAME}_${KERNEL_VERSION}_$(date +%Y%m%d_%H%M).tar.xz"
	cd "${INSTALL_MOD_PATH}"
	TIME="Total Time: %E\tExit:%x" time tar cJfp "../${PACK_NAME}" *
	echo "Package To ${PACK_NAME}"
}

clean_all() {
	cd "${KERNEL_SRC}"
	make clean ${BUILD_ARGS}
	rm ${INSTALL_MOD_PATH}/* -rf
}

create_deb() {
	local deb_name="${DT_FILE}-kernel"
	local deb_version="${KERNEL_VERSION}-$(date +%Y%m%d%H%M)"
	cd "${WORKSPACE_PATH}"

	rm -rf deb/${deb_name}
	mkdir -p deb/${deb_name}
	cd deb/${deb_name}

	mkdir -p DEBIAN
	mkdir -p boot
	cp -dpr "${INSTALL_MOD_PATH}/lib" ./
	cp "${INSTALL_MOD_PATH}/${DT_FILE}.dtb" ./boot/dtb.img
	cp "${INSTALL_MOD_PATH}/uImage" ./boot

	cat <<EOF >DEBIAN/control
Package: ${deb_name}
Version: ${deb_version}
Architecture: ${ARCH}
Maintainer: test
Installed-Size: $(du -ks | cut -f 1)
Section: test
Priority: optional
Description: kernel for ${BOARD_NAME}

EOF
	# 	cat <<EOF >DEBIAN/postinst

	# EOF
	# 	chmod 775 DEBIAN/postinst
	cd ..
	dpkg -b ${deb_name} ${deb_name}_${KERNEL_VERSION}_${ARCH}.deb
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
	echo -e "\t[4]. Install All"
	echo -e "\t[41] ├─Install Kernel And Modules"
	echo -e "\t[42] └─Install Headers"
	echo -e "\t[5]. Archive Kernel"
	echo -e "\t[6]. Clean"

	read -p "Please Select: >> " OPT
	case ${OPT} in
	"1")
		cd ${KERNEL_SRC}
		make ${DEFCONFIG} ${BUILD_ARGS}
		;;
	"2")
		cd ${KERNEL_SRC}
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
		install_headers
		;;
	"41")
		install_kernel
		;;
	"42")
		install_headers
		;;
	"5")
		archive_kernel
		;;
	"6")
		cd "${KERNEL_SRC}"
		make clean ${BUILD_ARGS}
		rm ${INSTALL_MOD_PATH}/* -rf
		;;
	"mrproper")
		cd "${KERNEL_SRC}"
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
	local dts_in_vendor=0
	local dts_link dts_src defconfig_path

	if [ "$ARCH" == "arm64" ] || [ "$(compare_versions "${KERNEL_VERSION}" "6.4.0")" -eq 1 ]; then
		dts_in_vendor=1
	fi

	# link dts
	dts_src="${SCRIPT_PATH}/boot/dts/${VENDOR}/${DT_TYPE}/"
	if [ $dts_in_vendor -eq 1 ]; then
		dts_link="${KERNEL_SRC}/arch/${ARCH}/boot/dts/${VENDOR}"
	else
		dts_link="${KERNEL_SRC}/arch/${ARCH}/boot/dts"
	fi
	link_file "${dts_src}/${DT_FILE}.dts" "${dts_link}/${DT_FILE}.dts"
	if [ "${DT_INC_FILE:-}" != "" ]; then
		link_file "${dts_src}/${DT_INC_FILE}.dtsi" "${dts_link}/${DT_INC_FILE}.dtsi"
	fi

	# add dtb to Makefile
	grep -q "${DT_FILE}" "${dts_link}/Makefile"
	if [ $? -ne 0 ]; then
		echo "dtb-y += ${DT_FILE}.dtb" >>"${dts_link}/Makefile"
	fi

	# link defconfig
	if [ "${BOARD_DEFCONFIG:-}" != "" ]; then
		defconfig_path="${SCRIPT_PATH}/boot/configs/${VENDOR}/${DT_TYPE}/${BOARD_DEFCONFIG}"
		link_file "${defconfig_path}" "${KERNEL_SRC}/arch/${ARCH}/configs/"
	fi
	if [ -f "${ADDITIONAL_CONFIG}" ]; then
		ln -nfs "${ADDITIONAL_CONFIG}" "${KERNEL_SRC}/arch/${ARCH}/configs/"
	fi
}

main() {
	init
	build_info
	build_probe
	show_menu
}

main
