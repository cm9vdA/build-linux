# Build-Linux
> 用于快速构建内核和根文件系统

## 目录说明：
- env：编译构建时所需要的环境变量
- boot：Linux启动相关的文件，包含内核编译配置、设备树、启动脚本以及从原机系统中提取的启动相关文件
- u-boot：u-boot编译构建相关的配置以及生成的bin文件
- resource：一些相关的资源文件

## 文件说明:
- `mk_kernel.sh` 文件是用于编译Linux内核的脚本
- `mk_rootfs.sh` 文件是用于构建Debian根文件系统

## 使用步骤:
- 内核编译：
以M2板子为例
1. 在当前用户的家目录下，建立`arm`目录，并clone本仓库到`arm`目录下。【可以是其他目录，后边好交叉编译工具链的路径就可以了】
2. 解压要编译的linux内核源码到`arm`目录下
3. 修改`build-linux\env\common\build_kernel_arm`中的PATH参数，根据实际情况填写交叉编译工具路径，如果是64位的板子，需要改`build_kernel_aarch64`
4. 在`arm`目录下创建M2的工作目录，比如`workspace`
5. 进入`workspace`目录，创建软链接到`build-linux\mk_kernel.sh`，软链接的名字是`build_kernel_m2`，因为`mk_kernel.sh`脚本是根据调用时的文件名来选择对应的环境变量文件，所以要以环境变量文件的名字来命名
6. 运行`./build_kernel_m2`，根据菜单提示项进行编译和打包

- 根文件系统制作
待续。。。
