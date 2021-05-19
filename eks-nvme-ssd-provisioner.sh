#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

mapfile -t SSD_NVME_DEVICE_LIST < <(nvme list | grep "Amazon EC2 NVMe Instance Storage" | cut -d " " -f 1 || true)
SSD_NVME_DEVICE_COUNT=${#SSD_NVME_DEVICE_LIST[@]}
RAID_DEVICE=${RAID_DEVICE:-/dev/md0}
RAID_CHUNK_SIZE=${RAID_CHUNK_SIZE:-512}  # Kilo Bytes
FILESYSTEM_BLOCK_SIZE=${FILESYSTEM_BLOCK_SIZE:-4096}  # Bytes
STRIDE=$((RAID_CHUNK_SIZE * 1024 / FILESYSTEM_BLOCK_SIZE))
STRIPE_WIDTH=$((SSD_NVME_DEVICE_COUNT * STRIDE))

# Checking if provisioning already happend
if [[ "$(ls -A /pv-disks)" ]]
then
  echo 'Volumes already present in "/pv-disks"'
  echo -e "\n$(ls -Al /pv-disks | tail -n +2)\n"
  echo "I assume that provisioning already happend, trying to assemble and mount!"
  case $SSD_NVME_DEVICE_COUNT in
  "0")
    exit 1
    ;;
  "1")
    echo "no need to assable a raid"
    DEVICE="${SSD_NVME_DEVICE_LIST[0]}"
    ;;
  *)
    # check if raid has already been started and is clean, if not try to assemble
    mdadm --detail "$RAID_DEVICE" 2>/dev/null | grep clean >/dev/null || mdadm --assemble "$RAID_DEVICE" "${SSD_NVME_DEVICE_LIST[@]}"
    # print details to log
    mdadm --detail "$RAID_DEVICE"
    DEVICE=$RAID_DEVICE
    ;;
  esac
  UUID=$(blkid -s UUID -o value "$DEVICE")
  if mount | grep "$DEVICE" > /dev/null; then
    echo "device $DEVICE appears to be mounted already"
  else
    mount -o defaults,noatime,discard,nobarrier --uuid "$UUID" "/pv-disks/$UUID"
  fi
  ln -s "/pv-disks/$UUID" /nvme/disk || true
  echo "Device $DEVICE has been mounted to /pv-disks/$UUID"
  while sleep 3600; do :; done
fi

# Perform provisioning based on nvme device count
case $SSD_NVME_DEVICE_COUNT in
"0")
  echo 'No devices found of type "Amazon EC2 NVMe Instance Storage"'
  echo "Maybe your node selectors are not set correct"
  exit 1
  ;;
"1")
  mkfs.ext4 -m 0 -b "$FILESYSTEM_BLOCK_SIZE" "${SSD_NVME_DEVICE_LIST[0]}"
  DEVICE="${SSD_NVME_DEVICE_LIST[0]}"
  ;;
*)
  mdadm --create --verbose "$RAID_DEVICE" --level=0 -c "${RAID_CHUNK_SIZE}" \
    --raid-devices=${#SSD_NVME_DEVICE_LIST[@]} "${SSD_NVME_DEVICE_LIST[@]}"
  while [ -n "$(mdadm --detail "$RAID_DEVICE" | grep -ioE 'State :.*resyncing')" ]; do
    echo "Raid is resyncing.."
    sleep 1
  done
  echo "Raid0 device $RAID_DEVICE has been created with disks ${SSD_NVME_DEVICE_LIST[*]}"
  mkfs.ext4 -m 0 -b "$FILESYSTEM_BLOCK_SIZE" -E "stride=$STRIDE,stripe-width=$STRIPE_WIDTH" "$RAID_DEVICE"
  DEVICE=$RAID_DEVICE
  ;;
esac

UUID=$(blkid -s UUID -o value "$DEVICE")
mkdir -p "/pv-disks/$UUID"
mount -o defaults,noatime,discard,nobarrier --uuid "$UUID" "/pv-disks/$UUID"
ln -s "/pv-disks/$UUID" /nvme/disk
echo "Device $DEVICE has been mounted to /pv-disks/$UUID"
echo "NVMe SSD provisioning is done and I will go to sleep now"

while sleep 3600; do :; done
