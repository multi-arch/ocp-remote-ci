#!/bin/bash

set -o nounset
set -o pipefail
set -o errexit


token=""
environment="ppc64le-libvirt"

if [[ -z "${token:-}" ]]; then
  echo "[ERROR] \$token must be passed."
  exit 1
fi

function OC() {
	./oc --server https://api.ci.openshift.org --token "${token}" --namespace "bastion-${environment}" { "${@}"
}

function port-forward() {
	while true; do
		echo "[INFO] Setting up port-forwarding..."
		pod="$( OC get pods --selector component=sshd -o jsonpath={.items[0].metadata.name} )"
		if ! OC port-forward "${pod}" 2222; then
			echo "[WARNING] Port-forwarding failed, retrying..."
			sleep 0.1
		fi
	done
}

function ssh-tunnel() {
	while true; do
		echo "[INFO] Setting up SSH tunnelling..."
		if ! ssh -N -T \
		   -R 8443:192.168.126.51:443 \
                   -R 6443:192.168.126.11:6443 \
                   -R 16509:localhost:16509 \
                   -R 8080:192.168.126.51:80 \
                   -p 2222 root@127.0.0.1 \
                ; then
			echo "[WARNING] SSH tunnelling failed, retrying..."
			sleep 0.1
		fi
	done
}

trap "kill 0" SIGINT

# set up port forwarding from the SSH bastion to the local port 2222
port-forward &

# without a better synchonization library, we just need to wait for the port-forward to run
sleep 5

# run an SSH tunnel from the port 8080 on the SSH bastion (through local port 2222) to local port 80
ssh-tunnel &

for job in $( jobs -p ); do
	wait "${job}"
done
