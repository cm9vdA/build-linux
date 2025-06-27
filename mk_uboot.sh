#!/bin/bash

set -euo pipefail

# ========= Path Setup =========
WORKSPACE_PATH="${PWD}"
SCRIPT_NAME="${0##*/}"
# SCRIPT_PATH=`S=\`readlink "$0"\`; [ -z "$S" ] && S=$0; dirname $S`
SCRIPT_PATH="$(dirname $(readlink -f $0))"

# ========= Load Common =========
if [ -f "${SCRIPT_PATH}/common.sh" ]; then
	source "${SCRIPT_PATH}/common.sh"
else
	echo_error "Missing common.sh script!"
	exit 1
fi

init() {
	source "${SCRIPT_PATH}/env/${SCRIPT_NAME}"

	for var in BOARD_NAME BOARD_DEFCONFIG CPU_INFO VENDOR BOARD_CODE; do
		check_param "$var"
	done

	export PATH=${PATH}:"${TOOLCHAIN_PATH}/${TOOLCHAIN_NAME}/bin"
	[ -n "${ARM_TOOLCHAIN_NAME:-}" ] && export PATH=${PATH}:"${TOOLCHAIN_PATH}/${ARM_TOOLCHAIN_NAME}/bin"

	# UBOOT_SRC="${WORKSPACE_PATH}/uboot${UBOOT_NAME:+-${UBOOT_NAME}}"
	if [ "${UBOOT_NAME}" != "mainline" ]; then
		UBOOT_SRC="${WORKSPACE_PATH}/uboot-${UBOOT_NAME}"
		BUILD_PATH="${WORKSPACE_PATH}/.build_uboot-${UBOOT_NAME}"
	else
		UBOOT_SRC="${WORKSPACE_PATH}/uboot"
		BUILD_PATH="${WORKSPACE_PATH}/.build_uboot"
	fi

	BUILD_ARGS="-j$(nproc) O=${BUILD_PATH}"
	DEFCONFIG="${BOARD_DEFCONFIG}"

	[ ! -d "${UBOOT_SRC}" ] && echo_error "Please link U-Boot source to '${UBOOT_SRC}'" && exit 1

	cd "${UBOOT_SRC}"
	UBOOT_VERSION=$(make ubootversion)

	UBOOT_CURRENT=$(git -C ${UBOOT_SRC} config remote.origin.url 2>/dev/null || echo "Archive File")
}

build_info() {
	echo_title "========= Build Info ========="
	echo_item "BOARD_NAME" "${BOARD_NAME}"
	echo_item "CPU_INFO" "${CPU_INFO}"
	echo_item "ARCH" "${ARCH}"
	echo_item "UBOOT_NAME" "${UBOOT_NAME}"
	echo_item "UBOOT_VERSION" "${UBOOT_VERSION}"
	echo_item "UBOOT_CURRENT" "${UBOOT_CURRENT}"
	echo_item "UBOOT_COMPATIBLE" "${UBOOT_COMPATIBLE}  ${UBOOT_COMPATIBLE_BRANCH:-}"
	echo_item "DEFCONFIG" "${DEFCONFIG}"
	echo_item "ATF_PLAT" "${ATF_PLAT:-}"
	echo_item "ATF(BL31)" "${BL31:-}"
	[ -n "${ROCKCHIP_TPL:-}" ] && echo_item "ROCKCHIP_TPL" "${ROCKCHIP_TPL}"
	echo_item "BUILD_ARGS" "${BUILD_ARGS}"
	echo_item "CROSS_COMPILE" "${CROSS_COMPILE}"
}

process() {
	echo_error "Function not implemented"
}

build_atf() {
	check_dependency "${DEPENDENCY_LIST}"

	[ -z "${ATF_PLAT:-}" ] && echo_warn "ATF_PLAT not set" && return
	[ ! -d "${ATF_SRC:-}" ] && git clone https://github.com/ARM-software/arm-trusted-firmware.git "${ATF_SRC}"
	cd "${ATF_SRC}"
	unset BL31
	make clean distclean
	git pull
	make CROSS_COMPILE=aarch64-linux-gnu- PLAT=${ATF_PLAT}
}

build_probe() {
	local dts_src="${SCRIPT_PATH}/boot/dts/${VENDOR}/${UBOOT_TYPE}"
	local dts_link="${UBOOT_SRC}/arch/arm/dts"
	local dts_up_link="${UBOOT_SRC}/dts/upstream/src/${UPSTREAM_ARCH}/${VENDOR}"

	link_file "${dts_src}/${BOARD_CODE}.dts" "${dts_link}/${BOARD_CODE}.dts"
	[ -d "${dts_up_link}" ] && link_file "${dts_src}/${BOARD_CODE}.dts" "${dts_up_link}/${BOARD_CODE}.dts"

	if [ -n "${DT_INC_FILE:-}" ]; then
		link_file "${dts_src}/${DT_INC_FILE}.dtsi" "${dts_link}/${DT_INC_FILE}.dtsi"
		[ -d "${dts_up_link}" ] && link_file "${dts_src}/${DT_INC_FILE}.dtsi" "${dts_up_link}/${DT_INC_FILE}.dtsi"
	fi

	if [ -e "${dts_src}/${BOARD_CODE}-u-boot.dtsi" ]; then
		ln -nfs "${dts_src}/${BOARD_CODE}-u-boot.dtsi" "${dts_link}"
		[ -d "${dts_up_link}" ] && ln -nfs "${dts_src}/${BOARD_CODE}-u-boot.dtsi" "${dts_up_link}"
	fi

	# link defconfig
	link_file "${SCRIPT_PATH}/u-boot/${VENDOR}/u-boot-${UBOOT_VERSION}/${BOARD_DEFCONFIG}" "${UBOOT_SRC}/configs/${BOARD_DEFCONFIG}"
}

build_uboot() {
	check_dependency "${DEPENDENCY_LIST}"

	TIME="Total Time: %E\tExit:%x" time make ${BUILD_ARGS}
}

show_menu() {
	cd "${UBOOT_SRC}"
	echo_title "========= Menu Options ========="
	echo_menu 0 "Install Required Packages"
	echo_menu 1 "Use Default Config"
	echo_menu 2 "Menu Config"
	echo_menu 3 "Build U-Boot"
	echo_menu 4 "Custom Process(Not implemented)"
	echo_menu 5 "Clean"

	read -rp "Please Select: >> " OPT
	case ${OPT} in
	0) install_pkg "${PKG_LIST}" ;;
	1) build_probe && make ${DEFCONFIG} ${BUILD_ARGS} ;;
	2) check_dependency "${DEPENDENCY_LIST}" && make menuconfig ${BUILD_ARGS} ;;
	3) build_uboot ;;
	4) process ;;
	5) make clean ${BUILD_ARGS} ;;
	atf) build_atf ;;
	mrproper) make mrproper ${BUILD_ARGS} ;;
	*) echo_error "Invalid Option: [${OPT}]" ;;
	esac
}

main() {
	init
	build_info
	show_menu
}

main
