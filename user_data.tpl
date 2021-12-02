#!/bin/bash
mkdir /tmp/data
cd /tmp/data
setenforce 0 
yum install httpd -y
${iso_download_cmd}
yum install httpd -y
mount /tmp/data/*.iso /mnt
cp -rf /mnt/* /var/www/html
cd /var/www/html/
service httpd start
cp /var/www/html/images/ignition.img /var/www/html/images/ignition.gz
gunzip /var/www/html/images/ignition.gz
cpio -idv -F /var/www/html/images/ignition
firewall-cmd --zone=public --permanent --add-service=http
firewall-cmd --reload
