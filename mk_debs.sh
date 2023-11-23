#!/bin/bash

# set -x
set -e

export HR_LOCAL_DIR=$(realpath $(cd $(dirname $0); pwd))

# 编译出来的镜像保存位置
export IMAGE_DEPLOY_DIR=${HR_LOCAL_DIR}/deploy
export CROSS_COMPILE=/opt/gcc-ubuntu-9.3.0-2020.03-x86_64-aarch64-linux-gnu/bin/aarch64-linux-gnu-
export LD_LIBRARY_PATH=/opt/gcc-ubuntu-9.3.0-2020.03-x86_64-aarch64-linux-gnu/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH
[ ! -z ${IMAGE_DEPLOY_DIR} ] && [ ! -d $IMAGE_DEPLOY_DIR ] && mkdir $IMAGE_DEPLOY_DIR

ARCH=arm64

pkg_build_time=$(date '+%Y%m%d%H%M%S')

function gen_contrl_file() {
    control_path="$1"
    Package="$2"
    Version="$3"
    Description="$4"
    Architecture="$ARCH"
    Maintainer="technical_support@horizon.ai"
    if [ ! -f ${control_path}/control ];then
        touch ${control_path}/control
    fi
    cat <<-EOF > ${control_path}/control
	Package: ${Package}
	Version: ${Version}
	Architecture: ${ARCH}
	Maintainer: ${Maintainer}
	Depends: ""
	Installed-Size: 0
	Description: ${Description}

	EOF
}

function gen_conffiles() {
    local dir="$1"
    echo "Generate the conffiles, and add the files in the ${dir} directory to it"
    touch ${control_path}/conffiles

    cd ${deb_dst_dir}
    for file in $(find "./${dir}" -type f); do
        # Append each file to the conffiles file
        echo "/${file#./}" >> ${control_path}/conffiles
    done
}

function gen_copyright() {
    echo "Generate the copyright"
    mkdir -p ${deb_dst_dir}/usr/share/doc/${Package}
cat <<EOF > "${deb_dst_dir}/usr/share/doc/${Package}/copyright"
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/

Files: *
Copyright: 2023, Horizon Robotics
EOF
}

function gen_changelog() {
    echo "Generate the changelog"
    changelog=$(mktemp)

cat <<EOF > "${changelog}"
${Package} ($Version)

  * Refer to Package Release Notes for details: https://developer.horizon.ai/api/v1/fileData/documents_pi/index.html

 -- ${Maintainer}

EOF
    mkdir -p ${deb_dst_dir}/usr/share/doc/${Package}
    original="${deb_dst_dir}/usr/share/doc/${Package}/changelog.Debian.gz"
    if [ -f ${original} ]; then
        zcat "${original}" >> "${changelog}"
    fi
    gzip -9nf -c "${changelog}" > "${original}"
}

function gen_md5sum() {
    echo "Calulating md5sum"
    pushd "${deb_dst_dir}" > /dev/null
    find . -type f ! -path "./${control_path##*/}/*" ! -path "./etc/*" | LC_ALL=C sort | xargs md5sum | \
        sed -e 's@\./@ @' > "${control_path}/md5sums"
    popd > /dev/null
}

function calc_installed_size()
{
    echo "Calulating the installed size"
    installed_size=0
    list=($(find "${deb_dst_dir}" \( -type f -o -type l \) \
        ! -path "*/${control_path##*/}/control" ! -path "*/${control_path##*/}/md5sums"))
    for file in "${list[@]}"; do
        size=$(stat -c %s "${file}")
        if [ ${size} -gt 0 ];then
            ((installed_size+=(${size}+1023)/1024))
        fi
    done

    ((installed_size+=$(find "${deb_dst_dir}" ! \( -type f -o -type l \) | wc -l)))
    sed -ri "s/(^Installed-Size:) ([0-9]*)$/\1 ${installed_size}/" "${control_path}/control"
    # echo "Installed-Size: ${installed_size}" >> "${control_path}/control"
}

debian_src_dir="${HR_LOCAL_DIR}/source"
debian_dst_dir="${IMAGE_DEPLOY_DIR}/deb_pkgs"

