usb start

setenv dtb_name "dtb.img"
setenv dtb_mem_addr "0x1000000"
setenv kernel_name "uImage"
setenv kernel_mem_addr "0x1080000"
setenv init_hdmi "logo=osd1,loaded,${fb_addr},${hdmimode} vout=${hdmimode},enable";
setenv condev "console=ttyAML0,115200 console=tty0 consoleblank=0";
setenv fs_arg_mmc "noinitrd root=/dev/mmcblk1p2 rootfstype=ext4 rootdelay=1 rootflags=data=writeback rw"
setenv fs_arg_usb "noinitrd root=/dev/sda2 rootfstype=ext4 rootdelay=5 rootflags=data=writeback rw"
setenv net_arg "net.ifnames=0 mac=${mac}"
setenv bootargs "${fs_arg_usb} ${init_hdmi} ${condev} ${net_arg}";
setenv boot_start bootm $kernel_mem_addr - $dtb_mem_addr;

if fatload usb 0 $kernel_mem_addr $kernel_name; then if fatload usb 0 $dtb_mem_addr $dtb_name; then run boot_start; else store dtb read $dtb_mem_addr; run boot_start;fi;fi;
if fatload usb 1 $kernel_mem_addr $kernel_name; then if fatload usb 1 $dtb_mem_addr $dtb_name; then run boot_start; else store dtb read $dtb_mem_addr; run boot_start;fi;fi;
if fatload usb 2 $kernel_mem_addr $kernel_name; then if fatload usb 2 $dtb_mem_addr $dtb_name; then run boot_start; else store dtb read $dtb_mem_addr; run boot_start;fi;fi;
if fatload usb 3 $kernel_mem_addr $kernel_name; then if fatload usb 3 $dtb_mem_addr $dtb_name; then run boot_start; else store dtb read $dtb_mem_addr; run boot_start;fi;fi;
if fatload mmc 0 $kernel_mem_addr $kernel_name; then setenv bootargs "${fs_arg_mmc} ${init_hdmi} ${condev} ${net_arg}"; if fatload mmc 0 $dtb_mem_addr $dtb_name; then run boot_start; else store dtb read $dtb_mem_addr; run boot_start;fi;fi;
