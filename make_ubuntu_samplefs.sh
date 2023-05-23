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

COMMON_PACKAGE_LIST=" "
PYTHON_PACKAGE_LIST="numpy opencv-python pySerial i2cdev spidev matplotlib pillow \
websocket websockets lark-parser netifaces google protobuf==3.20.1 "

#DEBOOTSTRAP_LIST="systemd sudo locales apt-utils openssh-server ssh dbus init module-init-tools \
DEBOOTSTRAP_LIST="systemd sudo vim locales apt-utils openssh-server ssh dbus init \
strace kmod init udev bash-completion netbase network-manager \
ifupdown ethtool net-tools iputils-ping "

BASE_PACKAGE_LIST="file openssh-server ssh bsdmainutils whiptail device-tree-compiler \
bzip2 htop rsyslog parted python3 python3-pip console-setup fake-hwclock \
ncurses-term gcc g++ toilet sysfsutils rsyslog tzdata u-boot-tools \
libcjson1 libcjson-dev db-util diffutils e2fsprogs libc6 xterm \
libcrypt1 libcrypto++6 libdevmapper1.02.1 libedit2 libgcc-s1-arm64-cross libgcrypt20 libgpg-error0 \
libion0 libjsoncpp1 libkcapi1 libmenu-cache3 libnss-db libpcap0.8 libpcre3 \
libstdc++-10-dev libvorbis0a libzmq5 lvm2 makedev mtd-utils ncurses-term ncurses-base nettle-bin \
nfs-common openssl perl-base perl tftpd-hpa tftp-hpa tzdata watchdog \
wpasupplicant alsa-utils base-files cryptsetup diffutils dosfstools \
dropbear e2fsprogs ethtool exfat-utils ffmpeg i2c-tools iperf3 \
libaio1 libasound2 libattr1 libavcodec58 libavdevice58 libavfilter7 libavformat58 libavutil56 \
libblkid1 libc6 libc6-dev libcap2 libcom-err2 libcrypt-dev libdbus-1-3 libexpat1 libext2fs2 libflac8 \
libgcc1 libgdbm-compat4 libgdbm-dev libgdbm6 libgmp10 libgnutls30 libidn2-0 libjson-c4 libkmod2 \
liblzo2-2 libmount1 libncurses5 libncursesw5 libnl-3-200 libnl-genl-3-200 libogg0 libpopt0 \
libpostproc55 libreadline8 libsamplerate0 libsndfile1 libss2 libssl1.1 libstdc++6 libswresample3 \
libswscale5 libtinfo5 libtirpc3 libudev1 libunistring2 libusb-1.0-0 libuuid1 libwrap0 libx11-6 \
libxau6 libxcb1 libxdmcp6 libxext6 libxv1 libz-dev libz1 lrzsz lvm2 mtd-utils net-tools \
netbase openssh-sftp-server openssl rpcbind screen sysstat tcpdump libgl1-mesa-glx \
thin-provisioning-tools trace-cmd tzdata usbutils watchdog libturbojpeg libturbojpeg0-dev \
base-passwd libasound2-dev libavcodec-dev libavformat-dev libavutil-dev libcrypto++-dev \
libjsoncpp-dev libssl-dev libswresample-dev libzmq3-dev perl sed \
symlinks libunwind8 libperl-dev devmem2 ifmetric v4l-utils python3-dev \
build-essential libbullet-dev libasio-dev libtinyxml2-dev iotop htop iw wireless-tools \
bluetooth bluez blueman sqlite3 libsqlite3-dev libeigen3-dev liblog4cxx-dev libcurl4-openssl-dev \
libboost-dev libboost-date-time-dev libboost-thread-dev \
libwhoopsie-preferences0 libwhoopsie0 whoopsie whoopsie-preferences \
distro-info ubuntu-advantage-tools python3-click python3-colorama "