function get_version() {
  if [ $# -ne 1 ]; then
    echo "Usage: get_version <directory_path>"
    return 1
  fi

  local dir_path="$1"
  local version_file="$dir_path/VERSION"

  if [ ! -d "$dir_path" ]; then
    echo "Error: Directory '$dir_path' does not exist."
    return 1
  fi

  if [ ! -f "$version_file" ]; then
    echo "Error: VERSION file not found in '$dir_path'."
    return 1
  fi

  local version=$(cat "$version_file")
  echo "$version"
}


function make_debian_deb() {
    pkg_name=${1}
    pkg_version=$(get_version ${debian_src_dir}/${pkg_name})-${pkg_build_time}

    #命名规范：hobot-包名_版本_架构
    deb_name=${pkg_name}_${pkg_version}_${ARCH}
    deb_dst_dir=${debian_dst_dir}/${deb_name}
    deb_src_dir=${debian_src_dir}/${pkg_name}/debian
    rm -rf ${debian_dst_dir}/${pkg_name}_*
    echo deb_dst_dir = ${deb_dst_dir}
    mkdir -p ${deb_dst_dir}
    cp -a ${deb_src_dir}/* ${deb_dst_dir}/

    echo start ${FUNCNAME} : ${deb_dst_dir}/${deb_name}.deb

    is_allowed=0
    case ${pkg_name} in
    hobot-boot)
        KERNEL_DEPLOY_DIR=${IMAGE_DEPLOY_DIR}/kernel
        if [ ! -d "${KERNEL_DEPLOY_DIR}" ]; then
            echo "Directory ${KERNEL_DEPLOY_DIR} does not exist, please build kernel."
            exit 1
        fi

        pkg_description="Kernel Package. Provides kernel image and drivers."

        gen_contrl_file "${deb_dst_dir}/DEBIAN" "${pkg_name}" "${pkg_version}" "${pkg_description}"

        # set Depends
        sed -i 's/Depends: .*$/Depends: hobot-dtb/' ${deb_dst_dir}/DEBIAN/control

        boot_dest_dir=${deb_dst_dir}/boot
        mkdir -p ${boot_dest_dir}
        cp -arf ${IMAGE_DEPLOY_DIR}/kernel/Image  ${boot_dest_dir}/
        cp -arf ${KERNEL_DEPLOY_DIR}/modules/* ${deb_dst_dir}/

        is_allowed=1
        ;;
    hobot-kernel-headers)
        KERNEL_DEPLOY_DIR=${IMAGE_DEPLOY_DIR}/kernel
        if [ ! -d "${KERNEL_DEPLOY_DIR}" ]; then
            echo "Directory ${KERNEL_DEPLOY_DIR} does not exist, please build kernel."
            exit 1
        fi

        pkg_description="Linux kernel headers for 4.14.87 on arm64
 This package provides kernel header files for 4.14.87 on arm64.
 This is useful for people who need to build external modules.
 Generally used for building out-of-tree kernel modules."

        gen_contrl_file "${deb_dst_dir}/DEBIAN" "${pkg_name}" "${pkg_version}" "${pkg_description}"

        # set Depends
        sed -i 's/Depends: .*$/Depends: hobot-boot/' ${deb_dst_dir}/DEBIAN/control

        cp -arf ${IMAGE_DEPLOY_DIR}/kernel/kernel_headers/* ${deb_dst_dir}/
        is_allowed=1
        ;;
    hobot-dtb)
        KERNEL_DEPLOY_DIR=${IMAGE_DEPLOY_DIR}/kernel
        if [ ! -d "${KERNEL_DEPLOY_DIR}" ]; then
            echo "Directory ${KERNEL_DEPLOY_DIR} does not exist, please build kernel."
            exit 1
        fi

        pkg_description="Kernel DTB Package, This package provides kernel device tree."

        gen_contrl_file "${deb_dst_dir}/DEBIAN" "${pkg_name}" "${pkg_version}" "${pkg_description}"

        # set Depends
        sed -i 's/Depends: .*$/Depends: /' ${deb_dst_dir}/DEBIAN/control

        dtb_dest_dir=${deb_dst_dir}/boot/hobot
        mkdir -p ${dtb_dest_dir}
        cp -arf ${IMAGE_DEPLOY_DIR}/kernel/dtb/* ${dtb_dest_dir}/

        is_allowed=1
        ;;
    hobot-bpu-drivers)
        pkg_description="Horizon BPU Drivers"

        gen_contrl_file "${deb_dst_dir}/DEBIAN" "${pkg_name}" "${pkg_version}" "${pkg_description}"

        # set Depends
        sed -i 's/Depends: .*$/Depends: hobot-boot/' ${deb_dst_dir}/DEBIAN/control

        is_allowed=1
        ;;
    hobot-configs)
        pkg_description="Horizon custom system configuration"

        gen_contrl_file "${deb_dst_dir}/DEBIAN" "${pkg_name}" "${pkg_version}" "${pkg_description}"

        # set Depends
        sed -i 's/Depends: .*$/Depends: hobot-boot/' ${deb_dst_dir}/DEBIAN/control

        is_allowed=1
        ;;
    hobot-utils)
        pkg_description="Horizon Software Toolset"

        gen_contrl_file "${deb_dst_dir}/DEBIAN" "${pkg_name}" "${pkg_version}" "${pkg_description}"

        # set Depends
        sed -i 's/Depends: .*$/Depends: hobot-boot/' ${deb_dst_dir}/DEBIAN/control

        cd ${debian_src_dir}/${pkg_name}/hbutils
        # real build
        make || {
            echo "make failed"
            exit 1
        }

        make install || {
            echo "make install failed"
            exit 1
        }

        mkdir -p $deb_dst_dir/usr/bin
        ls ${debian_src_dir}/${pkg_name}/hbutils/_install/hrut* > /dev/null
        if [ $? -eq 0 ];then
            echo "cp -a ${debian_src_dir}/${pkg_name}/hbutils/_install/hrut* $deb_dst_dir/usr/bin"
            cp -a ${debian_src_dir}/${pkg_name}/hbutils/_install/hrut* $deb_dst_dir/usr/bin
        fi
        cp -a ${debian_src_dir}/${pkg_name}/hbutils/utility/prebuilds/hrut* $deb_dst_dir/usr/bin
        is_allowed=1
        ;;
    hobot-display)
        pkg_description="Display Support Package"

        gen_contrl_file "${deb_dst_dir}/DEBIAN" "${pkg_name}" "${pkg_version}" "${pkg_description}"

        # set Depends
        sed -i 's/Depends: .*$/Depends: /' ${deb_dst_dir}/DEBIAN/control

        cd ${debian_src_dir}/${pkg_name}/hobot_display_services
        make || {
            echo "make failed"
            exit 1
        }

        mkdir -p $deb_dst_dir/usr/bin
        cp -a ${debian_src_dir}/${pkg_name}/hobot_display_services/display $deb_dst_dir/usr/bin/hobot_display_service
        cp -a ${debian_src_dir}/${pkg_name}/hobot_display_services/get_edid_raw_data $deb_dst_dir/usr/bin
        cp -a ${debian_src_dir}/${pkg_name}/hobot_display_services/get_hdmi_res $deb_dst_dir/usr/bin
        mkdir -p $deb_dst_dir/usr/lib
        cp -a ${debian_src_dir}/${pkg_name}/hobot_display_services/liblt8618.so $deb_dst_dir/usr/lib

        is_allowed=1
        ;;
    hobot-wifi)
        pkg_description="Wi-Fi Support Package"

        gen_contrl_file "${deb_dst_dir}/DEBIAN" "${pkg_name}" "${pkg_version}" "${pkg_description}"

        # set Depends
        sed -i 's/Depends: .*$/Depends: /' ${deb_dst_dir}/DEBIAN/control

        is_allowed=1
        ;;
    hobot-io)
        pkg_description="IO Support Package"

        gen_contrl_file "${deb_dst_dir}/DEBIAN" "${pkg_name}" "${pkg_version}" "${pkg_description}"

        # set Depends
        sed -i 's/Depends: .*$/Depends: hobot-boot/' ${deb_dst_dir}/DEBIAN/control

        mkdir -p $deb_dst_dir/usr/bin
        hb_dtb_tool_dir=${debian_src_dir}/${pkg_name}/hb_dtb_tool
        cd ${debian_src_dir}/${pkg_name}/hb_dtb_tool
        make || {
            echo "make failed"
            exit 1
        }

        if [ -f ${hb_dtb_tool_dir}/hb_dtb_tool ];then
            echo "cp -a ${hb_dtb_tool_dir}/hb_dtb_tool $deb_dst_dir/usr/bin"
            cp -a ${hb_dtb_tool_dir}/hb_dtb_tool $deb_dst_dir/usr/bin
        fi

        echo "cp -af ${hb_dtb_tool_dir}/*pi-config $deb_dst_dir/usr/bin"
        cp -af ${hb_dtb_tool_dir}/*pi-config $deb_dst_dir/usr/bin

        if [ -d ${debian_src_dir}/${pkg_name}/hb_gpio_py/hobot-gpio ];then
            echo "cp -arf ${debian_src_dir}/${pkg_name}/hb_gpio_py/hobot-gpio $deb_dst_dir/usr/lib/"
            mkdir -p $deb_dst_dir/usr/lib/
            cp -arf ${debian_src_dir}/${pkg_name}/hb_gpio_py/hobot-gpio $deb_dst_dir/usr/lib/
        fi

        is_allowed=1
        ;;
    hobot-io-samples)
        pkg_description="Example of Peripheral Interface"

        gen_contrl_file "${deb_dst_dir}/DEBIAN" "${pkg_name}" "${pkg_version}" "${pkg_description}"

        # set Depends
        sed -i 's/Depends: .*$/Depends: hobot-io/' ${deb_dst_dir}/DEBIAN/control

        is_allowed=1
        ;;
    hobot-multimedia)
        pkg_description="Multimedia Support Package"

        gen_contrl_file "${deb_dst_dir}/DEBIAN" "${pkg_name}" "${pkg_version}" "${pkg_description}"

        # set Depends
        sed -i 's/Depends: .*$/Depends: hobot-boot/' ${deb_dst_dir}/DEBIAN/control

        cp -ar ${debian_src_dir}/${pkg_name}/usr "$deb_dst_dir/"
        cp -ar ${debian_src_dir}/${pkg_name}/etc "$deb_dst_dir/"

        is_allowed=1
        ;;
    hobot-multimedia-dev)
        pkg_description="Multimedia Development Support Package"

        gen_contrl_file "${deb_dst_dir}/DEBIAN" "${pkg_name}" "${pkg_version}" "${pkg_description}"

        # set Depends
        sed -i 's/Depends: .*$/Depends: hobot-multimedia,hobot-camera/' ${deb_dst_dir}/DEBIAN/control

        cp -ar ${debian_src_dir}/${pkg_name}/usr "$deb_dst_dir/"

        is_allowed=1
        ;;
    hobot-camera)
        pkg_description="Camera Sensor Support Package"

        gen_contrl_file "${deb_dst_dir}/DEBIAN" "${pkg_name}" "${pkg_version}" "${pkg_description}"

        # set Depends
        sed -i 's/Depends: .*$/Depends: hobot-boot/' ${deb_dst_dir}/DEBIAN/control

        cd ${debian_src_dir}/${pkg_name}/drivers
        make || {
            echo "make failed"
            exit 1
        }

        mkdir -p $deb_dst_dir/usr/lib/sensorlib
        cp -a ${debian_src_dir}/${pkg_name}/drivers/*.so $deb_dst_dir/usr/lib/sensorlib

        find ${debian_src_dir}/${pkg_name}/camera_configs -name "*.so" -exec cp {} $deb_dst_dir/usr/lib/sensorlib/ \;

        mkdir -p $deb_dst_dir/app/
        cp -ar ${debian_src_dir}/${pkg_name}/camera_configs $deb_dst_dir/app/

        mkdir -p "$deb_dst_dir/usr/bin/"
        cp ${debian_src_dir}/${pkg_name}/camera_configs/common/initweb.sh "$deb_dst_dir/usr/bin/"
        is_allowed=1
        ;;
    hobot-dnn)
        pkg_description="BPU Runtime Support Package"

        gen_contrl_file "${deb_dst_dir}/DEBIAN" "${pkg_name}" "${pkg_version}" "${pkg_description}"

        # set Depends
        sed -i 's/Depends: .*$/Depends: hobot-boot/' ${deb_dst_dir}/DEBIAN/control

        cp -ar ${debian_src_dir}/${pkg_name}/usr "$deb_dst_dir/"

        is_allowed=1
        ;;
    hobot-spdev)
        pkg_description="Python and C/C++ Development Interface"

        gen_contrl_file "${deb_dst_dir}/DEBIAN" "${pkg_name}" "${pkg_version}" "${pkg_description}"

        # set Depends
        sed -i 's/Depends: .*$/Depends: hobot-multimedia,hobot-camera,hobot-dnn/' ${deb_dst_dir}/DEBIAN/control

        cd ${debian_src_dir}/${pkg_name}

        ./build.sh || {
            echo "build.sh failed"
            exit 1
        }

        mkdir -p $deb_dst_dir/usr/lib
        cp -arf ${debian_src_dir}/${pkg_name}/output/*.so $deb_dst_dir/usr/lib/
        mkdir -p $deb_dst_dir/usr/include
        cp -arf ${debian_src_dir}/${pkg_name}/output/include/*.h  $deb_dst_dir/usr/include/
        mkdir -p $deb_dst_dir/usr/lib/hobot_spdev/
        cp -arf ${debian_src_dir}/${pkg_name}/output/*.whl  $deb_dst_dir/usr/lib/hobot_spdev/
        is_allowed=1
        ;;
    hobot-sp-samples)
        pkg_description="Example of Python and C/C++ Development Interface"

        gen_contrl_file "${deb_dst_dir}/DEBIAN" "${pkg_name}" "${pkg_version}" "${pkg_description}"

        # set Depends
        sed -i 's/Depends: .*$/Depends: hobot-spdev,hobot-models-basic/' ${deb_dst_dir}/DEBIAN/control

        is_allowed=1
        ;;
    hobot-multimedia-samples)
        pkg_description="Example of Multimedia (Hapi)"

        gen_contrl_file "${deb_dst_dir}/DEBIAN" "${pkg_name}" "${pkg_version}" "${pkg_description}"

        # set Depends
        sed -i 's/Depends: .*$/Depends: hobot-multimedia-dev,hobot-multimedia/' ${deb_dst_dir}/DEBIAN/control

        is_allowed=1
        ;;
    hobot-miniboot)
        pkg_description="RDK Miniboot updater"

        gen_contrl_file "${deb_dst_dir}/DEBIAN" "${pkg_name}" "${pkg_version}" "${pkg_description}"

        # set Depends
        sed -i 's/Depends: .*$/Depends: /' ${deb_dst_dir}/DEBIAN/control

        is_allowed=1
        ;;
    *)
        echo "Error: Make package ${pkg_name}-${pkg_version} failed"
        is_allowed=0
        ;;
    esac
    if [ $is_allowed == 1 ];then
        gen_changelog
        gen_copyright
        gen_md5sum
        calc_installed_size
        echo "#################### control ####################"
        cat ${deb_dst_dir}/DEBIAN/control
        echo "#################################################"
        fakeroot dpkg -b ${deb_dst_dir} ${deb_dst_dir}.deb
    fi
}

deb_pkg_list=(
    "hobot-boot"
    "hobot-kernel-headers"
    "hobot-dtb"
    "hobot-bpu-drivers"
    "hobot-configs"
    "hobot-utils"
    "hobot-display"
    "hobot-wifi"
    "hobot-io"
    "hobot-io-samples"
    "hobot-multimedia"
    "hobot-multimedia-dev"
    "hobot-camera"
    "hobot-dnn"
    "hobot-spdev"
    "hobot-sp-samples"
    "hobot-multimedia-samples"
)

function help_msg
{
    echo "./mk_deb.sh [all] | [deb_name]"
    for pkg_name in ""${deb_pkg_list[@]}""; do
        echo "    ${pkg_name}"
    done
}


if [ $# -eq 0 ];then
    # clear all
    rm -rf $debian_dst_dir
    mkdir -p $debian_dst_dir
    # make all
    for pkg_name in "${deb_pkg_list[@]}"; do
        echo "Make package ${pkg_name}"
        make_debian_deb ${pkg_name}
    done
elif [ $# -eq 1 ];then
    key_name=${1}
    found=false
    for pkg_name in "${deb_pkg_list[@]}"; do
        if [[ "${pkg_name}" == "${key_name}" ]]; then
            found=true
            mkdir -p $debian_dst_dir
            echo "Make package ${pkg_name}"
            make_debian_deb ${pkg_name}
            break
        fi
    done

    if ! $found; then
        echo "The debian package named by '${key_name}' is not supported, please check the input parameters."
        help_msg
    fi
else
    help_msg
    exit 1
fi
