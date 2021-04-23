#!/usr/bin/env bash
set -xeu

if [[ ! -v TOKEN ]]
then
	echo "ERROR: TOKEN environment variable must be set!"
	exit 1
fi
if [[ -z "${TOKEN}" ]]
then
	echo "ERROR: TOKEN environment variable must have a value!"
	exit 1
fi
if ! hash git;
then
	echo "ERROR: git must be installed!"
	exit 1
fi
if [[ -z "$(hostname)" ]]
then
	echo "ERROR: the hostname command must resolve to a name!"
	exit 1
fi

if ! sudo ls / > /dev/null 2>&1;
then
	echo "ERROR: passwordless sudo required!"
	exit 1
fi

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
OLD_SCRIPT_SHA1SUM=$(sha1sum /home/ocp/ocp-remote-ci/install-ci.sh | awk '{print $1}')

if [[ ! -d "${SCRIPT_DIR}" ]]
then
	echo "ERROR: Directory ${SCRIPT_DIR} doesn't exist!"
	exit 1
fi

cd "${SCRIPT_DIR}"

git reset --hard HEAD
git clean -fxd .
git checkout master
git pull

NEW_SCRIPT_SHA1SUM=$(sha1sum /home/ocp/ocp-remote-ci/install-ci.sh | awk '{print $1}')

if [[ "${OLD_SCRIPT_SHA1SUM}" != "${NEW_SCRIPT_SHA1SUM}" ]]
then
	echo "ERROR: install-ci.sh has changed upstream, rerun to reload the script!"
	exit 1
fi

sed -i -e 's,token: ".*$,token: "'${TOKEN}'",' ./libvirt/tunnel/profile_$(hostname).yaml

if ! sudo diff ./libvirt/tunnel/apici.service /usr/lib/systemd/system/apici.service;
then
	sudo systemctl stop apici.service
	sudo install --owner=root --group=root --mode=0644 ./libvirt/tunnel/apici.service /usr/lib/systemd/system/
	sudo systemctl daemon-reload
	sudo systemctl start apici.service
	sudo systemctl status apici.service
fi

if ! sudo diff ./libvirt/haproxy/haproxy_$(hostname).cfg /etc/haproxy/haproxy.cfg;
then
	sudo /bin/cp ./libvirt/haproxy/haproxy_$(hostname).cfg /etc/haproxy/haproxy.cfg
	sudo systemctl restart haproxy.service
	sudo systemctl status haproxy.service
fi
