# 开发板环境变量配置

**BOARD_NAME** 开发名称，仅用于显示

**PACK_NAME** 打包内核时的文件名

**CPU_INFO** 处理器

**VENDOR** 厂商

**BOARD_CODE** 开发板代号，用于匹配设备树和附加CONFIG文件

**ARCH_DEFCONFIG** 指定编译内核使用的DEFCONFIG文件，用于内核源码中已有配置文件

**BOARD_DEFCONFIG** 指定编译内核使用的DEFCONFIG文件，用于自定义的配置文件，优先级最高

**KERNEL_FMT** 内核文件格式，可选default,gzip,uboot

**KERNEL_TYPE** 适配内核类型，通常有mainline和vendor

**KERNEL_NAME** 内核源码来源名称

**KERNEL_COMPATIBLE** 当前配置兼容的内核源码

**KERNEL_COMPATIBLE_BRANCH** 当前配置兼容的内核源码分支

**NO_CROSS_COMPILE** 不使用交叉编译工具，在同平台编译时使用
