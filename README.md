# Build-Linux
> 用于快速构建内核和根文件系统

## 目录说明：
env：编译构建时所需要的环境变量

boot：Linux启动相关的文件，包含内核编译配置、设备树、启动脚本以及从原机系统中提取的启动相关文件。

u-boot：u-boot编译构建相关的配置以及生成的bin文件

## 用法:
在工作目录下创建与build_xxxx同名的软链接即可

## 举例：
- 假如要为M2板子编译内核，需进行以下步骤： 
  1. 解压下载好的内核源码
  2. 修改[build_linux_m2](https://github.com/HIWLYF/build-linux/blob/master/env/build_linux_m2)中的PATH参数，根据实际情况设置交叉编译工具路径
  3. 在内核源码目录下创建软链接到[mk_kernel.sh](https://github.com/HIWLYF/build-linux/blob/master/mk_kernel.sh)，软链接的名字是build_linux_m2， 因为mk_kernel.sh脚本是根据调用时的文件名来自动选择对应的环境变量文件，所以要以环境变量文件的名字来命名
  4. 【可选步骤】拷贝[sun7i-a20-m2.dts](https://github.com/HIWLYF/build-linux/blob/master/boot/dts/m2/linux-5.9.2/sun7i-a20-m2.dts) 到linux源码目录下对应位置并修改Makefile
  5. 拷贝[config](https://github.com/HIWLYF/build-linux/blob/master/boot/config/m2/config_5.9.2)文件到linux源码目录下的 .build 目录下边，并重命名为.config，如果该目录不存在可手动创建
  6. 运行./build_linux_m2，使用选项3开始编译
