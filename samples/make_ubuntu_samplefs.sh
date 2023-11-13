#!/bin/bash

set -e
BUILD_USER=$(logname)
echo "current build user:${BUILD_USER}."
LOCAL_DIR=$(realpath $(cd $(dirname $0); pwd))

# Ubuntu 20.04
RELEASE="focal"
ARCH=arm64
DEBOOTSTRAP_COMPONENTS="main,universe"
# apt_mirror="http://ports.ubuntu.com/"
UBUNTU_MIRROR="mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/"

# apt_mirror="http://${UBUNTU_MIRROR}"
# To use a local proxy to cache apt packages, you need to install apt-cacher-ng
apt_mirror="http://localhost:3142/${UBUNTU_MIRROR}"

PYTHON_PACKAGE_LIST="numpy opencv-python pySerial i2cdev spidev matplotlib pillow \
websocket websockets lark-parser netifaces google protobuf==3.20.1 "

DEBOOTSTRAP_LIST="systemd sudo locales apt-utils init dbus kmod udev bash-completion "

get_package_list()
{
    package_list_file="${LOCAL_DIR}/ubuntu-${RELEASE}-${1}-${ARCH}-packages"
    if [ ! -f "${package_list_file}" ]; then
        echo "ERROR: package list file - ${package_list_file} not found" > /dev/stderr
        exit 1
    fi
    PACKAGE_LIST=$(cat ${package_list_file} | sed ':a;N;$!ba;s/\n/ /g')
    echo ${PACKAGE_LIST}
}

# The default version is Ubuntu Desktop
ADD_PACKAGE_LIST="$(get_package_list "base") $(get_package_list "server") $(get_package_list "desktop") "
ubuntufs_src="${LOCAL_DIR}/desktop"
samplefs_version="v2.1.0"

# Ubuntu Desktop
if [[ $1 == "d"*  ]] ; then
    ADD_PACKAGE_LIST="$(get_package_list "base") $(get_package_list "server") $(get_package_list "desktop") "
    ubuntufs_src="${LOCAL_DIR}/desktop"
    tar_file=${ubuntufs_src}/samplefs_desktop-${samplefs_version}.tar.gz
fi

# Ubuntu Server
if [[ $1 == "s"*  ]] ; then
    ADD_PACKAGE_LIST="$(get_package_list "base") $(get_package_list "server") "
    ubuntufs_src="${LOCAL_DIR}/server"
    tar_file=${ubuntufs_src}/samplefs_server-${samplefs_version}.tar.gz
fi

# Ubuntu Base
if [[ $1 == "b"*  ]] ; then
    ADD_PACKAGE_LIST="$(get_package_list "base") "
    ubuntufs_src="${LOCAL_DIR}/base"
    tar_file=${ubuntufs_src}/samplefs_base-${samplefs_version}.tar.gz
fi

echo "Make ${tar_file}"
echo ${ADD_PACKAGE_LIST}

root_path=${ubuntufs_src}/${RELEASE}-xj3-${ARCH}

# Release specific packages
case $RELEASE in
    bionic)
        # Dependent debootstarp packages
        DEBOOTSTRAP_COMPONENTS="main,universe"
        DEBOOTSTRAP_LIST+=" module-init-tools"
        ADD_PACKAGE_LIST+=" android-tools-adbd"
    ;;
    focal)
        # Dependent debootstarp packages
        DEBOOTSTRAP_COMPONENTS="main,universe"
        DEBOOTSTRAP_LIST+=""
        ADD_PACKAGE_LIST+=""
    ;;
esac


log_out()
{
    # log function parameters to install.log
    local tmp=""
    [[ -n $2 ]] && tmp="[\e[0;33m $2 \x1B[0m]"

    case $3 in
        err)
        echo -e "[\e[0;31m error \x1B[0m] $1 $tmp"
        ;;

        wrn)
        echo -e "[\e[0;35m warn \x1B[0m] $1 $tmp"
        ;;

        ext)
        echo -e "[\e[0;32m o.k. \x1B[0m] \e[1;32m$1\x1B[0m $tmp"
        ;;

        info)
        echo -e "[\e[0;32m o.k. \x1B[0m] $1 $tmp"
        ;;

        *)
        echo -e "[\e[0;32m .... \x1B[0m] $1 $tmp"
        ;;
    esac
}

