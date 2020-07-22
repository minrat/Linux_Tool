#!/bin/bash
####################################################
###
### Copyright (2020, ) Gemini.Chen
###
### Author: gemini_chen@163.com
### Date  : 2020/03/19
### Scene : KSNS
###
######################################################

# Parameter Setting
target_path=$1
target_capacity=$2

# Path Check
path_flag=false
lv_paths=$(lvs | awk {'print $1'} | grep -v LV)
for i in  $lv_paths
do
	if [[ $i == $target_path"lv" ]];then
	        path_flag=true
	fi
done


# Get The Existing VG Name
vg_name=$(pvs| sed -n '2p'| awk {'print $2'})

# Get The Latest Disk
# Disk Name(0/1)
disk_name_total=$(lsblk -ml | grep -v floppy | grep -v cdrom| grep -v lv | grep -v dm| tail -n 1| awk {'print $1'})
# Disk Expand Task Flag
task_disk_expand_flag=1

# Disk Flag(1/1)
disk_used_flag=1
disk_name_unit=${disk_name_total:0-1}
units="1234567890"
if [[ $units == *$disk_name_unit* ]];then
	# Disk Not Ready
	disk_used_flag=1
else
	# Disk Flag(1/1)
	disk_format_stat=$(parted /dev/$disk_name_total print | grep unrecognised >/dev/null)
	if [[ $disk_format_stat -eq 0 ]];then
	        # unused disk
	        disk_used_flag=0
	fi

	# Disk Ready
	disk_name=$disk_name_total
	
	# Disk Type(1/1)
	disk_type=$(lsblk -ml | grep -v floppy | grep -v cdrom | grep -v lv | grep -v dm | tail -n 1| awk {'print $(NF-1)'})
	if [[ $disk_type == "disk" ]];then
		disk_type_capacity_total=$(lsblk -ml | grep -v floppy | grep -v cdrom| grep -v dm | tail -n 1| awk {'print $2'})
		disk_type_capacity_count=$(echo $disk_type_capacity_total| sed 's/.$//')
		disk_type_capacity_unit=${disk_type_capacity_total:0-1}
		if [[ $disk_type_capacity_unit == "t" ]] || [[ $disk_type_capacity_unit == "T" ]];then
			# T
			disk_type_capacity=$(($disk_type_capacity_count*1024))
		elif [[ $disk_type_capacity_unit == "g" ]] || [[ $disk_type_capacity_unit == "G" ]];then
			# G
			disk_type_capacity=$disk_type_capacity_count
		elif [[ $disk_type_capacity_unit == "m" ]] || [[ $disk_type_capacity_unit == "M" ]];then
			# M
			if [ $disk_type_capacity_count -lt 1024 ];then
				disk_type_capacity=0
			else
				disk_type_capacity=$(($disk_type_capacity_count/1024))
			fi
		elif [[ $disk_type_capacity_unit == "k" ]] || [[ $disk_type_capacity_unit == "K" ]];then
			# K
			disk_type_capacity=0
		fi
	else
		disk_flag=1
	fi
fi

