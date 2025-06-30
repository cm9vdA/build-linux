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
	echo "Missing common.sh script!"
	exit 1
fi

init() {
	# Source env
	source "${SCRIPT_PATH}/env/${SCRIPT_NAME}"

	for var in BOARD_NAME PACK_NAME CPU_INFO VENDOR BOARD_CODE; do
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

	if [ "${KERNEL_NAME}" != "mainline" ]; then
		KERNEL_SRC="${WORKSPACE_PATH}/linux-${KERNEL_NAME}"
		BUILD_PATH="${WORKSPACE_PATH}/.build_kernel-${KERNEL_NAME}"
	else
		KERNEL_SRC="${WORKSPACE_PATH}/linux"
		BUILD_PATH="${WORKSPACE_PATH}/.build_kernel"
	fi

	# Check kernel source
	if [ ! -e "${KERNEL_SRC}" ]; then
		echo_error "Please link the kernel source directory to '${KERNEL_SRC}'."
		exit 1
	fi

	KERNEL_VERSION=$(make -s -C ${KERNEL_SRC} kernelversion)
	export KERNELRELEASE="${KERNEL_VERSION}-${KERNEL_NAME}-${ARCH}"
	BUILD_ARGS="-j$(nproc) O=${BUILD_PATH} KERNELRELEASE=${KERNELRELEASE}"

	DEFCONFIG="${ARCH_DEFCONFIG:-}"
	if [ -n "${BOARD_DEFCONFIG:-}" ]; then
		DEFCONFIG="${BOARD_DEFCONFIG}"
	fi

	ADDITIONAL_CONFIG="${SCRIPT_PATH}/boot/configs/${VENDOR}/${KERNEL_TYPE}/${BOARD_CODE}.config"
	if [ -f "${ADDITIONAL_CONFIG}" ]; then
		DEFCONFIG="${DEFCONFIG} ${BOARD_CODE}.config"
	fi

	KERNEL_CURRENT=$(git -C ${KERNEL_SRC} config remote.origin.url 2>/dev/null || echo "Archive File")
	KERNEL_CURRENT_BRANCH="$(git -C ${KERNEL_SRC} describe --all --exact-match HEAD 2>/dev/null || echo "Detached at $(git rev-parse --short HEAD)")"
}

build_info() {
	echo_title "================ Build Info ================"
	echo_item "BOARD_NAME" "${BOARD_NAME}"
	echo_item "CPU_INFO" "${CPU_INFO}"
	echo_item "BOARD_CODE" "${BOARD_CODE}"
	echo_item "ARCH" "${ARCH}"
	echo_item "KERNEL_NAME" "${KERNEL_NAME}"
	echo_item "KERNEL_VERSION" "${KERNEL_VERSION}"
	echo_item "KERNEL_CURRENT" "${KERNEL_CURRENT} ${KERNEL_CURRENT_BRANCH}"
	echo_item "KERNEL_COMPATIBLE" "${KERNEL_COMPATIBLE} ${KERNEL_COMPATIBLE_BRANCH:-}"
	echo_item "DEFCONFIG" "${DEFCONFIG}"
	echo_item "BUILD_ARGS" "${BUILD_ARGS}"
	echo_item "CROSS_COMPILE" "${CROSS_COMPILE:-}"
	echo_item "INSTALL_MOD_PATH" "${INSTALL_MOD_PATH}"
	echo_item "INSTALL_HDR_PATH" "${INSTALL_HDR_PATH}"
}

build_kernel() {
	local target="$1"
	local make_target=""
	local valid=1

	check_dependency "${DEPENDENCY_LIST}"

	# 参数检查
	if [ -z "${target}" ]; then
		echo_error "Missing build target (e.g., kernel/modules/dtbs)"
		return 1
	fi

	case "${target}" in
	kernel) make_target="${KERNEL_TARGET}" ;;
	modules) make_target="modules" ;;
	dtbs)
		if [ -z "${BOARD_CODE}" ]; then
			echo_warn "BOARD_CODE not set, skipping dtbs build"
			return 0
		fi
		make_target="dtbs"
		;;
	*)
		echo_error "Invalid Target: ${target}"
		valid=0
		;;
	esac

	if [ "${valid}" -eq 1 ]; then
		cd "${KERNEL_SRC}"
		TIME="Total Time: %E\tExit:%x" time make ${make_target} ${BUILD_ARGS}
		return $?
	fi

	return 1
}

