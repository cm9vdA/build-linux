> https://www.linaro.org/blog/initial-u-boot-release-for-qualcomm-platforms/
> https://github.com/u-boot/u-boot/blob/master/doc/board/qualcomm/board.rst


# 拉取源码
```
git clone https://git.codelinaro.org/linaro/qcomlt/u-boot
```


# 编译
```
make CROSS_COMPILE=aarch64-linux-gnu- O=.output qcom_defconfig
make CROSS_COMPILE=aarch64-linux-gnu- O=.output -j$(nproc) DEVICE_TREE=qcom/sm8250-hdk
```

# 方法1: XBL
```
git clone https://github.com/msm8916-mainline/qtestsign
ln -s $PWD/qtestsign.py ~/.local/bin/qtestsign
ln -s $PWD/qtestsign.py ~/.local/bin/patchxbl
```
刷入
```
patchxbl -o .output/u-boot-xbl.elf -c .output/u-boot-dtb.bin ~/Documents/work/rb2-bootloader-emmc-linux-47528/xbl.elf
# qtestsign -v6 xbl -o .output/u-boot-xbl.mbn .output/u-boot-xbl.elf
qtestsign -v6 sbl1 -o .output/u-boot-xbl.mbn .output/u-boot-xbl.elf
fastboot flash xbl .output/u-boot-xbl.mbn
```


# 方法2: boot.img
````
gzip .output/u-boot-nodtb.bin -c > .output/u-boot-nodtb.bin.gz
cat .output/u-boot-nodtb.bin.gz .output/dts/upstream/src/arm64/qcom/sm8250-hdk.dtb > /tmp/uboot-dtb
mkbootimg --kernel_offset '0x00008000' --pagesize '4096' --kernel /tmp/uboot-dtb -o .output/u-boot.img
```
刷入
```
fastboot flash boot u-boot.img
fastboot erase dtbo
```


# 方法3: EFI
```
make CROSS_COMPILE=aarch64-linux-gnu- O=.output qcm6490_defconfig
make CROSS_COMPILE=aarch64-linux-gnu- O=.output -j$(nproc)

qtestsign -v6 hyp -o .output/u-boot.mbn .output/u-boot.elf
fastboot flash uefi_a .output/u-boot.mbn
```


# 方法4: HYP
```
make CROSS_COMPILE=aarch64-linux-gnu- O=.output qcom_defconfig hyp-sm8250.config
make CROSS_COMPILE=aarch64-linux-gnu- O=.output -j$(nproc) DEVICE_TREE=qcom/qrb5165-rb5

qtestsign -v6 hyp -o .output/u-boot-hyp.mbn .output/u-boot.elf
fastboot flash hyp .output/u-boot-hyp.mbn
```

# qtestsign后记
`db410c` -> v3
`rb3` -> v5
`rb5` -> v6