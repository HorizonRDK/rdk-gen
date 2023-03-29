#!/bin/bash
###
 # COPYRIGHT NOTICE
 # Copyright 2023 Horizon Robotics, Inc.
 # All rights reserved.
 # @Date: 2023-03-15 15:58:13
 # @LastEditTime: 2023-03-19 13:39:45
### 

set -e

main()
{
    cd $1

    deb_pkg_list=(hobot-boot hobot-kernel-headers hobot-dtb hobot-bpu-drivers \
        hobot-configs hobot-utils \
        hobot-hdmi hobot-wifi \
        hobot-io hobot-io-samples \
        hobot-multimedia hobot-multimedia-dev hobot-camera hobot-dnn \
        hobot-spdev hobot-sp-samples \
        hobot_models_basic hhp-verify tros )

    for pkg_name in ${deb_pkg_list[@]}
    do
        # Get the latest version number from the Packages file
        VERSION=$(curl -sf http://archive.sunrisepi.tech/ubuntu-rdk-beta/dists/focal/main/binary-arm64/Packages | awk -v pkg=$pkg_name '$1 == "Package:" && $2 == pkg {getline; print}' | awk '{print $2}' | sort -V | tail -n1)

        if [[ -z "$VERSION" ]]; then
            echo "Error: Unable to retrieve version number for $pkg_name" >&2
            return 1
        fi

        # Get a list of all .deb files in the current directory with the same package name as PKG_NAME
        FILES=$(ls ${PKG_NAME}_*.deb 2>/dev/null)

        # Loop through each file and delete any with a lower version number than the latest version
        for file in $FILES; do
            file_version=$(echo $file | sed "s/${PKG_NAME}_\(.*\)_arm64.deb/\1/")
            if [[ $file_version < $VERSION ]]; then
                echo "Deleting older version of $PKG_FILE"
                # rm "$file"
            fi
        done

        # Construct the name of the deb package
        PKG_FILE="${pkg_name}_$VERSION_arm64.deb"

        # Check if the package has already been downloaded
        if [[ -f "$PKG_FILE" ]]; then
            echo "$PKG_FILE already exists in current directory. Skipping download."
            continue
        fi

        # Construct the download URL for the deb package
        PKG_URL="http://archive.sunrisepi.tech/ubuntu-ports/pool/main/focal/${PKG_FILE}"

        # Download the deb package
        echo "Downloading ${PKG_FILE} ..."
        if ! wget -q "$PKG_URL"; then
            echo "Error: Unable to download $pkg_name version $VERSION" >&2
            return 1
        fi
    done
}

main $@
