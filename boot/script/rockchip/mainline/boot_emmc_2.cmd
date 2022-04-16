setenv dtb_name "dtb.img"
setenv dtb_mem_addr "0x1000000"
setenv kernel_name "uImage"
setenv kernel_mem_addr "0x1080000"
setenv fs_arg_dev "/dev/mmcblk2p2"
setenv fs_arg_mmc "noinitrd root=${fs_arg_dev} rootfstype=ext4 rootdelay=1 rootflags=data=writeback rw"
setenv boot_start bootm $kernel_mem_addr - $dtb_mem_addr
setenv bootargs "${fs_arg_mmc}"
fatload mmc 1 $dtb_mem_addr $dtb_name
fatload mmc 1 $kernel_mem_addr $kernel_name
run boot_start