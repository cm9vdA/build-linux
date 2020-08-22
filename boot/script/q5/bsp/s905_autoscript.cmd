setenv dtb_name "dtb.img"
setenv kernel_name "uImage"
setenv kernel_mem_addr "0x1080000"
setenv init_hdmi "logo=osd1,loaded,${fb_addr},${hdmimode} vout=${hdmimode},enable";
setenv condev "console=ttyAML0,115200 console=tty0 consoleblank=0";
setenv rootdev "noinitrd root=/dev/mmcblk1p2 rootfstype=ext4 rootdelay=1 rootflags=data=writeback rw"
setenv netdev "net.ifnames=0 mac=${mac}"
setenv bootargs "${rootdev} ${init_hdmi} ${condev} ${netdev}";
setenv boot_start bootm $kernel_mem_addr - $dtb_mem_addr;
fatload mmc 0:1 $dtb_mem_addr $dtb_name
fatload mmc 0:1 $kernel_mem_addr ${kernel_name}
run boot_start