# mount_chroot <target>
#
# helper to reduce code duplication
#
mount_chroot()
{
    local target=$1
    log_out "Mounting" "$target" "info"
    mount -t proc chproc "${target}"/proc
    mount -t sysfs chsys "${target}"/sys
    mount -t devtmpfs chdev "${target}"/dev || mount --bind /dev "${target}"/dev
    mount -t devpts chpts "${target}"/dev/pts
} 

# unmount_on_exit <target>
#
# helper to reduce code duplication
#
unmount_on_exit()
{
    local target=$1
    trap - INT TERM EXIT
    umount_chroot "${target}/"
    rm -rf ${target}
}


# umount_chroot <target>
#
# helper to reduce code duplication
#
umount_chroot()
{
    local target=$1
    log_out "Unmounting" "$target" "info"
    while grep -Eq "${target}.*(dev|proc|sys)" /proc/mounts
    do
        umount -l --recursive "${target}"/dev >/dev/null 2>&1
        umount -l "${target}"/proc >/dev/null 2>&1
        umount -l "${target}"/sys >/dev/null 2>&1
        sleep 5
    done
} 

create_base_sources_list()
{
    local release=$1
    local basedir=$2
    [[ -z $basedir ]] && log_out "No basedir passed to create_base_sources_list" " " "err"
    # cp /etc/apt/sources.list "${basedir}"/etc/apt/sources.list
    cat <<-EOF > "${basedir}"/etc/apt/sources.list
# See http://help.ubuntu.com/community/UpgradeNotes for how to upgrade to
# newer versions of the distribution.
deb http://${UBUNTU_MIRROR} $release main restricted universe multiverse
#deb-src http://${UBUNTU_MIRROR} $release main restricted universe multiverse
EOF
}


create_sources_list()
{
    local release=$1
    local basedir=$2
    [[ -z $basedir ]] && log_out "No basedir passed to create_sources_list" " " "err"
    # cp /etc/apt/sources.list "${basedir}"/etc/apt/sources.list
    cat <<-EOF > "${basedir}"/etc/apt/sources.list
# See http://help.ubuntu.com/community/UpgradeNotes for how to upgrade to
# newer versions of the distribution.
deb http://${UBUNTU_MIRROR} $release main restricted universe multiverse
#deb-src http://${UBUNTU_MIRROR} $release main restricted universe multiverse

deb http://${UBUNTU_MIRROR} ${release}-security main restricted universe multiverse
#deb-src http://${UBUNTU_MIRROR} ${release}-security main restricted universe multiverse

deb http://${UBUNTU_MIRROR} ${release}-updates main restricted universe multiverse
#deb-src http://${UBUNTU_MIRROR} ${release}-updates main restricted universe multiverse

deb http://${UBUNTU_MIRROR} ${release}-backports main restricted universe multiverse
#deb-src http://${UBUNTU_MIRROR} ${release}-backports main restricted universe multiverse
EOF
}

end_debootstrap()
{
    local target=$1
}

extract_base_root() {
    local tar_file=$1
    local dest_dir=$2
    rm -rf $dest_dir
    mkdir -p $dest_dir
    if [ ! -f "${tar_file}0" ];then
        log_out "File is not exist!" "${tar_file}0" "err"
        exit -1
    fi
    if [ ! -d $dest_dir ];then
        log_out "Dir is not exist!" "${dest_dir}" "err"
        exit -1
    fi
    log_out "Start extract" "$tar_file to $dest_dir" "info"
    tar --same-owner --numeric-owner -xzpf ${tar_file} -C ${dest_dir}
    mkdir -p ${dest_dir}/{dev,proc,tmp,run,proc,sys,userdata,app}
}

