#!/bin/bash
###
 # COPYRIGHT NOTICE
 # Copyright 2023 Horizon Robotics, Inc.
 # All rights reserved.
 # @Date: 2023-03-16 10:02:18
 # @LastEditTime: 2023-03-22 17:46:10
### 

set -ex

export HR_LOCAL_DIR=$(realpath $(cd $(dirname $0); pwd))
export HR_ROOTFS_PART_NAME="system"

this_user="$(whoami)"
if [ "${this_user}" != "root" ]; then
    echo "ERROR: This script requires root privilege"
    exit 1
fi

# 编译出来的镜像保存位置
export IMAGE_DEPLOY_DIR=${HR_LOCAL_DIR}/deploy
[ ! -z ${IMAGE_DEPLOY_DIR} ] && [ ! -d $IMAGE_DEPLOY_DIR ] && mkdir $IMAGE_DEPLOY_DIR

rm -f ${IMAGE_DEPLOY_DIR}/${HR_ROOTFS_PART_NAME}_sdcard.img

ROOTFS_ORIG_DIR=${HR_LOCAL_DIR}/rootfs
ROOTFS_BUILD_DIR=${IMAGE_DEPLOY_DIR}/rootfs
rm -rf ${ROOTFS_BUILD_DIR}
[ ! -d $ROOTFS_BUILD_DIR ] && mkdir ${ROOTFS_BUILD_DIR}

function get_partition_size()
{
    partition_size=$(du -sk ${ROOTFS_BUILD_DIR} | awk '{print $1}')
    partition_size=$((${partition_size} * 1024))
    if [ ! -z ${partition_size} ];then
        # 扩大两倍，因为制作的
        partition_size=$((${partition_size} * 2))
        partition_align_size=$(($partition_size - 512*1024))
    else
        echo "rootfs size error: ${partition_size}"
        exit -1
    fi
}

if [[ "$fs_type" = "none" ]] || [[ "$fs_type" = "" ]] ;then
    fs_type=${HR_ROOTFS_FS_TYPE}
fi

relpath() {
    source_path=$1
    full=$2
    if [ "${full}" == "${source_path}" ]; then
        echo ""
    else
        base=${source_path%%/}/
        echo "${full##$base}"
    fi
}

function install_deb_chroot()
{
    local package=$1
    local dst_dir=$2

    cd "${dst_dir}/app/hobot_debs"
    echo "###### Installing" "${package} ######"
    depends=$(dpkg-deb -f "${package}" Depends | sed 's/([^()]*)//g')
    if [ -f ${package} ];then
        chroot "${dst_dir}" /bin/bash -c "dpkg --ignore-depends=${depends// /} -i /app/hobot_debs/${package}"
    fi
    echo "###### Installed" "${package} ######"
}

function install_packages()
{
    local dst_dir=$1
    if [ ! -d ${dst_dir} ]; then
        echo "dst_dir is not exist!" "${dst_dir}"
        exit -1
    fi

    echo "Start install hobot packages"

    cd "${dst_dir}/app/hobot_debs"
    deb_list=$(ls)

    for deb_name in ${deb_list[@]}
    do
        install_deb_chroot "${deb_name}" "${dst_dir}"
    done

    chroot ${dst_dir} /bin/bash -c "apt clean"
    echo "Install hobot packages is finished"
}

