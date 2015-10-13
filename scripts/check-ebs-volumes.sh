#!/bin/bash
# 
# Russell Simpkins <russell.simpkins@nytimes.com 
# 
# A very simple script that looks at the avialable disks NOT mounted to / 
# AND formats them using ext4 if they are NOT formatted 
# AND adds a mount point to /etc/fstab for /var/nyt 
# AND runs mount -u 
# 
# I could do more, but this was all I needed 
# 

# logic to check all devices not on / 
for e in $(lsblk |awk '$1 ~/xv/ && $7 != "/" {print $1}'); do

    # file -s /dev/device will print "data" if it's not formatted 
    format=$(file -s /dev/$e |awk '{print $2}')
    if [ "data" == "${format}" ]; then
        echo mkfs -t ext4 /dev/$e
        mkfs -t ext4 /dev/$e
    else
        echo "/dev/$e formatted"
    fi

    # check if it's mounted 
    mounted=$(mount|grep -c "/dev/$e")
    if [ "$mounted" == "1" ]; then
        echo "/dev/$e is mounted"
    else
        # add an entry to /etc/fstab and mount that sucka 
        echo "/dev/$e is not mounted"
        echo "/dev/$e   /var/nyt        ext4    defaults,noatime        1       0" >> /etc/fstab
        if [ ! -d /var/nyt ]; then
            mkdir /var/nyt
        fi
        /bin/mount -a
        echo "/dev/$e is mounted (hopefully)"
    fi
done
