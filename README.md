English| [简体中文](./README_cn.md)

# Development Environment Setup and Compilation Instructions

## Overview

Introduce the requirements and setup of cross-compilation development environment, as well as compilation instructions for system image.

## Development Environment

Cross-compilation refers to developing and building software on the host machine, then deploying the built software to run on the development board. The host machine generally has higher performance and memory than the development board, which can speed up code building and allow for more development tools installation, making it convenient for development.

**Host Compilation Environment Requirements**

It is recommended to use the Ubuntu operating system. If using other system versions, adjustments may be needed for the compilation environment.

For Ubuntu 18.04 system, install the following packages:

```shell
sudo apt-get install -y build-essential make cmake libpcre3 libpcre3-dev bc bison \
flex python-numpy mtd-utils zlib1g-dev debootstrap \
libdata-hexdumper-perl libncurses5-dev zip qemu-user-static \
curl git liblz4-tool apt-cacher-ng libssl-dev checkpolicy autoconf \
android-tools-fsutils mtools parted dosfstools udev rsync
```

For Ubuntu 20.04 system, install the following packages:

```shell
sudo apt-get install -y build-essential make cmake libpcre3 libpcre3-dev bc bison \
flex python-numpy mtd-utils zlib1g-dev debootstrap \
libdata-hexdumper-perl libncurses5-dev zip qemu-user-static \
curl git liblz4-tool apt-cacher-ng libssl-dev checkpolicy autoconf \
android-sdk-libsparse-utils android-sdk-ext4-utils mtools parted dosfstools udev rsync
```

For Ubuntu 22.04 system, install the following packages:

```shell
sudo apt-get install -y build-essential make cmake libpcre3 libpcre3-dev bc bison \
flex python3-numpy mtd-utils zlib1g-dev debootstrap \
libdata-hexdumper-perl libncurses5-dev zip qemu-user-static \
curl repo git liblz4-tool apt-cacher-ng libssl-dev checkpolicy autoconf \
android-sdk-libsparse-utils mtools parted dosfstools udev rsync
```

**Installing Cross-Compilation Toolchain**

Execute the following command to download the cross-compilation toolchain:

```shell
curl -fO http://sunrise.horizon.cc/toolchain/gcc-ubuntu-9.3.0-2020.03-x86_64-aarch64-linux-gnu.tar.xz
``````

Unzip and install, it is recommended to install under the /opt directory. Usually, writing data to the /opt directory requires sudo permission, for example:

```shell
sudo tar -xvf gcc-ubuntu-9.3.0-2020.03-x86_64-aarch64-linux-gnu.tar.xz -C /opt
```

Configure the environment variables for the cross-compilation toolchain:

```shell
export CROSS_COMPILE=/opt/gcc-ubuntu-9.3.0-2020.03-x86_64-aarch64-linux-gnu/bin/aarch64-linux-gnu-
export LD_LIBRARY_PATH=/opt/gcc-ubuntu-9.3.0-2020.03-x86_64-aarch64-linux-gnu/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH
export PATH=$PATH:/opt/gcc-ubuntu-9.3.0-2020.03-x86_64-aarch64-linux-gnu/bin/
export ARCH=arm64
```

The above commands are for temporary environment variable configuration. To make the configuration permanent, you can add the above commands to the end of the environment variable file `~/.profile` or `~/.bash_profile`.

## rdk-gen

rdk-gen is used to build custom operating system images for Horizon RDK X3. It provides an extensible framework that allows users to customize and build the Ubuntu operating system for RDK X3 according to their needs.

Download the source code:

```shell
git clone https://github.com/HorizonRDK/rdk-gen.git
```

After downloading, the directory structure of rdk-gen is as follows:

| **Directory**             | **Description**                                              |
| -------------------------  | ------------------------------------------------------------ |
| pack_image.sh              | Code entry for building system images                        |
| download_samplefs.sh       | Download pre-made base Ubuntu file system                   |
| download_deb_pkgs.sh       | Download Horizon's deb packages to be pre-installed in the system image, including kernel, multimedia libraries, sample code, tros.bot, etc. |
| hobot_customize_rootfs.sh  | Customization of Ubuntu file system                          |
| source_sync.sh             | Download source code, including bootloader, uboot, kernel, sample code, etc. |
| mk_kernel.sh               | Compile kernel, device tree, and driver modules              |
| mk_debs.sh                 | Generate deb packages                                       |
| make_ubuntu_samplefs.sh    | Code for creating Ubuntu system filesystem, can modify this script to customize samplefs  |
| config                     | Contains content that needs to be placed under /hobot/config in the system image, a vfat root partition. For SD card boot method, users can directly modify the content of this partition in the Windows system. |

## Compile System Image

Run the following command to package the system image:

```shell
cd rdk-gen
sudo ./pack_image.sh
``````