SERVER_PACKAGE_LIST="file openssh-server ssh bsdmainutils rfkill whiptail device-tree-compiler \
bzip2 htop rsyslog make cmake parted python3 python3-pip console-setup fake-hwclock \
ncurses-term gcc g++ toilet sysfsutils rsyslog tzdata u-boot-tools \
libcjson1 libcjson-dev db-util diffutils e2fsprogs iptables libc6 xterm \
libcrypt1 libcrypto++6 libdevmapper1.02.1 libedit2 libgcc-s1-arm64-cross libgcrypt20 libgpg-error0 \
libion0 libjsoncpp1 libkcapi1 libmenu-cache3 libnss-db libpcap0.8 libpcre3 \
libstdc++-10-dev libvorbis0a libzmq5 lvm2 makedev mtd-utils ncurses-term ncurses-base nettle-bin \
nfs-common openssl perl-base perl tftpd-hpa tftp-hpa tzdata watchdog \
wpasupplicant alsa-utils base-files cryptsetup diffutils dosfstools \
dropbear e2fsprogs ethtool exfat-utils ffmpeg file gdb gdbserver i2c-tools iperf3 iptables \
libaio1 libasound2 libattr1 libavcodec58 libavdevice58 libavfilter7 libavformat58 libavutil56 \
libblkid1 libc6 libc6-dev libcap2 libcom-err2 libcrypt-dev libdbus-1-3 libexpat1 libext2fs2 libflac8 \
libgcc1 libgdbm-compat4 libgdbm-dev libgdbm6 libgmp10 libgnutls30 libidn2-0 libjson-c4 libkmod2 \
liblzo2-2 libmount1 libncurses5 libncursesw5 libnl-3-200 libnl-genl-3-200 libogg0 libpopt0 \
libpostproc55 libreadline8 libsamplerate0 libsndfile1 libss2 libssl1.1 libstdc++6 libswresample3 \
libswscale5 libtinfo5 libtirpc3 libudev1 libunistring2 libusb-1.0-0 libuuid1 libwrap0 libx11-6 \
libxau6 libxcb1 libxdmcp6 libxext6 libxv1 libz-dev libz1 lrzsz lvm2 mtd-utils net-tools \
netbase openssh-sftp-server openssl rpcbind screen sysstat tcpdump libgl1-mesa-glx \
thin-provisioning-tools trace-cmd tzdata usbutils watchdog libturbojpeg libturbojpeg0-dev \
base-passwd libasound2-dev libavcodec-dev libavformat-dev libavutil-dev libcrypto++-dev \
libjsoncpp-dev libssl-dev libswresample-dev libzmq3-dev perl sed \
symlinks libunwind8 libperl-dev devmem2 tree unzip ifmetric v4l-utils python3-dev \
wget curl gnupg2 lsb-release lshw lsof memstat aptitude apt-show-versions \
build-essential libbullet-dev libasio-dev libtinyxml2-dev iotop htop iw wireless-tools \
bluetooth bluez blueman sqlite3 libsqlite3-dev libeigen3-dev liblog4cxx-dev libcurl4-openssl-dev \
libboost-dev libboost-date-time-dev libboost-thread-dev \
python3-wstool ninja-build stow \
libgoogle-glog-dev libgflags-dev libatlas-base-dev libeigen3-dev libsuitesparse-dev \
lua5.2 liblua5.2-dev libluabind-dev libprotobuf-dev protobuf-compiler libcairo2-dev \
hostapd dnsmasq isc-dhcp-server x11vnc fuse ntfs-3g libtinyxml-dev "

DESKTOP_PACKAGE_LIST="xubuntu-desktop xserver-xorg-video-fbdev policykit-1-gnome notification-daemon \
tightvncserver network-manager-gnome xfce4-terminal tightvncserver firefox firefox-locale-zh-hans \
gedit \
language-pack-zh-hans language-pack-zh-hans-base language-pack-en language-pack-en-base \
fonts-beng \
fonts-beng-extra fonts-deva fonts-deva-extra fonts-freefont-ttf fonts-gargi fonts-gubbi fonts-gujr fonts-gujr-extra fonts-guru fonts-guru-extra \
fonts-indic fonts-kacst fonts-kacst-one fonts-kalapi fonts-khmeros-core fonts-knda fonts-lao fonts-liberation fonts-lklug-sinhala \
fonts-lohit-beng-assamese fonts-lohit-beng-bengali fonts-lohit-deva fonts-lohit-gujr fonts-lohit-guru fonts-lohit-knda fonts-lohit-mlym \
fonts-lohit-orya fonts-lohit-taml fonts-lohit-taml-classical fonts-lohit-telu fonts-mlym fonts-nakula fonts-navilu fonts-noto-cjk \
fonts-noto-core fonts-noto-hinted fonts-noto-ui-core fonts-orya fonts-orya-extra fonts-pagul fonts-sahadeva fonts-samyak-deva fonts-samyak-gujr \
fonts-samyak-mlym fonts-samyak-taml fonts-sarai fonts-sil-abyssinica fonts-sil-padauk fonts-smc fonts-smc-anjalioldlipi fonts-smc-chilanka \
fonts-smc-dyuthi fonts-smc-gayathri fonts-smc-karumbi fonts-smc-keraleeyam fonts-smc-manjari fonts-smc-meera fonts-smc-rachana \
fonts-smc-raghumalayalamsans fonts-smc-suruma fonts-smc-uroob fonts-symbola fonts-taml fonts-telu fonts-telu-extra fonts-thai-tlwg \
fonts-tibetan-machine fonts-tlwg-garuda fonts-tlwg-garuda-ttf fonts-tlwg-kinnari fonts-tlwg-kinnari-ttf fonts-tlwg-laksaman \
fonts-tlwg-laksaman-ttf fonts-tlwg-loma fonts-tlwg-loma-ttf fonts-tlwg-mono fonts-tlwg-mono-ttf fonts-tlwg-norasi fonts-tlwg-norasi-ttf \
fonts-tlwg-purisa fonts-tlwg-purisa-ttf fonts-tlwg-sawasdee fonts-tlwg-sawasdee-ttf fonts-tlwg-typewriter fonts-tlwg-typewriter-ttf \
fonts-tlwg-typist fonts-tlwg-typist-ttf fonts-tlwg-typo fonts-tlwg-typo-ttf fonts-tlwg-umpush fonts-tlwg-umpush-ttf fonts-tlwg-waree \
fonts-tlwg-waree-ttf fonts-ubuntu fonts-yrsa-rasa fonts-arphic-ukai fonts-arphic-gkai00mp fonts-arphic-bkai00mp xfonts-wqy ttf-wqy-microhei ttf-wqy-zenhei \
ibus-rime librime-data-wubi librime-data-pinyin-simp librime-data-stroke-simp \
fcitx wbritish firefox-locale-en fonts-arphic-ukai fcitx-module-cloudpinyin fonts-arphic-uming hunspell-en-ca \
fcitx-table-wubi hunspell-en-za wamerican hunspell-en-au fcitx-frontend-gtk3 fcitx-ui-qimpanel fcitx-pinyin \
fonts-noto-cjk-extra fcitx-sunpinyin hunspell-en-gb fcitx-frontend-gtk2 fcitx-ui-classic hunspell-en-us fcitx-frontend-qt5 \
language-pack-gnome-zh-hans language-pack-gnome-zh-hans-base language-pack-gnome-zh-hant language-pack-gnome-zh-hant-base \
fcitx-chewing fcitx-table-cangjie firefox-locale-zh-hant \
smplayer pavucontrol pulseaudio \
libvulkan1 mesa-vulkan-drivers libtinyxml-dev "

