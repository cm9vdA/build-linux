fatload mmc 0:1 0x42000000 zImage
fatload mmc 0:1 0x43000000 sun7i-a20-m2.dtb

setenv bootargs console=ttyS0,115200 earlyprintk root=/dev/mmcblk0p2 rootwait panic=10

bootz 0x42000000 - 0x43000000
