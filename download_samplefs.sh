#!/bin/bash
###
 # COPYRIGHT NOTICE
 # Copyright 2023 Horizon Robotics, Inc.
 # All rights reserved.
 # @Date: 2023-03-24 21:02:31
 # @LastEditTime: 2023-05-15 14:35:12
### 

set -e

main()
{
    rootfs_dir="$1"
    [ ! -z ${rootfs_dir} ] && [ ! -d ${rootfs_dir} ] && mkdir ${rootfs_dir}
    cd ${rootfs_dir}

    # Set the URL of the file server
    SERVER_URL="http://sunrise.horizon.cc/samplefs"

    # Set the name of the file that records the latest version information
    VERSION_FILE="samplefs_desktop_latest.txt"
    if [[ $# -eq 2 && "$2" = "server" ]]; then
        VERSION_FILE="samplefs_server_latest.txt"
    fi

    # Download the version information file
    if curl -fs -O --connect-timeout 5 "${SERVER_URL}/${VERSION_FILE}"; then
        echo "File ${VERSION_FILE} downloaded successfully"
    else
        echo "File ${VERSION_FILE} downloaded failed"
    return -1
    fi

    # Extract the list of files to download from the version information file
    FILE_LIST=$(cat "$VERSION_FILE" | grep -v "^#")

    # Loop through each file and download it
    for FILE in $FILE_LIST; do
        # Extract the file name, version number, and extension
        FILE_NAME=$(echo "$FILE" | cut -d "-" -f1)

        # Check if the file has already been downloaded
        if [[ -f "${FILE}" ]]; then
            echo "File ${FILE} already exists, skipping download"
            continue
        fi

        # Download the md5sum file for the file
        if curl -fs -O --connect-timeout 5 "${SERVER_URL}/${FILE_NAME}/${FILE_NAME}.md5sum"; then
            echo "File ${FILE_NAME}.md5sum downloaded successfully"
        else
            echo "File ${FILE_NAME}.md5sum downloaded failed"
            return -1
        fi

        # Extract the file name and md5sum value from the md5sum file
        FILE_MD5SUM=$(cat "${FILE_NAME}.md5sum" | grep ${FILE_NAME} | cut -d " " -f1)

        # Download the file
        echo "Downloading ${FILE} ..."
        if curl -f -O --connect-timeout 5 "${SERVER_URL}/${FILE_NAME}/${FILE}"; then
            echo "File ${FILE} downloaded successfully"
        else
            echo "File ${FILE} downloaded failed"
            rm -f ${FILE}
            return -1
        fi

        # Calculate the md5sum of the downloaded file
        DOWNLOADED_MD5SUM=$(md5sum "${FILE}" | awk '{print $1}')

        # Verify the md5sum value of the downloaded file
        if [[ "${FILE_MD5SUM}" == "${DOWNLOADED_MD5SUM}" ]]; then
            echo "File ${FILE} verify successfully"
        else
            echo "File ${FILE} verify md5sum failed, Expected to be ${FILE_MD5SUM}, actually ${DOWNLOADED_MD5SUM}"
            rm ${FILE}
            return -1
        fi
    done

    return 0
}

main $@