# The default version is Ubuntu Desktop
ADD_PACKAGE_LIST="${BASE_PACKAGE_LIST} ${SERVER_PACKAGE_LIST} ${DESKTOP_PACKAGE_LIST} "

ubuntufs_src="${LOCAL_DIR}/desktop"

# Ubuntu Desktop
if [[ $1 == *"d"*  ]] ; then
    desktop="true"
    ADD_PACKAGE_LIST="${BASE_PACKAGE_LIST} ${SERVER_PACKAGE_LIST} ${DESKTOP_PACKAGE_LIST} "
    ubuntufs_src="${LOCAL_DIR}/desktop"
fi

# Ubuntu Server
if [[ $1 == *"s"*  ]] ; then
    ADD_PACKAGE_LIST="${BASE_PACKAGE_LIST} ${SERVER_PACKAGE_LIST}"
    ubuntufs_src="${LOCAL_DIR}/server"
fi

# Ubuntu Base
if [[ $1 == *"b"*  ]] ; then
    ADD_PACKAGE_LIST="${BASE_PACKAGE_LIST} "
    ubuntufs_src="${LOCAL_DIR}/base"
fi

root_path=${ubuntufs_src}/${RELEASE}-xj3-${ARCH}
tar_file=${ubuntufs_src}/samplefs_desktop-v2.0.0.tar.gz

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
    eval 'LC_ALL=C LANG=C chroot ${dst_dir} /bin/bash -c "DEBIAN_FRONTEND=noninteractive apt-get -y -q $apt_extra --no-install-recommends install $ADD_PACKAGE_LIST"'
    [[ $? -ne 0 ]] && exit -1
    chroot ${dst_dir} /bin/bash -c "dpkg --get-selections" | grep -v deinstall | awk '{print $1}' | cut -f1 -d':' > ${tar_file}.info

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
    eval 'LC_ALL=C LANG=C chroot ${dst_dir} /bin/bash -c "DEBIAN_FRONTEND=noninteractive apt-get -y -q $apt_extra --no-install-recommends install $ADD_PACKAGE_LIST"'
    [[ $? -ne 0 ]] && exit -1
    chroot ${dst_dir} /bin/bash -c "dpkg --get-selections" | grep -v deinstall | awk '{print $1}' | cut -f1 -d':' > ${tar_file}.info

    chroot ${dst_dir} /bin/bash -c "pip3 config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple"
    chroot ${dst_dir} /bin/bash -c "pip3 config set install.trusted-host https://pypi.tuna.tsinghua.edu.cn"
    chroot ${dst_dir} /bin/bash -c "pip3 install ${PYTHON_PACKAGE_LIST}"

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

    chroot "${dst_dir}" /bin/bash -c "systemctl disable hostapd dnsmasq NetworkManager-wait-online.service"

     #/etc/apt/source.list
    chroot ${dst_dir} /bin/bash -c "apt clean"

    chroot ${dst_dir} /bin/bash -c "rm -f /var/lib/apt/lists/mirrors*"
    chroot ${dst_dir} /bin/bash -c "rm -rf /home/${BUILD_USER}"

    umount_chroot ${dst_dir}
    end_debootstrap ${dst_dir}
    chmod 777 ${dst_dir}/home/ -R

    #store size of dst_dir to ${tar_file}.info
    local dusize=`du -sh ${dst_dir} 2> /dev/null |awk '{print $1}'`
    echo "DIR_DU_SIZE ${dusize%%M}" >> ${tar_file}.info
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
