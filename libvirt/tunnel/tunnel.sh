#!/bin/bash

set -o nounset
set -o pipefail
set -o errexit

# Number of clusters that can run on this host
cluster_capacity=5

# Bastion name & credentials
bastion_name="bastion-z"
token=""

# Default Ports
libvirt_port=16509
api_port=6443
http_port=80
https_port=443

# Cluster id is added to bastion ports so that they don't conflict with each other
cluster_id=1
declare -A BASTION_PORTS
BASTION_PORTS["LIBVIRT"]=$(($libvirt_port + $cluster_id))
BASTION_PORTS["API"]=$(($api_port + $cluster_id))
BASTION_PORTS["HTTP"]=$(($http_port + $cluster_id))
BASTION_PORTS["HTTPS"]=$(($https_port + $cluster_id))

# Bastion ports are calculated to ensure uniqueness, but the first env breaks the pattern
declare -A CLUSTER_PORTS
CLUSTER_PORTS["0,API"]=${BASTION_PORTS["API"]}
CLUSTER_PORTS["0,HTTP"]=$((${BASTION_PORTS["HTTP"]} + 8000))
CLUSTER_PORTS["0,HTTPS"]=$((${BASTION_PORTS["HTTPS"]} + 8000))
for (( i=1; i<$cluster_capacity; i++ ))
do
  CLUSTER_PORTS["$i,API"]=$((${BASTION_PORTS["API"]} + 10000 * $i))
  CLUSTER_PORTS["$i,HTTP"]=$((${BASTION_PORTS["HTTP"]} + 10000 * $i))
  CLUSTER_PORTS["$i,HTTPS"]=$((${BASTION_PORTS["HTTPS"]} + 10000 * $i))
done

# Debug and verify input
if [[ -z "${token:-}" ]]; then
  echo "[ERROR] \$token must be passed."
  exit 1
fi
# declare -p BASTION_PORTS
# declare -p CLUSTER_PORTS
# echo "-R ${BASTION_PORTS['LIBVIRT']}:127.0.0.1:16509"
# echo "-R ${CLUSTER_PORTS['0,API']}:127.0.0.1:6443   -R ${CLUSTER_PORTS['0,HTTP']}:127.0.0.1:80    -R ${CLUSTER_PORTS['0,HTTPS']}:127.0.0.1:443"
# echo "-R ${CLUSTER_PORTS['1,API']}:127.0.0.1:16443  -R ${CLUSTER_PORTS['1,HTTP']}:127.0.0.1:10080 -R ${CLUSTER_PORTS['1,HTTPS']}:127.0.0.1:10443"
# echo "-R ${CLUSTER_PORTS['2,API']}:127.0.0.1:26443  -R ${CLUSTER_PORTS['2,HTTP']}:127.0.0.1:20080 -R ${CLUSTER_PORTS['2,HTTPS']}:127.0.0.1:20443"
# echo "-R ${CLUSTER_PORTS['3,API']}:127.0.0.1:36443  -R ${CLUSTER_PORTS['3,HTTP']}:127.0.0.1:30080 -R ${CLUSTER_PORTS['3,HTTPS']}:127.0.0.1:30443"
# echo "-R ${CLUSTER_PORTS['4,API']}:127.0.0.1:46443  -R ${CLUSTER_PORTS['4,HTTP']}:127.0.0.1:40080 -R ${CLUSTER_PORTS['4,HTTPS']}:127.0.0.1:40443"

function OC() {
	./oc --server https://api.ci.openshift.org --token "${token}" --namespace "${bastion_name}" "${@}"
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
                        -R ${BASTION_PORTS["LIBVIRT"]}:127.0.0.1:16509 \
                        -R ${CLUSTER_PORTS["0,API"]}:127.0.0.1:6443   -R ${CLUSTER_PORTS["0,HTTP"]}:127.0.0.1:80    -R ${CLUSTER_PORTS["0,HTTPS"]}:127.0.0.1:443 \
                        -R ${CLUSTER_PORTS["1,API"]}:127.0.0.1:16443  -R ${CLUSTER_PORTS["1,HTTP"]}:127.0.0.1:10080 -R ${CLUSTER_PORTS["1,HTTPS"]}:127.0.0.1:10443 \
                        -R ${CLUSTER_PORTS["2,API"]}:127.0.0.1:26443  -R ${CLUSTER_PORTS["2,HTTP"]}:127.0.0.1:20080 -R ${CLUSTER_PORTS["2,HTTPS"]}:127.0.0.1:20443 \
                        -R ${CLUSTER_PORTS["3,API"]}:127.0.0.1:36443  -R ${CLUSTER_PORTS["3,HTTP"]}:127.0.0.1:30080 -R ${CLUSTER_PORTS["3,HTTPS"]}:127.0.0.1:30443 \
                        -R ${CLUSTER_PORTS["4,API"]}:127.0.0.1:46443  -R ${CLUSTER_PORTS["4,HTTP"]}:127.0.0.1:40080 -R ${CLUSTER_PORTS["4,HTTPS"]}:127.0.0.1:40443 \
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
