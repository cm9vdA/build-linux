setenv dtb_path "/boot/dtb/qcom/sm8250-hdk.dtb"
setenv kernel_path "/boot/Image"

setenv dtb_addr    0x9a000000
setenv kernel_addr 0x9f000000

setenv bootargs "noinitrd root=/dev/sda15 rootfstype=ext4 rootdelay=1 rootflags=data=writeback rw"
setenv boot_start booti $kernel_addr - $dtb_addr

ext4load scsi 0:f $dtb_addr $dtb_path
ext4load scsi 0:f $kernel_addr $kernel_path

run boot_start