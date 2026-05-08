#!/bin/sh

ARTIFACTS="./artifacts"
TFTP_DIR="/srv/tftp"
OWNER="tftp"
GROUP="tftp"

FILES="
ts209/uImage
ts209/orion5x-qnap-ts209pro2.dtb
uInitrd
"

echo "Deploying boot artifacts to ${TFTP_DIR}"

if [ ! -d "${TFTP_DIR}" ]; then
    echo "Error: TFTP directory ${TFTP_DIR} does not exist"
    exit 1
fi

for f in $FILES; do
    SRC="${ARTIFACTS}/${f}"
    DST="${TFTP_DIR}/${f}"

    if [ ! -f "${SRC}" ]; then
        echo "Warning: ${SRC} not found, skipping"
        continue
    fi

    echo "Copying ${f}..."
    cp "${SRC}" "${DST}"

    echo "Setting ownership to ${OWNER}:${GROUP}"
    chown ${OWNER}:${GROUP} "${DST}"

    echo "Setting permissions to 644"
    chmod 644 "${DST}"
done

echo "Deployment complete."
echo "TS-209 Pro II u-boot console commands"
echo "tftpboot 0x800000 uImage\ntftpboot 0x1100000 uInitrd\nbootm 0x800000 0x1100000"