# Capacity Verify Workflow
function capacity_verify
{
	# Existing Free Capacity(float situation)
	free_pvs_result_list=$(pvs| awk '{print $NF}'| grep -v PFree)
	free_pvs_capacity=0
	for pv in $free_pvs_result_list
	do
		# Remove "<" 
		free_pvs_capacity_count_pre=$(echo $pv | sed 's/<//g')
		free_pvs_capacity_count=$(echo $free_pvs_capacity_count_pre | awk -F "." {'print $1'}| sed 's/<//g')

		# Get The Unit
		if [[ "$pv" == "0" ]];then
			free_pvs_capacity_unit=0
		else
			free_pvs_capacity_unit=${pv:0-1}
		fi
		
		if [[ $free_pvs_capacity_unit == "T" ]] || [[ $free_pvs_capacity_unit == "t" ]];then
			# t
			free_pvs_capacity_tmp=$(($free_pvs_capacity_count*1024))
		elif [[ $free_pvs_capacity_unit == "G" ]] || [[ $free_pvs_capacity_unit == "g" ]];then
			# g
			free_pvs_capacity_tmp=$free_pvs_capacity_count
			

		elif [[ $free_pvs_capacity_unit == "M" ]] || [[ $free_pvs_capacity_unit == "m" ]];then
			# m
			if [ $free_pvs_capacity_count -ge 1024 ];then
		        	free_pvs_capacity_tmp=$(($free_pvs_capacity_count/1024))
			else
				free_pvs_capacity_tmp=0
			fi
		fi
		# sum
		let free_pvs_capacity=$((free_pvs_capacity+free_pvs_capacity_tmp))
	done
	
	# Verify
	if [[ ! -n "$free_pvs_capacity" ]] && [ $disk_type_capacity_count -eq 0 ];then
		#"No Free Capacity, Need Add A New Disk! Please Double Confirm This. Detail Information As Following [Situation-1]:"
		task_disk_expand_flag=1
		echo "diskSize: "$free_pvs_capacity "G"
		echo "diskSizeCheck: true"
                echo "diskPathCheck: "$path_flag

	elif [[ $free_pvs_capacity -gt 0 ]] && [[ $target_capacity -gt $free_pvs_capacity ]];then
		# Enable Added Disk Active(Handle The Part Space)
                if [[ -f /etc/SuSE-release ]];then
			#echo "SuSE Disk Active[0]"
                        echo "- - -" > /sys/class/scsi_host/host0/scan
                        echo "- - -" > /sys/class/scsi_host/host1/scan
                        echo "- - -" > /sys/class/scsi_host/host2/scan
		fi
		# Disk Capacity Verify
		if [[ $disk_type == "disk" ]] && [[ $free_pvs_capacity -lt $target_capacity ]] && [[ $disk_used_flag -eq 0 ]] && [[ $((disk_type_capacity+free_pvs_capacity)) -ge $target_capacity ]] && [[ $disk_used_flag -eq 0 ]];then
			# Active New Disk (Here Will Cover Disk + Existing Space)
			echo "diskSizeCheck: false"
			echo "diskSize: "$((disk_type_capacity+free_pvs_capacity)) "G"
			disk_active
		else
			error_info="Existing Capacity (Free + Disk) Do Not Match, Need Add A New Disk! Detail Refer To [Situation-3]:"
			echo "diskSizeCheck: true"
			echo "diskSize: "$((disk_type_capacity+free_pvs_capacity)) "G"
		fi
	elif [[ $free_pvs_capacity -gt 0 ]] && [[ $target_capacity -le $free_pvs_capacity ]]  && [[ $disk_used_flag -eq 1 ]] ;then
		#" Expand The Existing Capacity Directly! [Situation-4]\n"
		echo "diskSizeCheck: false"
		echo "diskSize: "$free_pvs_capacity"G"
		lvextend -L +"$target_capacity"G /dev/$vg_name/"$target_path"lv &> /dev/null
                if [[ $? -eq 0 ]];then
			echo "diskPathCheck: "$path_flag
                        resize2fs /dev/$vg_name/"$target_path"lv &> /dev/null
                        if [[ $? -eq 0 ]];then
                                # Succeed
				task_disk_expand_flag=0
			else
				task_disk_expand_flag=1
                        fi
		else
			task_disk_expand_flag=1
			echo "diskPathCheck: "$path_flag
		fi
	else
		#Active The New Added Disk
		if [[ $disk_used_flag -eq 0 ]];then
			# Active Disk
                	disk_active
		else
			# Disk Active Error
			echo "diskSizeCheck: true"
			echo "diskSize: "$free_pvs_capacity"G"
			echo "diskPathCheck: "$path_flag
			
		fi
	fi
}

# Disk Active Workflow
function disk_active
{
	#echo -e "Add Disk && Active Start \n"
	# Here Need Disk Type Verify
	if [[ "$disk_type" != "disk" ]] || [[ $disk_flag -eq 1 ]];then
		error_info="Disk Not Adding Ready, Please Double Confirm !"
        	echo $(eval echo '{ \"ERROR\":\""$error_info"\"}') | python -m json.tool
		#exit 0
	elif [[ "$disk_type" == "disk" ]] && [[ $disk_flag -eq 0 ]];then
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
				echo $(eval echo '{ \"ERROR\":\""$error_info"\"}') | python -m json.tool
                        fi

        	fi
		
		if [[ $? -eq 0 ]];then
			# Expand The VG
        		echo 'y' | vgextend $vg_name /dev/"$disk_name"1
			if [[ $? -eq 0 ]];then
				# Expand LV(Here Will Cover Disk + Existing Space)
				lvextend -L +"$target_capacity"G /dev/$vg_name/"$target_path"lv &>/dev/null
				if [[ $? -eq 0 ]];then
					echo "diskPathCheck: "$path_flag
					# Resize
					resize2fs /dev/$vg_name/"$target_path"lv &>/dev/null
					if [[ $? -eq 0 ]];then
						# mark the task succeed
						task_disk_expand_flag=0
					fi
				else
					task_disk_expand_flag=1
					echo "diskPathCheck: "$path_flag
				fi
			else
				task_disk_expand_flag=1
			fi
		else
			task_disk_expand_flag=1
		fi
	fi	
	
}

# Main Function
function __main__
{
	# Parameter Verify(0/1)
	path=$target_path
	capacity=$target_capacity

	# Parameter Verify(1/1)
	if [[ ! -n "$path" ]] || [[ ! -n "$capacity" ]]; then
		error_info="Invalid Parameter, Please Double Confirm!"
		echo $(eval echo '{ \"ERROR\":\""$error_info"\"}') | python -m json.tool
	else
		# Start Capacity Check
		capacity_verify 
		if [[ $? -eq 0 ]] && [[ $task_disk_expand_flag -eq 0 ]];then
			# "Disk Expand Action Status : [Succeed]"
			echo "diskChangeCheck: true"
		else
			#"Disk Expand Action Status : [FAIL]"
			echo "diskChangeCheck: false"
		fi
	fi
}

# Start Trigger
__main__ $target_path $target_capacity
