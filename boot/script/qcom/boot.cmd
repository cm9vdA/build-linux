setenv dtb_path "/boot/sm8250-hdk.dtb"
setenv kernel_path "/boot/Image"
setenv initrd_path "/boot/uInitrd"

setenv dtb_addr    0x9a000000
setenv kernel_addr 0x9f000000
setenv initrd_addr 0xa5000000

setenv bootargs "root=/dev/sda1 rootfstype=ext4 rootdelay=1 rootflags=data=writeback rw"
setenv boot_start booti $kernel_addr $initrd_addr $dtb_addr

ext4load scsi 0:1 $dtb_addr $dtb_path
ext4load scsi 0:1 $kernel_addr $kernel_path
ext4load scsi 0:1 $initrd_addr $initrd_path

run boot_start

# mkimage -A arm -O linux -T script -C none -a 0 -e 0 -n 'Boot Script' -d boot.cmd boot.scr