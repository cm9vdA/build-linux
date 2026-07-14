setenv devtype mmc
setenv devnum 0

setenv kernel_file zImage
setenv fdt_file dtb.img
setenv kernel_addr_r 0x42000000
setenv fdt_addr_r 0x43000000
setenv load_addr 0x44000000
setenv rootdev "/dev/mmcblk${devnum}p2"
setenv bootargs "noinitrd root=${rootdev} rootfstype=ext4 rootwait rootdelay=1 rootflags=data=writeback rw earlycon console=ttyS0,115200n8 consoleblank=0 docker_optimizations"

echo "Boot script loaded from ${devtype} ${devnum}:${distro_bootpart}"

test -n "${distro_bootpart}" || distro_bootpart=1

if test -e ${devtype} ${devnum}:${distro_bootpart} env.txt; then
	load ${devtype} ${devnum}:${distro_bootpart} ${load_addr} env.txt
	env import -t ${load_addr} ${filesize}
fi

if fatload ${devtype} ${devnum}:${distro_bootpart} ${kernel_addr_r} ${kernel_file}; then
    echo "Kernel loaded."
else
    echo "Cannot load ${kernel_file}"
    exit
fi

if fatload ${devtype} ${devnum}:${distro_bootpart} ${fdt_addr_r} ${fdt_file}; then
    echo "DTB loaded."
else
    echo "Cannot load ${fdt_file}"
    exit
fi

echo "Booting from ${devtype}${devnum}:${distro_bootpart}"
echo "Kernel : ${kernel_file}"
echo "DTB    : ${fdt_file}"
echo "Rootfs : ${rootdev}"
echo "bootargs: ${bootargs}"

echo "Start Kernel..."

bootz ${kernel_addr_r} - ${fdt_addr_r}

# mkimage -A arm -O linux -T script -C none -a 0 -e 0 -n 'Execute Boot Script' -d boot.cmd boot.scr
