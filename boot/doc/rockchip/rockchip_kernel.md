> https://opensource.rock-chips.com/wiki_Rockchip_Kernel


# Download Kernel
You can clone the rockchip kernel repository from github which is kernel 4.4 based:
```
git clone https://github.com/rockchip-linux/kernel.git
```

# Supported SoCs and Devices
Rockchip kernel 4.4 supports:

RK3036, RK3066, RK312X, RK3188, RK322X,RK3288, RK3328, RK3368, RK3399, PX30


# Configure and Build
You will need to use rockchip_linux_defconfig for Linux OS

For ARM v7
```
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- rockchip_linux_defconfig
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- -j4
```

For ARM V8
```
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- rockchip_linux_defconfig
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j4
```

Then you can get Image/zImage and dtb file and used for LInux Distro boot.

**Rockchip RKIMG format image**

RKIMG is a format customized by Rockchip from Android boot image, usually only used by kernel developers. It's support by Rockchip  U-Boot.

For example, build for rk3399-evb with command:
```
make rk3399-evb.img
```

The output will be as below, boot.img is ramdisk with rockchip header, kernel is zImage/Image with rockchip header, resource is dtb and boot logo with rockchip header.
```
kernel/
├── boot.img
├── kernel.img
└── resource.img
```

# Install Boot/kernel for Distro
We use distro boot in U-Boot, so we need to make a boot partition for U-Boot with kernel image and dtb inside.
```
mkdir boot
cp arch/arm64/boot/dts/rockchip/rk3399-evb.dtb boot/rk3399.dtb
cp arch/arm64/boot/Image boot/
```

Add extlinux/extlinux.conf for distro boot.
```
mkdir boot/extlinux
vi boot/extlinux/extlinux.conf
```
```
label rockchip-kernel-4.4
    kernel /Image
    fdt /rk3399.dtb
    append earlycon=uart8250,mmio32,0xff1a0000 root=PARTUUID=B921B045-1D rootwait rootfstype=ext4 init=/sbin/init
```

For armv7
```
label rockchip-kernel-4.4
    kernel /zImage
    fdt /rk3288.dtb
    append earlyprintk console=ttyS2,1500000n8 rw root=PARTUUID=69dad710-2c rootwait rootfstype=ext4 init=/sbin/init
```

You need to change the base address of debug UART, root partition for your board.

Pls reference to rockchip Linux parttion definition for rootfs partition and where boot to flash.

After all these files prepare completely, we write the file to the boot partition

Folder tree for armv8(rk3399, rk3328):
```
boot
├── extlinux
│   └── extlinux.conf
├── Image
└── rk3399-evb.dtb
```

Folder tree for armv7(rk3288), rootfs is optional, and we usually use compressed 'zImage':
```
boot_rk3288/
├── extlinux
│   └── extlinux.conf
├── rk3288-evb-rk808.dtb
├── rootfs.cpio.gz
└── zImage
```

Generate ext2fs boot partition
by genext2fs:
```
genext2fs -b 32768 -B $((32*1024*1024/32768)) -d boot/ -i 8192 -U boot_rk3399.img
```

According to Rockchip partition definition, you need to flash this image to boot partiton which offset is 0x8000.


# Generate fatfs boot partition
**Generate boot.img in fatfs**
Below commands can generate a fatfs boot.img
```
dd if=/dev/zero of=boot.img bs=1M count=32
sudo mkfs.fat boot.img
mkdir tmp
sudo mount boot.img tmp/
cp -r boot/* tmp/
umount tmp
```
Done!

Flash this boot.img to boot partition, which is offset 0x8000 in Rockchip partition definition.

**Update boot.img via U-Boot in target**
After flash and boot the U-Boot, write the gpt table from default partition table
```
gpt write mmc 0 $partitions
gpt verify mmc 0 $partitions
```
connect target to PC and start the ums in command line:

ums 0 mmc 1:6
We should able to see a device connect to PC, formate and copy data into the partition(dev/sdb6 for example).

sudo mkfs.fat /dev/sdb6
cp -r boot/* /media/machine/9F35-9565/
Done!


# Boot from U-Boot
If you are using genext2fs to genarate the boot.img, you need write the gpt table in U-Boot command line:
```
gpt write mmc 0 $partitions
```

Then boot from eMMC or reset:
```
boot
```

If everything is OK, you should able to see the U-Boot log like this:
```
switch to partitions #0, OK
mmc0(part 0) is current device
Scanning mmc 0:6...
Found /extlinux/extlinux.conf
Retrieving file: /extlinux/extlinux.conf
205 bytes read in 82 ms (2 KiB/s)
1:      upstream-4.10
Retrieving file: /Image
13484040 bytes read in 1833 ms (7 MiB/s)
append: earlycon=uart8250,mmio32,0xff1a0000 console=ttyS2,1500000n8 rw root=PARTUUID=B921B045-1D rootwait rootfstype=ext4 init=/sbin/init
Retrieving file: /rk3399.dtb
61714 bytes read in 54 ms (1.1 MiB/s)
## Flattened Device Tree blob at 01f00000
   Booting using the fdt blob at 0x1f00000
   Loading Device Tree to 000000007df14000, end 000000007df26111 ... OK

Starting kernel ...
```
