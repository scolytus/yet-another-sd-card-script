#!/bin/bash

################################################################################
# This is yet another SD card creation script.
#
# You better don't use it as is!
#
# (C) 2014 Michael Gissing
#
################################################################################

#set -e
#set -x

# ------------------------------------------------------------------------------
CARD=/dev/sdb

UBOOT="u-boot-sunxi-with-spl-ct-20140107.bin"
#BOOTFS_TAR="bootfs-part1.tar.gz"
#ROOTFS_TAR="rootfs-part2.tar.gz"

BOOTFS_TAR="ct-lubuntu-card0-v1.03/EN/bootfs-part1.tar.gz"
ROOTFS_TAR="ct-lubuntu-card0-v1.03/EN/rootfs-part2.tar.gz"

LOG="./create.log"

# ------------------------------------------------------------------------------
fail() {
  echo "[ERROR][$(timestamp)] ${1}" | tee -a "${LOG}"
  exit 255
}

info() {
  echo "[INFO ][$(timestamp)] ${1}" | tee -a "${LOG}"
}

timestamp() {
  echo $(date +%Y%m%d-%H%M%S)
}

check_file_fail() {
  [ -f "${1}" ] || fail "can't find file ${1}"
}

mount_write_fs_image() {
  local mount_point=$(mktemp -d)

  mount "${1}" "${mount_point}" || fail "can not mount ${1}"

  pushd "${mount_point}" &> /dev/null
  tar xzf "${2}" || fail "error while extracting ${2}"
  popd &> /dev/null

  sync && sync && sync

  umount "${mount_point}"
  mountpoint -q "${mount_point}" && fail "can not unmount ${mount_point}"
  mountpoint -q "${mount_point}" || rm -rf "${mount_point}"
}

# ------------------------------------------------------------------------------
WD="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
IMG_DIR="${WD}/images"

UBOOT_PATH="${IMG_DIR}/${UBOOT}"
BOOTFS_TAR_PATH="${IMG_DIR}/${BOOTFS_TAR}"
ROOTFS_TAR_PATH="${IMG_DIR}/${ROOTFS_TAR}"

# ------------------------------------------------------------------------------
[ "0" = $EUID ]  || fail "has to be root"
[ -b "${CARD}" ] || fail "not a block device '${CARD}'"

check_file_fail "${UBOOT_PATH}"
check_file_fail "${BOOTFS_TAR_PATH}"
check_file_fail "${ROOTFS_TAR_PATH}"

# ------------------------------------------------------------------------------
info "cleaning first 100M of card"
dd if=/dev/zero of="${CARD}" bs=100M count=1 &>> "${LOG}"
sync

info "write UBoot"
dd if="${UBOOT_PATH}" of="${CARD}" bs=1024 seek=8 &>> "${LOG}"
sync

info "create partition table"
echo -e "o\nn\np\n1\n2048\n+64M\nn\np\n2\n\n\np\nw\n" | fdisk "${CARD}" &>> "${LOG}"

info "sync partition table"
partprobe "${CARD}" &>> "${LOG}"

info "create ext2 fs on boot partition"
$sudo mkfs.ext2 "${CARD}"1 &>> "${LOG}"

info "create ext4 fs on root partition"
$sudo mkfs.ext4 "${CARD}"2 &>> "${LOG}"

info "mount and write boot partition"
mount_write_fs_image "${CARD}"1 "${BOOTFS_TAR_PATH}"

info "mount and write root partition"
mount_write_fs_image "${CARD}"2 "${ROOTFS_TAR_PATH}"

info "DONE"

