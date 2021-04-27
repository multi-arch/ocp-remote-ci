#!/usr/bin/env bash
set -xeu

if ! sudo ls / > /dev/null 2>&1;
then
	echo "ERROR: passwordless sudo required!"
	exit 1
fi

if [[ -z "$(hostname)" ]]
then
	echo "ERROR: the hostname command must resolve to a name!"
	exit 1
fi

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "${SCRIPT_DIR}"

sudo systemctl stop apici.service
sudo systemctl daemon-reload
sudo systemctl start apici.service
sudo systemctl status apici.service

sudo /bin/cp ./libvirt/haproxy/haproxy_$(hostname).cfg /etc/haproxy/haproxy.cfg
sudo systemctl restart haproxy.service
sudo systemctl status haproxy.service
