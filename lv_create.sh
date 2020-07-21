#!/bin/bash

OS_TYPE=$1

function lv_suse
{
	# Create LV
	lvcreate -L 20G -n oradatalv datavg
	lvcreate -L 5G -n archloglv datavg

	# Format LV
	mkfs.ext4 /dev/datavg/oradatalv
	mkfs.ext4 /dev/datavg/archloglv

	# Mount
	mount /dev/mapper/datavg-oradatalv	/oradatalv
        mount /dev/mapper/datavg-archloglv	/archloglv

	echo "/dev/mapper/datavg-oradatalv   /oradatalv		ext4	defaults	1 2" >> /etc/fstab
	echo "/dev/mapper/datavg-archloglv   /archloglv		ext4	defaults	1 2" >> /etc/fstab

	# Change ATTR
	chown -R oracle:oinstall /oradatalv
	chown -R oracle:oinstall /archloglv

}

function lv_rhel
{
	# Create LV
	lvcreate -L 20G -n oradatalv systemvg
	lvcreate -L 5G -n archloglv systemvg
	
	# Format
	mkfs.ext4 /dev/systemvg/oradatalv
	mkfs.ext4 /dev/systemvg/archloglv

	# Mount
	mount /dev/mapper/systemvg-oradatalv	/oradatalv
	mount /dev/mapper/systemvg-archloglv	/archloglv

	echo "/dev/mapper/systemvg-oradatalv	/oradatalv      ext4    defaults        1 2" >> /etc/fstab
        echo "/dev/mapper/systemvg-archloglv	/archloglv	ext4    defaults        1 2" >> /etc/fstab

	# Change ATTR
	chown -R oracle:oinstall /oradatalv
        chown -R oracle:oinstall /archloglv
}

if [[ "$OS_TYPE" == "SUSE"  ]]
then
	#
	lv_suse
elif [[ "$OS_TYPE" == "RHEL" ]]
then
	#
	lv_rhel
fi

