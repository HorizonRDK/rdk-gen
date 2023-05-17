#!/bin/bash
###
 # COPYRIGHT NOTICE
 # Copyright 2023 Horizon Robotics, Inc.
 # All rights reserved.
 # @Date: 2023-03-15 15:58:13
 # @LastEditTime: 2023-04-24 12:26:18
### 

set -e

main()
{
    dep_pkg_dir="$1"
    [ ! -z ${dep_pkg_dir} ] && [ ! -d ${dep_pkg_dir} ] && mkdir ${dep_pkg_dir}
    cd ${dep_pkg_dir}

    archive_url="http://archive.sunrisepi.tech/ubuntu-rdk-beta"

    deb_pkg_list=(hobot-boot hobot-kernel-headers hobot-dtb hobot-bpu-drivers \
        hobot-configs hobot-utils \
        hobot-display hobot-wifi \
        hobot-io hobot-io-samples \
        hobot-multimedia hobot-multimedia-dev hobot-camera hobot-dnn \
        hobot-models-basic hhp-verify tros \
        hobot-spdev hobot-sp-samples \
        tros-ros-base tros-ai-msgs \
        tros-audio-control tros-audio-msg tros-audio-tracking \
        tros-body-tracking tros-dnn-benchmark-example \
        tros-dnn-node tros-dnn-node-example tros-dnn-node-sample \
        tros-elevation-net tros-gesture-control tros-hand-gesture-detection \
        tros-hand-lmk-detection tros-hbm-img-msgs tros-hobot-app-xrrobot-body-tracking \
        tros-hobot-app-xrrobot-gesture-control tros-hobot-codec tros-hobot-cv \
        tros-hobot-falldown-detection tros-hobot-hdmi tros-hobot-image-publisher \
        tros-hobot-mot tros-hobot-usb-cam tros-image-subscribe-example tros-img-msgs \
        tros-imu-sensor tros-line-follower-model tros-line-follower-perception \
        tros-mipi-cam tros-mono2d-body-detection tros-mono2d-trash-detection \
        tros-mono3d-indoor-detection tros-parking-perception tros-parking-search \
        tros-rgbd-sensor tros-websocket tros-xrrobot tros-xrrobot-msgs )

    if curl -sfO --connect-timeout 5 "${archive_url}/dists/focal/main/binary-arm64/Packages"; then
        echo "File Packages downloaded successfully"
    else
        echo "File Packages downloaded failed"
        return -1
    fi

    for pkg_name in ${deb_pkg_list[@]}
    do
        # Get the latest version number from the Packages file
        VERSION=$(cat Packages | awk -v pkg=${pkg_name} '$1 == "Package:" && $2 == pkg {getline; print}' | awk '{print $2}' | sort -V | tail -n1)
        FILENAME=$(grep -A 10 -E "^Package: ${pkg_name}$" Packages | grep '^Filename: ' | cut -d ' ' -f 2 | sort -V | tail -n1)

        if [[ -z "$VERSION" ]]; then
            echo "Error: Unable to retrieve version number for $pkg_name" >&2
            return 1
        fi

        # Get a list of all .deb files in the current directory with the same package name as pkg_name
        FILES=$(ls ${pkg_name}_*.deb 2>/dev/null || true)

        # Loop through each file and delete any with a lower version number than the latest version
        for file in $FILES; do
            file_version=$(echo ${file} | sed "s/${pkg_name}_\(.*\)_arm64.deb/\1/")
            if [[ $file_version < $VERSION ]]; then
                echo "Deleting older version of ${file}"
                rm "${file}"
            fi
        done

        # Construct the name of the deb package
        PKG_FILE=$(basename "${FILENAME}")

        # Check if the package has already been downloaded
        if [[ -f "$PKG_FILE" ]]; then
            echo "$PKG_FILE already exists in current directory. Skipping download."
            continue
        fi

        # Construct the download URL for the deb package
        PKG_URL="${archive_url}/${FILENAME}"

        # Download the deb package
        echo "Downloading ${PKG_FILE} ..."
        if ! curl -fs -O --connect-timeout 5 "$PKG_URL"; then
            echo "Error: Unable to download $pkg_name version $VERSION" >&2
            rm -f ${PKG_FILE}
            return 1
        fi
    done
}

main $@
