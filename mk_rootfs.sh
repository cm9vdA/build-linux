#!/bin/bash

source_env(){
	SCRIPT_NAME=${0##*/}
	# SCRIPT_PATH=$(cd "$(dirname "$0")"; pwd)
	# SCRIPT_PATH=`S=\`readlink "$0"\`; [ -z "$S" ] && S=$0; dirname $S`
	SCRIPT_PATH=$(dirname $(readlink -f $0))
	ENV_FILE=${SCRIPT_PATH}/env/${SCRIPT_NAME}
	HOST_ARCH=`uname -m`

	source ${ENV_FILE}

	# Other Environment Variable
	XZ_DEFAULTS="-T 0"
	MIRROR_URL=http://mirrors.ustc.edu.cn/debian/
	DEBOOTSTRAP_ENV="LC_ALL=en_US.UTF-8 LANGUAGE=en_US.UTF-8 LANG=en_US.UTF-8 DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true"
}

build_info(){
	echo "================ Build Info ================"
	echo -e "ARCH:            ${ARCH}"
	echo -e "TARGET_ARCH:     ${TARGET_ARCH}"
	echo -e "TARGET_VERSION:  ${TARGET_VERSION}"
	echo -e "TARGET_ROOTFS:   ${TARGET_FS}"
	echo -e "MIRROR_URL:      ${MIRROR_URL}"
}

install_software(){
	if ([ "${HOST_ARCH}" == "aarch64" ] && [ "${ARCH}" == "arm64" ]) || ([ "${HOST_ARCH:0:3}" == "arm" ] && [ "${ARCH}" == "arm" ]); then
		SOFTWARE_LIST="binfmt-support debootstrap"
	else 
		SOFTWARE_LIST="binfmt-support qemu qemu-user-static debootstrap"
	fi
	echo "Install [${SOFTWARE_LIST}]"
	apt install ${SOFTWARE_LIST}
}

create_base_fs(){

	if [ -e ${TARGET_FS} ]; then
		echo "[${TARGET_FS}] Exists"
		return 1
	fi

	echo "Create directory [${TARGET_FS}]"
	mkdir $TARGET_FS
	echo "Stage 1:"
	debootstrap --arch=${ARCH} --foreign ${TARGET_VERSION} ${TARGET_FS}/ ${MIRROR_URL}

	if ([ "${HOST_ARCH}" == "aarch64" ] && [ "${ARCH}" == "arm64" ]) || ([ "${HOST_ARCH:0:3}" == "arm" ] && [ "${ARCH}" == "arm" ]); then
		echo "No need copy qemu-${TARGET_ARCH}-static"
	else
		echo "Copy qemu-${TARGET_ARCH}-static"
		cp /usr/bin/qemu-${TARGET_ARCH}-static ${TARGET_FS}/usr/bin/
	fi

	echo "Stage 2:"
	${DEBOOTSTRAP_ENV} chroot ${TARGET_FS} /debootstrap/debootstrap --second-stage
	echo "Configure Package"
	${DEBOOTSTRAP_ENV} chroot ${TARGET_FS} dpkg --configure -a
	echo "Install Package"
	${DEBOOTSTRAP_ENV} chroot ${TARGET_FS} apt install -y sudo vim openssh-server bash-completion ca-certificates htop locales wget curl
	# dpkg-reconfigure locales
	echo "End Build Base File System"
}

chroot_fs(){
	if [ ! -e ${TARGET_FS} ]; then
		echo "[${TARGET_FS}] Not Exists"
		return 1
	fi
	mount -t proc /proc	${TARGET_FS}/proc
	mount -t sysfs /sys	${TARGET_FS}/sys
	mount -o bind /dev	${TARGET_FS}/dev
	mount -o bind /dev/pts	${TARGET_FS}/dev/pts

	chroot ${TARGET_FS}

	umount $TARGET_FS/proc
	umount $TARGET_FS/sys
	umount $TARGET_FS/dev/pts
	umount $TARGET_FS/dev
}

archive_fs(){
	if [ ! -e ${TARGET_FS} ]; then
		echo "[${TARGET_FS}] Not Exists"
		return 1
	fi
	echo "Start Archive [${TARGET_FS}]"
	PACK_DATE=`date +%Y%m%d_%H%M`
	PACK_NAME=${TARGET_FS}_${PACK_DATE}.xz.tar
	tar cJfp ${PACK_NAME} --exclude=$TARGET_FS/usr/bin/qemu-${TARGET_ARCH}-static ${TARGET_FS}
	echo "End Archive"
}

copy_fs(){
	if [ ! -e ${TARGET_FS} ]; then
		echo "[${TARGET_FS}] Not Exists"
		return 1
	fi

	read -p "Input TF Path: " TF_PATH
	if [ ! -e ${TF_PATH} ]; then
		echo "[${TF_PATH}] Not Exists"
		return 2
	fi

	echo "Start Copy [${TARGET_FS}] To ${TF_PATH}"
	cp -pr ${TARGET_FS}/* ${TF_PATH}
	sync
	echo "End Copy"
}

show_menu(){
	echo "================ Menu Option ================"
	echo -e "\t[0]. Install Software"
	echo -e "\t[1]. Create Base ROOTFS"
	echo -e "\t[2]. Chroot to ROOTFS"
	echo -e "\t[3]. Archive ROOTFS"
	echo -e "\t[4]. Copy ROOTFS"
	
	read -p "Please Select:" OPT
	case ${OPT} in
		"0")
			install_software
			;;
		"1")
			create_base_fs
			;;
		"2")
			chroot_fs
			;;
		"3")
			archive_fs
			;;
		"4")
			copy_fs
			;;
		*)
			echo "Not Support Option [${OPT}]"
			;;
	esac
}

main(){
	source_env $0
	build_info
	show_menu
}

main
