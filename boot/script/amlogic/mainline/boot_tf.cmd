setenv dtb_name "dtb.img"
setenv dtb_mem_addr "0x1000000"
setenv kernel_name "uImage"
setenv kernel_mem_addr "0x1080000"
setenv condev "console=ttyAML0,115200 console=tty0 consoleblank=0"
setenv fs_arg_dev "/dev/mmcblk1p2"
setenv fs_arg_mmc "noinitrd root=${fs_arg_dev} rootfstype=ext4 rootdelay=1 rootflags=data=writeback rw"
setenv net_arg "net.ifnames=0 mac=${mac}"
setenv boot_start bootm $kernel_mem_addr - $dtb_mem_addr
setenv bootargs "${fs_arg_mmc} ${condev} ${net_arg}"
fatload mmc 1 $dtb_mem_addr $dtb_name
fatload mmc 1 $kernel_mem_addr $kernel_name
run boot_start