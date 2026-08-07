# 交叉编译
```
make \
ARCH=arm64 \
CROSS_COMPILE=aarch64-linux-gnu- \
KDIR=/path/to/kernel
```

# 目标板上安装
```
mkdir -p  /lib/modules/$(uname -r)/extra/
cp mcu_i2c_wdt.ko /lib/modules/$(uname -r)/extra/
depmod -a
modprobe mcu_i2c_wdt
```