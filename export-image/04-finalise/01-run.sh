#!/bin/bash -e

IMG_FILE="${IMG_FILE:?"ERROR"}"
INFO_FILE="${IMG_FILE%.img}.info"
MD5_FILE="${IMG_FILE}.md5"

on_chroot << EOF
hardlink -t /usr/share/doc
echo ${BUILDHASH} > /etc/crankshaft.build
echo ${IMG_DATE} > /etc/crankshaft.date
if [ "$BUILD_RELEASE_FROM_DEV" == "1" ]; then
    echo "crankshaft-ng" > /etc/crankshaft.branch
else
    echo ${BUILDBRANCH} > /etc/crankshaft.branch
fi
EOF

if [ -d "${ROOTFS_DIR}/home/pi/.config" ]; then
	chmod 700 "${ROOTFS_DIR}/home/pi/.config"
fi

rm -f "${ROOTFS_DIR}/etc/apt/apt.conf.d/51cache"
rm -f "${ROOTFS_DIR}/usr/bin/qemu-arm-static"

rm -f "${ROOTFS_DIR}/etc/apt/sources.list~"
rm -f "${ROOTFS_DIR}/etc/apt/trusted.gpg~"

rm -f "${ROOTFS_DIR}/etc/passwd-"
rm -f "${ROOTFS_DIR}/etc/group-"
rm -f "${ROOTFS_DIR}/etc/shadow-"
rm -f "${ROOTFS_DIR}/etc/gshadow-"
rm -f "${ROOTFS_DIR}/etc/subuid-"
rm -f "${ROOTFS_DIR}/etc/subgid-"

rm -f "${ROOTFS_DIR}"/var/cache/debconf/*-old
rm -f "${ROOTFS_DIR}"/var/lib/dpkg/*-old

rm -f "${ROOTFS_DIR}"/usr/share/icons/*/icon-theme.cache

rm -f "${ROOTFS_DIR}/var/lib/dbus/machine-id"

true > "${ROOTFS_DIR}/etc/machine-id"

ln -nsf /proc/mounts "${ROOTFS_DIR}/etc/mtab"

find "${ROOTFS_DIR}/var/log/" -type f -exec cp /dev/null {} \;

rm -f "${ROOTFS_DIR}/root/.vnc/private.key"
rm -f "${ROOTFS_DIR}/etc/vnc/updateid"

update_issue "$(basename "${EXPORT_DIR}")"
install -m 644 "${ROOTFS_DIR}/etc/rpi-issue" "${ROOTFS_DIR}/boot/issue.txt"
install files/LICENSE.oracle "${ROOTFS_DIR}/boot/"


cp "$ROOTFS_DIR/etc/rpi-issue" "$INFO_FILE"

{
	firmware=$(zgrep "firmware as of" \
		"$ROOTFS_DIR/usr/share/doc/raspberrypi-kernel/changelog.Debian.gz" | \
		head -n1 | sed  -n 's|.* \([^ ]*\)$|\1|p')
	printf "\nFirmware: https://github.com/raspberrypi/firmware/tree/%s\n" "$firmware"

	kernel="$(curl -s -L "https://github.com/raspberrypi/firmware/raw/$firmware/extra/git_hash")"
	printf "Kernel: https://github.com/raspberrypi/linux/tree/%s\n" "$kernel"

	uname="$(curl -s -L "https://github.com/raspberrypi/firmware/raw/$firmware/extra/uname_string7")"

	printf "Uname string: %s\n" "$uname"
	printf "\nPackages:\n"
	dpkg -l --root "$ROOTFS_DIR"
} >> "$INFO_FILE"


ROOT_DEV="$(mount | grep "${ROOTFS_DIR} " | cut -f1 -d' ')"

unmount "${ROOTFS_DIR}"
zerofree -v "${ROOT_DEV}"

unmount_image "${IMG_FILE}"

mkdir -p "${DEPLOY_DIR}"

rm -f "${DEPLOY_DIR}/${IMG_FILENAME}${IMG_SUFFIX}.zip"

pushd "${STAGE_WORK_DIR}" > /dev/null
md5sum "$(basename "${IMG_FILE}")" > "$(basename "${MD5_FILE}")"
zip "${DEPLOY_DIR}/${IMG_FILENAME}${IMG_SUFFIX}.zip" \
        "$(basename "${IMG_FILE}")" \
        "$(basename "${MD5_FILE}")"
popd > /dev/null

cp "$INFO_FILE" "$DEPLOY_DIR"
