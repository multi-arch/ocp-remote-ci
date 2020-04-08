#!/bin/bash

set -o nounset
set -o pipefail
set -o errexit


token=""

if [[ -z "${token:-}" ]]; then
  echo "[ERROR] \$token must be passed."
  exit 1
fi

function OC() {
	./oc --server https://api.ci.openshift.org --token "${token}" --namespace bastion-z "${@}"
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
		if ! ssh -N -T root@127.0.0.1 -p 2222 \
			-R 16509:127.0.0.1:16509 \
			-R 6443:127.0.0.1:6443 -R 8080:127.0.0.1:80 -R 8443:127.0.0.1:443 \
			-R 16443:127.0.0.1:16443 -R 10080:127.0.0.1:10080 -R 10443:127.0.0.1:10443 \
			-R 26443:127.0.0.1:26443 -R 20080:127.0.0.1:20080 -R 20443:127.0.0.1:20443 \
			-R 36443:127.0.0.1:36443 -R 30080:127.0.0.1:30080 -R 30443:127.0.0.1:30443 \
			-R 46443:127.0.0.1:46443 -R 40080:127.0.0.1:40080 -R 40443:127.0.0.1:40443 \
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
