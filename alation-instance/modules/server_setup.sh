#!/bin/bash

sleep 20
echo "Check if disk is created and Find the disk name"
create=false
while [ "$created" == "false" ]
do
  echo "data device not created"
  lsblk|grep 80 && create=true
  sleep 2
done
datadisk_name=`lsblk |grep 80 |awk '{print $1}'`
create=false
while [ "$created" == "false" ]
do
  echo "backup device not created"
  lsblk|grep 140 && create=true
  sleep 2
done
backupdisk_name=`lsblk |grep 140 |awk '{print $1}'`
echo
echo "data device is /dev/$datadisk_name"
echo "backup devide is /dev/$backupdisk_name"
echo
echo
echo "create filesystem on disks"
if [ -z "$(sudo blkid -s UUID -o value /dev/$datadisk_name)" ]; then
  sudo mkfs -t xfs /dev/$datadisk_name
else
  echo "fs on data created already"
fi
echo
echo "create backup filesystem"
if [ -z "$(sudo blkid -s UUID -o value /dev/$backupdisk_name)" ]; then
  sudo mkfs -t xfs /dev/$backupdisk_name
else
  echo "fs on backup created already"
fi
echo
echo "Create directories"
sudo mkdir -p /data /backup

echo "Get UUID for both volumes"
DATA_UUID=`lsblk -b -io UUID /dev/$datadisk_name|tail -1`
BACKUP_UUID=`lsblk -b -io UUID /dev/$backupdisk_name|tail -1`

echo "Add UUID to fstab"
grep $DATA_UUID /etc/fstab || echo "UUID=$DATA_UUID /data xfs defaults 0 0"| sudo tee -a /etc/fstab
grep $BACKUP_UUID /etc/fstab || echo "UUID=$BACKUP_UUID /backup xfs defaults 0 0"| sudo tee -a /etc/fstab
echo "Mount volumes"
sudo mount -a
