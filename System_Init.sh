#!/bin/bash
####################################################
###
### Copyright (2020, ) Gemini.Chen
###
### Author: gemini_chen@163.com
### Date  : 2020/07/16
### Scene : KSNS
###
######################################################

username=$1
uid=$2
if [[ ! -n $username ]] || [[ ! -n $uid ]];then
	echo "Invalid Option, Please Double Confirm!"
	exit 1
fi

# Add Nee User Action
function add_user
{
        user_name=$1
        group_name=$1
	user_password=$1
        user_id=$2
        group_id=$2

        # groupname gid
        groupadd -g $group_id $group_name
        if [[ $? -eq 0 ]];then
                # username uid = gid
                useradd -u $user_id $user_name -g $group_name
                if [[ $? -eq 0 ]];then
                        # username = groupname = password
                        echo $user_password | passwd --stdin $user_name
                        if [[ $? -eq 0 ]];then
                                echo "User Add Action : PASS"
                        fi
                fi
        fi
}

# Get The Existing VG Name
vg_name=$(pvs| sed -n '2p'| awk {'print $2'})

# Get The Free Disks
disk_name_pool=$(lsblk -ml | grep -v 'floppy\|fd\|sr' | grep -v 'cdrom\|NAME'| grep -v 'lv\|rhel\|centos' | grep -v 'dm'| awk {'print $1'}| cut -c 1-3| uniq)

# Disk Active Workflow
function disk_active
{
      disk_name=$1
      # OS Type Check
      if [[ -f /etc/redhat-release ]];then
              #echo "RHEL Situation"
              # Format The Disk(0/1)
              echo "n
              p
              1


              t
              8e
              w" | fdisk /dev/$disk_name &>/dev/null
              # Format The Disk(1/1)
              if [[ $? -eq 0 ]];then
                      mkfs -t ext4  /dev/"$disk_name"1 &>/dev/null
              fi
      elif [[ -f /etc/SuSE-release ]];then
              #echo "SuSE Situation"
              # Format The Disk(0/1)
              echo "n
              p
              1


              t
              8e
              w" | fdisk /dev/$disk_name &>/dev/null
              #
              disk_fdisk_stat=$?
              if [[ $disk_fdisk_stat -eq 0 ]];then
                      #"SuSE Disk Partition Action [PASS]!\n"
                      # Wait For 5 Seconds
                      sleep 10
                      # Format The Disk(1/1)
                      mkfs -t ext3  /dev/"$disk_name"1
              else
                      #echo -e "SuSE Disk Partition Action [ERROR]!\n"
                      error_info="SuSE Disk Partition Action [ERROR]!"
                      echo $error_info
              fi

      fi

      # Add To The Exist VG
      if [[ $? -eq 0 ]];then
              # Expand The VG
              echo 'y' | vgextend $vg_name /dev/"$disk_name"1
      fi

}
function vg_expand
{
      for disk_index in $disk_name_pool
      do
        parted /dev/$disk_index print | grep 'File system' &> /dev/null
        if [[ $? -ne 0 ]];then
                # unused disk
                echo "$disk_index is OK For Add To Existing VG..."
                # Add Disk
                disk_active $disk_index
        fi

      done

}


# Main Function
function __main__
{
        # user add
        add_user $username $uid

        # disk expand
	vg_expand

}

# Start Trigg#er
__main__ $1 $2