You need sudo privileges to compile, and after successful compilation, a system image file `*.img` will be generated in the deploy directory.

### Introduction to `pack_image.sh` Compilation Process

1. Call two scripts `download_samplefs.sh` and `download_deb_pkgs.sh` to download samplefs and the required deb software packages from Horizon's file server.
2. Unpack samplefs and call `hobot_customize_rootfs.sh` script to customize the filesystem configuration.
3. Install deb packages into the filesystem.
4. Generate the system image.

## Downloading Source Code

The source code for RDK-Linux related kernel, bootloader, and hobot-xxx software packages are hosted on [GitHub](https://github.com/). Before downloading the code, please register and log in to [GitHub](https://github.com/), and add the development server's `SSH Key` to the user settings through [Generating a new SSH key and adding it to the ssh-agent](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent) method.

`source_sync.sh` is used to download the source code, including bootloader, U-Boot, kernel, sample codes, etc. This download tool downloads all source code locally by executing `git clone git@github.com:xxx.git`.

Execute the following command to download the code from the main branch:

```shell
./source_sync.sh -t main
```

By default, the program will download the source code to the source directory:

```
source
├── bootloader
├── hobot-boot
├── hobot-bpu-drivers
├── hobot-camera
├── hobot-configs
├── hobot-display
├── hobot-dnn
├── hobot-dtb
├── hobot-io
├── hobot-io-samples
├── hobot-kernel-headers
├── hobot-multimedia
├── hobot-multimedia-dev
├── hobot-spdev
├── hobot-sp-samples
├── hobot-utils
├── hobot-wifi
└── kernel
```

## Kernel

Execute the following command to compile the Linux kernel:
```shell
./mk_kernel.sh
```

After compilation, the kernel image, driver modules, device tree, and kernel headers will be generated in the `deploy/kernel` directory.

```shell
dtb  Image  Image.lz4  kernel_headers  modules
```

These contents will be used by three Debian packages: hobot-boot, hobot-dtb, and hobot-kernel-headers. Therefore, if you want to customize or modify these three packages, you need to compile the kernel first.

## hobot-xxx Software Package

The hobot-xxx software package contains the source code and configuration of the Debian packages maintained by Horizon. After downloading the source code, you can execute `mk_deb.sh` to rebuild the Debian package.

Help information is as follows:

```shell
$ ./mk_debs.sh help
The debian package named by help is not supported, please check the input parameters.
./mk_deb.sh [all] | [deb_name]
    hobot-multimedia-dev, Version 2.0.0
    hobot-wifi, Version 2.0.0
    hobot-camera, Version 2.0.0
    hobot-dtb, Version 2.0.0
    hobot-configs, Version 2.0.0
    hobot-io, Version 2.0.0
    hobot-spdev, Version 2.0.0
    hobot-boot, Version 2.0.0
    hobot-sp-samples, Version 2.0.0
    hobot-bpu-drivers, Version 2.0.0
    hobot-multimedia-samples, Version 2.0.0
    hobot-dnn, Version 2.0.0
    hobot-io-samples, Version 2.0.0
    hobot-kernel-headers, Version 2.0.0
    hobot-utils, Version 2.0.0
    hobot-multimedia, Version 2.0.0
    hobot-display, Version 2.0.0
```

### Overall Build

Executing the following command will rebuild all Debian packages (kernel compilation needs to be completed first):

```shell
./mk_deb.sh
```
Upon completion of the build, deb software packages will be generated in the `deploy/deb_pkgs` directory.

### Build Individual Software Package

`mk_deb.sh` supports building specified software packages individually. Simply provide the package name parameter when executing, for example:

```shell
./mk_deb.sh hobot-configs
```

## bootloader

The source code for `bootloader` is used to generate the minimal boot image `miniboot.img`, which includes partition table, spl, ddr, bl31, and uboot as a unified boot firmware.

The minimal boot image for RDK X3 is usually maintained and released by Horizon official. You can download the corresponding version from [miniboot](http://sunrise.horizon.cc/downloads/miniboot/).

Recompile and generate miniboot with the following steps.

### Sync U-Boot code

Execute the command to download U-Boot code:

```shell
git submodule init
git submodule update
```

### Choose Hardware Configuration File

```shell
cd build
./xbuild.sh lunch

You're building on #221-Ubuntu SMP Tue Apr 18 08:32:52 UTC 2023
Lunch menu... pick a combo:
      0. horizon/x3/board_ubuntu_emmc_sdcard_config.mk
      1. horizon/x3/board_ubuntu_emmc_sdcard_samsung_4GB_config.mk
      2. horizon/x3/board_ubuntu_nand_sdcard_config.mk
      3. horizon/x3/board_ubuntu_nand_sdcard_samsung_4GB_config.mk
Which would you like? [0] :  
```

Select the board-level configuration file as prompted.

The predefined configuration files are adapted to different hardware configurations of development boards, distinguished by the use of emmc or nand for burning miniboot, ddr model and capacity, and different root file systems:

| Board Configuration File                          | Memory             | Rootfs       | Miniboot Storage    | Main Storage |
| -------------------------------------------------| ------------------ | ------------ | ------------------- | ------------ |
| board_ubuntu_emmc_sdcard_config.mk               | LPDDR4 2GB         | ubuntu-20.04  | emmc                | sdcard       |
| board_ubuntu_emmc_sdcard_samsung_4GB_config.mk   | LPDDR4 4GB         | ubuntu-20.04  | emmc                | sdcard       |
| board_ubuntu_nand_sdcard_config.mk             | LPDDR4 2GB | ubuntu-20.04 | nand               | sdcard/emmc |
| board_ubuntu_nand_sdcard_samsung_4GB_config.mk | LPDDR4 4GB | ubuntu-20.04 | nand               | sdcard/emmc |

**Minimum Boot Image Storage:** Burn the storage of miniboot. Users of RDK X3 and RDK X3 Module all choose the nand flash method.

**Main Memory:** The storage of the Ubuntu system image, sdcard and eMMC are mutually compatible, meaning the image burned to a Micro SD card can also be burned to eMMC.

The lunch command also supports directly completing the configuration by specifying a number and the board configuration file name.

```shell
$ ./xbuild.sh lunch 2

You're building on #221-Ubuntu SMP Tue Apr 18 08:32:52 UTC 2023
You are selected board config: horizon/x3/board_ubuntu_nand_sdcard_config.mk

$ ./xbuild.sh lunch board_ubuntu_nand_sdcard_config.mk

You're building on #221-Ubuntu SMP Tue Apr 18 08:32:52 UTC 2023
You are selected board config: horizon/x3/board_ubuntu_nand_sdcard_config.mk
```

### Overall Compilation

Go to the build directory and execute xbuild.sh for overall compilation:

```shell
cd build
./xbuild.sh
```

After successful compilation, miniboot.img, uboot.img, disk_nand_minimum_boot.img and other image files will be generated in the image output directory (deploy_ubuntu_xxx). disk_nand_minimum_boot.img is the minimum boot image file.

### Modular Compilation

Compile individual modules using the xbuild.sh script, and the generated image files will be output to the image output directory (deploy_ubuntu_xxx).

```shell
./xbuild.sh miniboot | uboot
```

**miniboot:** Call mk_miniboot.sh to generate miniboot.img.

**uboot:** Call mk_uboot.sh to generate uboot.img.

After modular compilation, the pack command can be executed to pack disk_nand_minimum_boot.img.

```shell
./xbuild.sh pack
```
## Creating Ubuntu File System

This chapter introduces how to create the `samplefs_desktop-v2.0.0.tar.gz` file system. Horizon will maintain this file system, and if there are customization requirements, it needs to be re-created according to the instructions in this chapter.

### Environment Setup

It is recommended to use an Ubuntu host to create the file system for the Ubuntu development board. First, install the following packages in the host environment:

```shell
sudo apt-get install wget ca-certificates device-tree-compiler pv bc lzop zip binfmt-support \
build-essential ccache debootstrap ntpdate gawk gcc-arm-linux-gnueabihf qemu-user-static \
u-boot-tools uuid-dev zlib1g-dev unzip libusb-1.0-0-dev fakeroot parted pkg-config \
libncurses5-dev whiptail debian-keyring debian-archive-keyring f2fs-tools libfile-fcntllock-perl \
rsync libssl-dev nfs-kernel-server btrfs-progs ncurses-term p7zip-full kmod dosfstools \
libc6-dev-armhf-cross imagemagick curl patchutils liblz4-tool libpython2.7-dev linux-base swig acl \
python3-dev python3-distutils libfdt-dev locales ncurses-base pixz dialog systemd-container udev \
lib32stdc++6 libc6-i386 lib32ncurses5 lib32tinfo5 bison libbison-dev flex libfl-dev cryptsetup gpg \
gnupg1 gpgv1 gpgv2 cpio aria2 pigz dirmngr python3-distutils distcc git dos2unix apt-cacher-ng
```

### Key Tools Introduction

#### debootstrap

debootstrap is a tool in Debian/Ubuntu used to build a basic system (root file system). The generated directory complies with the Linux Filesystem Hierarchy Standard (FHS), containing directories like /boot, /etc, /bin, /usr, etc. It is smaller in size compared to the Linux distribution version, with less functionality, hence it can be considered as a "basic system" that can be customized according to specific needs for the Ubuntu system.

Installing debootstrap in Ubuntu system (PC):

```shell
sudo apt-get install debootstrap
```

Usage:

```shell
# Additional parameters can be added to specify the source
sudo debootstrap --arch [platform] [release code name] [directory] [source]
```

#### chroot

chroot stands for change root directory. In Linux systems, the default directory structure starts with `/`, which is the root. After using chroot, the system's directory structure will start from the specified location as the new root directory `/`.

#### parted

parted is a powerful disk partition tool developed by the GNU organization that supports adjusting partition sizes. Unlike fdisk, it can handle common partition formats including ext2, ext3, fat16, fat32, NTFS, ReiserFS, JFS, XFS, UFS, HFS, and Linux swap partitions.

### Script Code for Creating Ubuntu Rootfs
Download the `rdk-gen` source code:

```shell
git clone https://github.com/HorizonRDK/rdk-gen.git
```

Execute the following command to generate the Ubuntu file system:

```shell
mkdir ubuntu_rootfs
cd ubuntu_rootfs
cp ../make_ubuntu_rootfs.sh .
chmod +x make_ubuntu_rootfs.sh
sudo ./make_ubuntu_rootfs.sh
```

Output of successful compilation:

```shell
desktop/                                   # Output directory after compilation
├── focal-xj3-arm64                        # Root file system generated after successful compilation, containing various system temporary files
├── samplefs_desktop-v2.0.0.tar.gz         # Compressed pack of contents needed inside focal-xj3-arm64
└── samplefs_desktop-v2.0.0.tar.gz.info    # Information on which apt packages are installed in the current system

rootfs/                                    # After extracting samplefs_desktop-v2.0.0.tar.gz, it should contain the following files
├── app
├── bin -> usr/bin
├── boot
├── dev
├── etc
├── home
├── lib -> usr/lib
├── media
├── mnt
├── opt
├── proc
├── root
├── run
├── sbin -> usr/sbin
├── srv
├── sys
├── tmp
├── userdata
├── usr
└── var

21 directories, 5 files
```
### Customization

Key variable definitions in the code:

**PYTHON_PACKAGE_LIST**: Python packages to install

**DEBOOTSTRAP_LIST**: Debian packages to install when executing debootstrap

**BASE_PACKAGE_LIST**: Debian packages needed for the most basic Ubuntu system installation

**SERVER_PACKAGE_LIST**: Additional Debian packages installed on top of the basic version for the Ubuntu Server edition

**DESKTOP_PACKAGE_LIST**: Software packages required for supporting desktop graphical interfaces

The `samplefs_desktop` file system maintained by Horizon will contain content corresponding to all of the above configuration packages, and users can add or remove packages according to their needs.