install_kernel() {
	local dts_path kernel_img

	check_dependency "${DEPENDENCY_LIST}"

	cd "${KERNEL_SRC}"
	rm -rf "${INSTALL_MOD_PATH}"

	# Install Modules
	TIME="Total Time: %E\tExit:%x" time make modules_install ${BUILD_ARGS}

	# Copy Kernel
	if [ "$ARCH" == "arm64" ]; then
		kernel_img="${BUILD_PATH}/arch/${ARCH}/boot/Image"
		if [ "${KERNEL_FMT:-}" == "gzip" ]; then
			gzip -9cnk "${kernel_img}" >"${INSTALL_MOD_PATH}/Image.gz"
		elif [ "${KERNEL_FMT:-}" == "uboot" ]; then
			# Generate uImage
			mkimage -A "${ARCH}" -O linux -T kernel -C none -a 0x1080000 -e 0x1080000 -n linux-next -d "${kernel_img}" "${INSTALL_MOD_PATH}/uImage"
		else
			cp -f "${kernel_img}" "${INSTALL_MOD_PATH}"
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

	cp -f "${KERNEL_SRC}/${dts_path}/${BOARD_CODE}.dts" "${INSTALL_MOD_PATH}/"
	cp -f "${BUILD_PATH}/${dts_path}/${BOARD_CODE}.dtb" "${INSTALL_MOD_PATH}/"

	if [ -n "${DT_INC_FILE:-}" ]; then
		cp -f "${KERNEL_SRC}/${dts_path}/${DT_INC_FILE}.dtsi" "${INSTALL_MOD_PATH}/"
	fi

	# Copy .config
	cp -f "${BUILD_PATH}/.config" "${INSTALL_MOD_PATH}/config"

	cd "${WORKSPACE_PATH}"
}

install_headers() {
	check_dependency "${DEPENDENCY_LIST}"

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
	echo_info "Package to ${PACK_NAME}"
}

clean_all() {
	cd "${KERNEL_SRC}"
	make clean ${BUILD_ARGS}
	rm ${INSTALL_MOD_PATH}/* -rf
}

create_deb() {
	local deb_name="${BOARD_CODE}-kernel"
	local deb_version="${KERNEL_VERSION}-$(date +%Y%m%d%H%M)"

	check_dependency "${DEPENDENCY_LIST}"

	cd "${WORKSPACE_PATH}"

	rm -rf deb/${deb_name}
	mkdir -p deb/${deb_name}
	cd deb/${deb_name}

	mkdir -p DEBIAN
	mkdir -p boot
	cp -dpr "${INSTALL_MOD_PATH}/lib" ./
	cp "${INSTALL_MOD_PATH}/${BOARD_CODE}.dtb" ./boot/dtb.img
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

	echo_title "================ Menu Option ================"
	echo_menu 0 " Install Required Packages"
	echo_menu 1 " Use Default Config"
	echo_menu 2 " Menu Config"
	echo_menu 3 " Build All"
	echo_menu 31 "├─ Build Kernel"
	echo_menu 32 "├─ Build Modules"
	echo_menu 33 "└─ Build DTB"
	echo_menu 4 " Install All"
	echo_menu 41 "├─ Install Kernel and Modules"
	echo_menu 42 "└─ Install Headers"
	echo_menu 5 " Archive Kernel"
	echo_menu 6 " Clean"

	read -rp "Please Select: >> " OPT
	case ${OPT} in
	0) install_pkg "${PKG_LIST}" ;;
	1) check_dependency "${DEPENDENCY_LIST}" && make ${DEFCONFIG} ${BUILD_ARGS} ;;
	2) check_dependency "${DEPENDENCY_LIST}" && make menuconfig ${BUILD_ARGS} ;;
	3) build_kernel kernel && build_kernel modules && build_kernel dtbs ;;
	31) build_kernel kernel ;;
	32) build_kernel modules ;;
	33) build_kernel dtbs ;;
	4) install_kernel && install_headers ;;
	41) install_kernel ;;
	42) install_headers ;;
	5) archive_kernel ;;
	6) make clean ${BUILD_ARGS} && rm -rf "${INSTALL_MOD_PATH:?}"/* ;;
	mrproper) make mrproper ${BUILD_ARGS} ;;
	*) echo_error "Invalid Option: [${OPT}]" ;;
	esac
}

build_probe() {
	local dts_in_vendor=0
	local dts_link dts_src defconfig_path

	if [ "$ARCH" == "arm64" ] || [ "$(compare_versions "${KERNEL_VERSION}" "6.4.0")" -eq 1 ]; then
		dts_in_vendor=1
	fi

	# link dts
	dts_src="${SCRIPT_PATH}/boot/dts/${VENDOR}/${KERNEL_TYPE}/"
	if [ $dts_in_vendor -eq 1 ]; then
		dts_link="${KERNEL_SRC}/arch/${ARCH}/boot/dts/${VENDOR}"
	else
		dts_link="${KERNEL_SRC}/arch/${ARCH}/boot/dts"
	fi
	link_file "${dts_src}/${BOARD_CODE}.dts" "${dts_link}/${BOARD_CODE}.dts"
	if [ "${DT_INC_FILE:-}" != "" ]; then
		link_file "${dts_src}/${DT_INC_FILE}.dtsi" "${dts_link}/${DT_INC_FILE}.dtsi"
	fi

	# add dtb to Makefile
	if ! grep -q "${BOARD_CODE}" "${dts_link}/Makefile"; then
		echo "dtb-y += ${BOARD_CODE}.dtb" >>"${dts_link}/Makefile"
	fi

	# link defconfig
	if [ "${BOARD_DEFCONFIG:-}" != "" ]; then
		defconfig_path="${SCRIPT_PATH}/boot/configs/${VENDOR}/${KERNEL_TYPE}/${BOARD_DEFCONFIG}"
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