compress_base_root() {
    local tar_file=$1
    local src_dir=$2
    if [ ! -d $src_dir ];then
        log_out "Dir is not exist!" "${src_dir}" "err"
        exit -1
    fi
    log_out "Start compress" "${tar_file} from ${src_dir}" "info"
    tar --numeric-owner -czpf ${tar_file} -C $src_dir/ --exclude='./dev/*' --exclude='./proc/*' --exclude='./run/*' --exclude='./tmp/*' --exclude='./sys/*' --exclude='./usr/lib/aarch64-linux-gnu/dri/*' .
}

check_ret(){
    ret=$1
    if [ ${ret} -ne 0 ];then
        log_out "return value:" "${ret}" "err"
        exit -1
    fi
}

install_package()
{
    retry=0
    retry_max=5

    echo "Install ${1}"
    while true
    do
        eval 'LC_ALL=C LANG=C chroot ${dst_dir} /bin/bash -c "DEBIAN_FRONTEND=noninteractive apt-get -y $apt_extra --no-install-recommends install ${1}"'
        if [[ $? -eq 0 ]]; then
            return 0
        else
            retry=$( expr $retry + 1 )
            if [ "${retry}" == "${retry_max}" ]; then
                return 1
            else
                sleep 1
                echo "Retrying ${1} package install"
            fi
        fi
    done
}

