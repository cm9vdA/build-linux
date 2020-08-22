setenv dtb_name "dtb.img"
setenv dtb_mem_addr "0x1000000"
setenv kernel_name "uImage"
setenv kernel_mem_addr "0x1080000"
setenv ethaddr "0a:1b:2c:3d:4e:5f"
setenv init_hdmi "logo=osd1,loaded,${fb_addr},${hdmimode} vout=${hdmimode},enable";
setenv condev "console=ttyAML0,115200 console=tty0 consoleblank=0";
setenv fs_arg_mmc "noinitrd root=/dev/mmcblk1p2 rootfstype=ext4 rootdelay=1 rootflags=data=writeback rw"
setenv net_arg "net.ifnames=0"
setenv boot_start bootm $kernel_mem_addr - $dtb_mem_addr;
setenv bootargs "${fs_arg_mmc} ${init_hdmi} ${condev} ${net_arg}"
fatload mmc 2 $kernel_mem_addr $kernel_name
fatload mmc 2 $dtb_mem_addr $dtb_name
run boot_start