# 制作 ubuntu 根文件系统镜像
function make_ubuntu_image()
{
    # ubuntu 系统直接解压制作image
    echo "tar -xzf ${ROOTFS_ORIG_DIR}/samplefs*.tar.gz -C ${ROOTFS_BUILD_DIR}"
    tar -xzf ${ROOTFS_ORIG_DIR}/samplefs*.tar.gz -C ${ROOTFS_BUILD_DIR}
    mkdir -p ${ROOTFS_BUILD_DIR}/{home,home/root,mnt,root,usr/lib,var,media,tftpboot,var/lib,var/volatile,dev,proc,tmp,run,sys,userdata,app,boot/hobot,boot/config}
    # echo "${HR_BSP_VERSION}" >${ROOTFS_BUILD_DIR}/etc/version

    # Custom Special Modifications
    echo "Custom Special Modifications"
    source hobot_customize_rootfs.sh
    hobot_customize_rootfs ${ROOTFS_BUILD_DIR}

    # install debs
    echo "Install hobot debs in /app/hobot_debs"
    mkdir -p ${ROOTFS_BUILD_DIR}/app/hobot_debs
    [ -d "${HR_LOCAL_DIR}/deb_packages" ] && find "${HR_LOCAL_DIR}/deb_packages" -maxdepth 1 -type f -name '*.deb' -exec cp -f {} "${ROOTFS_BUILD_DIR}/app/hobot_debs" \;
    [ -d "${HR_LOCAL_DIR}/third_packages" ] && find "${HR_LOCAL_DIR}/third_packages" -maxdepth 1 -type f -name '*.deb' -exec cp -f {} "${ROOTFS_BUILD_DIR}/app/hobot_debs" \;


    install_packages ${ROOTFS_BUILD_DIR}
    rm ${ROOTFS_BUILD_DIR}/app/hobot_debs/ -rf

    rm -rf ${ROOTFS_BUILD_DIR}/lib/aarch64-linux-gnu/dri/

    # 从实际的根文件系统大小里面直接计算得到根文件系统大小
    get_partition_size

    make_ext4fs -l ${partition_size} -L ${HR_ROOTFS_PART_NAME} ${IMAGE_DEPLOY_DIR}/${HR_ROOTFS_PART_NAME}.img ${ROOTFS_BUILD_DIR}
    # 压缩根文件系统镜像到最小尺寸
    resize2fs -M ${IMAGE_DEPLOY_DIR}/${HR_ROOTFS_PART_NAME}.img
    # 再最小尺寸上增加50MB空间，用于在系统第一次启动时存放各种服务的启动文件，方式服务启动失败
    image_size=`ls -l --block-size=M ${IMAGE_DEPLOY_DIR}/${HR_ROOTFS_PART_NAME}.img | awk '{print $5}'`
    resize2fs ${IMAGE_DEPLOY_DIR}/${HR_ROOTFS_PART_NAME}.img `expr ${image_size%?} + 50`M

    # sdcard启动方式，需要在生成的根文件系统前头加上分区表头用于烧录到sdcard上
    cd ${IMAGE_DEPLOY_DIR}
    # 添加分区信息
    IMG_FILE="${IMAGE_DEPLOY_DIR}/${HR_ROOTFS_PART_NAME}_sdcard.img"

    ROOT_SIZE=`ls -l --block-size=1 ${IMAGE_DEPLOY_DIR}/${HR_ROOTFS_PART_NAME}.img | awk '{print $5}'`

    # All partition sizes and starts will be aligned to this size
    ALIGN="$((4 * 1024 * 1024))"
    CONFIG_SIZE="$((256 * 1024 * 1024))"
    CONFIG_PART_START=$((ALIGN))
    CONFIG_PART_SIZE=$(((CONFIG_SIZE + ALIGN - 1) / ALIGN * ALIGN))
    ROOT_PART_START=$((CONFIG_PART_START + CONFIG_PART_SIZE))
    ROOT_PART_SIZE=$(((ROOT_SIZE + ALIGN  - 1) / ALIGN * ALIGN))
    IMG_SIZE=$((CONFIG_PART_START + CONFIG_PART_SIZE + ROOT_PART_SIZE))

    truncate -s "${IMG_SIZE}" "${IMG_FILE}"

    parted --script "${IMG_FILE}" mklabel msdos
    parted --script "${IMG_FILE}" unit B mkpart primary fat32 "${CONFIG_PART_START}" "$((CONFIG_PART_START + CONFIG_PART_SIZE - 1))"
    parted --script "${IMG_FILE}" unit B mkpart primary ${fs_type} "${ROOT_PART_START}" "$((ROOT_PART_START + ROOT_PART_SIZE - 1))"
    # 设置为启动分区
    parted "${IMG_FILE}" set 2 boot on

    # 创建配置分区的镜像
    CONFIG_PARTITION="${IMAGE_DEPLOY_DIR}/config_part.img"
    rm -f ${CONFIG_PARTITION}
    fallocate -l ${CONFIG_PART_SIZE} ${CONFIG_PARTITION}
    mkfs.fat -nCONFIG -F32 -S512 -s4 "${CONFIG_PARTITION}" >/dev/null

    CONFIG_PART_SOURCE="${HR_LOCAL_DIR}/config"
    mkdir -p ${CONFIG_PART_SOURCE}
    find "${CONFIG_PART_SOURCE}" -type d | while read dir; do
        target=$(relpath "${CONFIG_PART_SOURCE}" "$dir")
        [ -z "$target" ] && continue
        # echo "  Creating $target"
        mmd -i "${CONFIG_PARTITION}" "::$target"
    done
    find ${CONFIG_PART_SOURCE} -type f | while read file; do
        target=$(relpath "${CONFIG_PART_SOURCE}" "$file")
        # echo "  Copying $target"
        mcopy -i "${CONFIG_PARTITION}" "$file" "::$target"
    done

    # 在原来的文件之前添加用于存放分区表和配置分区的大小
    dd if=${CONFIG_PARTITION} of=${IMAGE_DEPLOY_DIR}/${HR_ROOTFS_PART_NAME}_sdcard.img bs=1024 seek=$((CONFIG_PART_START / 1024))
    dd if=${IMAGE_DEPLOY_DIR}/${HR_ROOTFS_PART_NAME}.img of=${IMAGE_DEPLOY_DIR}/${HR_ROOTFS_PART_NAME}_sdcard.img bs=1024 seek=$((ROOT_PART_START / 1024))

    exit 0
}

${HR_LOCAL_DIR}/download_samplefs.sh ${ROOTFS_ORIG_DIR}
${HR_LOCAL_DIR}/download_deb_pkgs.sh ${HR_LOCAL_DIR}/deb_packages

make_ubuntu_image

