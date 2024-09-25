#!/bin/bash
firewall-cmd --zone=libvirt --add-service=ntp --permanent
firewall-cmd --reload

