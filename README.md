# Build-Linux
> 用于构建嵌入式板子的内核、U-Boot和根文件系统

> 交叉编译工具链下载地址 https://developer.arm.com/downloads/-/arm-gnu-toolchain-downloads

## 目录说明：
- board：一些板子的参数信息以及图片存档
- boot：系统启动所需要的文件，包含内核编译配置（configs）、设备树（dts）、内核引导脚本（script）以及从原机系统中提取的启动相关文件（bsp）
- env：编译构建时所需要的环境变量
- u-boot：u-boot编译构建相关的配置以及生成的bin文件
- resource：一些相关的资源文件

## 文件说明:
- `mk_kernel.sh` 文件是用于编译Linux内核的脚本
- `mk_rootfs.sh` 文件是用于构建Debian根文件系统的脚本
- `mk_uboot.sh` 文件是用于构建U-Boot的脚本

## 使用步骤:
- 内核编译：
  - 以M2板子为例
    1. 在当前用户的家目录下，建立`arm`目录，并clone本仓库到`arm`目录下。【可以是其他目录，只要在第3步中配置好交叉编译的工具链即可】
    2. 解压要编译的Linux内核源码到`arm`目录下。【通常我使用的都是主线内核，地址：<https://www.kernel.org/>】
    3. 修改`build-linux/env/common/build_kernel_arm`中的PATH参数，根据实际情况填写交叉编译工具路径和工具链名，如果是64位的板子，需要改`build_kernel_aarch64`。
    4. 在`arm`目录下创建M2的工作目录，比如`workspace`。
    5. 进入`workspace`目录，创建软链接到`build-linux/mk_kernel.sh`，软链接的名字是`build_kernel_m2`（也就是与env目录下的环境变量文件同名），因为`mk_kernel.sh`脚本是根据调用时的文件名来选择对应的环境变量文件，所以要以环境变量文件的名字来命名。
    6. 运行`./build_kernel_m2`，根据菜单提示项进行编译和打包。

  - 菜单说明
    ```
    ================ Build Info ================                # 第一部分是要编译的目标板的配置信息，一般都是在`env`下定义的。
    BOARD_NAME:       Merrii M2
    CPU_INFO:         Allwinner A20
    DT_FILE:          sun7i-a20-m2
    ARCH:             arm
    KERNEL_VERSION:   5.17.3
    DEFCONFIG:        sun7i_defconfig
    BUILD_ARGS:       -j4 O=/home/code/arm/workspace_m2/.build
    CROSS_COMPILE:    arm-none-linux-gnueabihf-
    INSTALL_MOD_PATH: /home/code/arm/workspace_m2/install
    ================ Menu Option ================
            [1]. Use Default Config                             # 使用defconfig文件生成编译配置，可以通过DEFCONFIG来指定，如未指定则使用默认的
            [2]. Menu Config                                    # 在菜单中修改编译配置
            [3]. Build All                                      # 构建内核、模块和dtb
            [31] ├─Build Kernel                                 # 仅编译内核
            [32] ├─Build Modules                                # 仅编译内核模块
            [33] └─Build DTB                                    # 仅编译dtb
            [4]. Install All
            [41] ├─Install Kernel And Modules                   # 安装内核和模块文件到INSTALL_MOD_PATH指定的位置
            [42] └─Install Headers                              # 安装内核头文件到INSTALL_HDR_PATH指定的位置
            [5]. Archive Kernel                                 # 将INSTALL_MOD_PATH位置的内核文件打包
            [6]. Clean                                          # 清理编译生成的文件
    Please Select: >>
    ```

- U-Boot编译
  使用方法和编译内核类似

  - 菜单说明
    ```
    ================ Build Info ================                # 第一部分是要编译的目标板的配置信息，一般都是在`env`下定义的。
    BOARD_NAME:       LX-R3S
    CPU_INFO:         Rockchip RK3399
    ARCH:             arm
    UBOOT_VERSION:    2022.01
    DEFCONFIG:        lx-r3s-rk3399_defconfig
    ATF_PLAT:         rk3399
    ATF(BL31) /home/code/arm/workspace_r3s/arm-trusted-firmware/build/rk3399/release/bl31/bl31.elf
    BUILD_ARGS:       -j4 O=/home/code/arm/workspace_r3s/.build_uboot
    CROSS_COMPILE:    aarch64-none-elf-
    ================ Menu Option ================
            [0]. Build ATF(arm64 only)                          # 对于64位的板子需要编译这个arm trust firmware。【Amlogic不需要】
            [1]. Use Default Config                             # 使用defconfig文件生成编译配置，通过DEFCONFIG来指定
            [2]. Menu Config                                    # 在菜单中修改编译配置
            [3]. Build U-boot                                   # 构建
            [4]. Process                                        # 某些平台的U-Boot编译完以后不能直接用，暂未实现。【例如：Amlogic需要签名以后才可以运行】
            [5]. Clean                                          # 清理编译生成的文件
    Please Select: >>
    ```

- 根文件系统制作
  待续。。。
