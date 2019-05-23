#!/bin/bash
set -o errexit
######################################################
################## TODO: settings#####################
src_root_device=/dev/root
src_boot_device=/dev/mmcblk0p1
######################################################

green="\e[32;1m"
normal="\e[0m"

echo -e "${green} \n安装必备软件\n ${normal}"
sudo apt-get install -y dosfstools dump parted kpartx bc
echo -e "${green} \n软件安装完成\n ${normal}"

echo -e "${green}开始创建镜像...\n ${normal}"
used_size=`df -P | grep $src_root_device | awk '{print $3}'`
boot_size=`df -P | grep $src_boot_device | awk '{print $2}'`
if [ "x${used_size}" != "x" ] && [ "x${boot_size}" != "x" ];then
	count=`echo "${used_size}*1.1+${boot_size}+2"|bc|awk '{printf("%.0f",$1)}'`
else
	echo "device $src_root_device or $src_boot_device not exist,mount first"
	exit 0;
fi
echo boot分区大小:$boot_size,已使用空间:$used_size,剩余空间: $count
echo $(($boot_size/1024+1))
sudo dd if=/dev/zero of=backup.img bs=1k count=$count
sudo parted backup.img --script -- mklabel msdos
sudo parted backup.img --script -- mkpart primary fat32 1M $(($boot_size/1024+1))M #(nByte/512)s
sudo parted backup.img --script -- mkpart primary ext4 $(($boot_size/1024+1))M -1

echo -e "${green}挂载loop设备并将文件复制到映像\n${normal}"
loopdevice=`sudo losetup --show -f backup.img`
echo $loopdevice
device=`sudo kpartx -va $loopdevice`
echo $device
device=`echo $device | sed -E 's/.*(loop[0-9]*)p.*/\1/g' | head -1`
# device=`echo $device |awk '{print $3}' | head -1`
echo $device
device="/dev/mapper/${device}"
boot_device="${device}p1"
root_device="${device}p2"
sleep 2
sudo mkfs.vfat $boot_device
sudo mkfs.ext4 $root_device
sudo mkdir -p /media/img_to
sudo mkdir /media/img_src
mount_path=`df -h|grep ${src_boot_device}|awk '{print $6}'`
if [ "x${mount_path}" == "x" ];then
  sudo mount -t vfat $src_boot_device /media/img_src
  mount_path=/media/img_src
fi
sudo mount -t vfat $boot_device /media/img_to
echo -e "${green}复制 /boot${normal}"
sudo cp -rfp ${mount_path}/* /media/img_to
sudo umount /media/img_to

sudo chattr +d backup.img #exclude img file from backup(support in ext* file system)
echo "如果出现 'Operation not supported while reading flags on backup.img' 请忽略它"

mount_path=`df -h|grep ${src_root_device}|awk '{print $6}'`
echo root mount path: $mount_path
if [ "x${mount_path}" == "x" ];then
  sudo mount -t ext4 $src_root_device /media/img_src
  mount_path=/media/img_src
fi
sudo mount -t ext4 $root_device /media/img_to

cd /media/img_to
echo -e "${green}复制./根目录${normal}"
sudo dump -0auf - ${mount_path} | sudo restore -rf -
cd
sudo umount /media/img_to

sudo kpartx -d $loopdevice
sudo losetup -d $loopdevice
sudo rm /media/img_to /media/img_src -rf

echo -e "${green}\n备份完成\n${normal}"