make_base_root() {
    local dst_dir=$1
    rm -rf $dst_dir
    mkdir -p $dst_dir
    trap "unmount_on_exit ${dst_dir}" INT TERM EXIT
    log_out "Installing base system : " "Stage 2/1" "info"
    debootstrap --variant=minbase \
        --include=${DEBOOTSTRAP_LIST// /,} \
        --arch=${ARCH} \
        --components=${DEBOOTSTRAP_COMPONENTS} \
        --foreign ${RELEASE} \
        $dst_dir \
        $apt_mirror
    if [[ $? -ne 0 ]] || [[ ! -f $dst_dir/debootstrap/debootstrap ]];then 
        log_out "Debootstrap base system first stage failed" "err"
        exit -1
    fi
    if [ ! -f /usr/bin/qemu-aarch64-static ];then
        log_out "File is not exist!" "Please install qemu-user-static with apt first" "err"
        exit -1
    else
        log_out "Copy qemu-aarch64-static to" "$dst_dir/usr/bin" "info"
        cp /usr/bin/qemu-aarch64-static $dst_dir/usr/bin
    fi

    log_out "Installing base system : " "Stage 2/2" "info"
    chroot ${dst_dir} /bin/bash -c "/debootstrap/debootstrap --second-stage"
    if [[ $? -ne 0 ]] || [[ ! -f $dst_dir/bin/bash ]];then
        log_out "Debootstrap base system second stage failed" "err"
        exit -1
    fi
    mount_chroot ${dst_dir}

    # this should fix resolvconf installation failure in some cases
    chroot ${dst_dir} /bin/bash -c 'echo "resolvconf resolvconf/linkify-resolvconf boolean false" | debconf-set-selections'

    local apt_extra="-o Acquire::http::Proxy=\"http://localhost:3142\""
    # base for gcc 9.3
    create_base_sources_list ${RELEASE} ${dst_dir}
    log_out "Updating base packages" "${dst_dir}" "info"
    eval 'LC_ALL=C LANG=C chroot ${dst_dir} /bin/bash -c "apt-get -q -y $apt_extra update"'
    [[ $? -ne 0 ]] && exit -1
    log_out "Upgrading base packages" "${dst_dir}" "info"
    eval 'LC_ALL=C LANG=C chroot ${dst_dir} /bin/bash -c "apt-get -q -y $apt_extra upgrade"'
    [[ $? -ne 0 ]] && exit -1
    log_out "Installing base packages" "${dst_dir}" "info"
    package_list=$(echo "${ADD_PACKAGE_LIST}")
    if [ ! -z "${package_list}" ]; then
        for package in ${package_list}
        do
            if ! install_package "${package}"; then
                echo "ERROR: Failed to install ${package}"
                exit -1
            fi
        done
    fi

    # Fixed GCC version: 9.3.0
    chroot ${dst_dir} /bin/bash -c "apt-mark hold cpp-9 g++-9 gcc-9-base gcc-9 libasan5 libgcc-9-dev libstdc++-9-dev"

    # upgrade packages
    create_sources_list ${RELEASE} ${dst_dir}
    log_out "Updating focal-updates and focal-security packages" "${dst_dir}" "info"
    eval 'LC_ALL=C LANG=C chroot ${dst_dir} /bin/bash -c "apt-get -q -y $apt_extra update"'
    [[ $? -ne 0 ]] && exit -1
    log_out "Upgrading base packages" "${dst_dir}" "info"
    eval 'LC_ALL=C LANG=C chroot ${dst_dir} /bin/bash -c "apt-get -q -y $apt_extra upgrade"'
    [[ $? -ne 0 ]] && exit -1
    log_out "Installing base packages" "${dst_dir}" "info"
    package_list=$(echo "${ADD_PACKAGE_LIST}")
    if [ ! -z "${package_list}" ]; then
        for package in ${package_list}
        do
            if ! install_package "${package}"; then
                echo "ERROR: Failed to install ${package}"
                exit -1
            fi
        done
    fi
    chroot ${dst_dir} /bin/bash -c "dpkg --get-selections" | grep -v deinstall | awk '{print $1}' | cut -f1 -d':' | sort > ${tar_file}.info

    chroot ${dst_dir} /bin/bash -c "pip3 config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple"
    chroot ${dst_dir} /bin/bash -c "pip3 config set install.trusted-host https://pypi.tuna.tsinghua.edu.cn"
    chroot ${dst_dir} /bin/bash -c "pip3 install ${PYTHON_PACKAGE_LIST}"
    py_pkg_list=$(echo "${PYTHON_PACKAGE_LIST}")
    if [ ! -z "${py_pkg_list}" ]; then
        for package in ${py_pkg_list}
        do
            chroot ${dst_dir} /bin/bash -c "pip3 install ${package}"
        done
    fi
    chroot ${dst_dir} /bin/bash -c "rm -rf /root/.cache"

    DEST_LANG="en_US.UTF-8"
    DEST_LANG_CN="zh_CN.UTF-8"
    log_out "Configuring locales" "${DEST_LANG}" "${DEST_LANG_CN}" "info"
    if [ -f ${dst_dir}/etc/locale.gen ];then
        sed -i "s/^# $DEST_LANG/$DEST_LANG/" $dst_dir/etc/locale.gen
        sed -i "s/^# $DEST_LANG_CN/$DEST_LANG_CN/" $dst_dir/etc/locale.gen
    fi
    eval 'LC_ALL=C LANG=C chroot $dst_dir /bin/bash -c "locale-gen $DEST_LANG"'
    eval 'LC_ALL=C LANG=C chroot $dst_dir /bin/bash -c "locale-gen $DEST_LANG_CN"'
    eval 'LC_ALL=C LANG=C chroot $dst_dir /bin/bash -c "update-locale LANG=$DEST_LANG LANGUAGE=$DEST_LANG"'

    chroot "${dst_dir}" /bin/bash -c "systemctl disable hostapd NetworkManager-wait-online.service"

    chroot ${dst_dir} /bin/bash -c "apt clean"

    chroot ${dst_dir} /bin/bash -c "rm -f /var/lib/apt/lists/mirrors*"
    chroot ${dst_dir} /bin/bash -c "rm -rf /home/${BUILD_USER}"

    umount_chroot ${dst_dir}
    end_debootstrap ${dst_dir}

    trap - INT TERM EXIT
}

log_out "Build ubuntu base" "root_path=$root_path tar_file=$tar_file" "info"
log_out "Start build" "ubuntu base :${RELEASE}-xj3-${ARCH}" "info"

if [ ! -f "${tar_file}0" ];then
    make_base_root "${root_path}"
    sync
    compress_base_root "${tar_file}" "${root_path}"
    sync
else
    sync
fi

log_out "End build ubuntu" "${ubuntufs_src}" "info"
exit 0
