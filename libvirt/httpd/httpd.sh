#!/bin/bash
TARGET_PORT=8080

dnf install httpd -y
sed -i "s/Listen 80$/Listen ${TARGET_PORT}/" /etc/httpd/conf/httpd.conf 
service httpd start
virsh -c qemu+tcp:///system pool-define-as --name httpd --type dir --target /var/www/html
virsh -c qemu+tcp:///system pool-autostart httpd
virsh -c qemu+tcp:///system pool-start httpd

firewall-cmd --zone libvirt --add-port ${TARGET_PORT}/tcp --permanent
firewall-cmd --reload

