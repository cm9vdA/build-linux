fatload mmc 1:1 0x42000000 zImage
fatload mmc 1:1 0x43000000 dtb.img

setenv bootargs console=ttyS0,115200 earlyprintk root=/dev/mmcblk1p2 rootwait panic=10

bootz 0x42000000 - 0x43000000
