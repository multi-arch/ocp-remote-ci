#!/bin/bash

set -o nounset
set -o pipefail
set -o errexit
export TZ=UTC

# Number of clusters that can run on this host
cluster_capacity=4

# Bastion name & credentials
token=""
environment="bastion-ppc64le-libvirt"

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

function OC() {
	oc --server https://api.ci.openshift.org --token "${token}" --namespace "${environment}" "${@}"
}

function timestamp() {
	# With UTC format.  2020-11-04 06:19:24
	date -u  +"%Y-%m-%d %H:%M:%S"
}

function port-forward() {
	while true; do
		echo "$(timestamp) [INFO] Setting up port-forwarding..."
		pod="$( OC get pods --selector component=sshd -o jsonpath={.items[0].metadata.name} )"
		if ! OC port-forward "${pod}" 2222; then
			echo "$(timestamp) [WARNING] Port-forwarding failed, retrying..."  >> tunnel.log
			sleep 0.1
		fi
	done
}

function ssh-tunnel() {
	while true; do
		echo "$(timestamp) [INFO] Setting up SSH tunnelling..." >> tunnel.log
		if ! ssh -N -T root@127.0.0.1 -p 2222 \
                        -R ${BASTION_PORTS["LIBVIRT"]}:127.0.0.1:16509 \
                        -R ${CLUSTER_PORTS["0,API"]}:127.0.0.1:6443   -R ${CLUSTER_PORTS["0,HTTP"]}:127.0.0.1:80    -R ${CLUSTER_PORTS["0,HTTPS"]}:127.0.0.1:443 \
                        -R ${CLUSTER_PORTS["1,API"]}:127.0.0.1:16443  -R ${CLUSTER_PORTS["1,HTTP"]}:127.0.0.1:10080 -R ${CLUSTER_PORTS["1,HTTPS"]}:127.0.0.1:10443 \
                        -R ${CLUSTER_PORTS["2,API"]}:127.0.0.1:26443  -R ${CLUSTER_PORTS["2,HTTP"]}:127.0.0.1:20080 -R ${CLUSTER_PORTS["2,HTTPS"]}:127.0.0.1:20443 \
                        -R ${CLUSTER_PORTS["3,API"]}:127.0.0.1:36443  -R ${CLUSTER_PORTS["3,HTTP"]}:127.0.0.1:30080 -R ${CLUSTER_PORTS["3,HTTPS"]}:127.0.0.1:30443 \
		; then
			echo "$(timestamp) [WARNING] SSH tunnelling failed, retrying..." >> tunnel.log
			sleep 0.1
		fi
	done
}

function pid-exists() {
	kill -0 $1 2>/dev/null
	return $?
}

trap "kill 0" SIGINT

PID_PORT=-1
PID_SSH=-1

while true; do

	if [[ ${PID_PORT} > 1 ]] && pid-exists ${PID_PORT}; then
		echo "$(timestamp) *** [WARNING] Killing old port-forward (${PID_PORT})" >> tunnel.log
		kill -9 ${PID_PORT}
	fi
	if [[ ${PID_SSH} > 1 ]] && pid-exists ${PID_SSH}; then
		echo "$(timestamp) *** [WARNING] Killing old ssh-tunnel (${PID_SSH})" >> tunnel.log
		kill -9 ${PID_SSH}
	fi

	# set up port forwarding from the SSH bastion to the local port 2222
	port-forward &
	PID_PORT=$!

	# without a better synchonization library, we just need to wait for the port-forward to run
	sleep 10s

	# run an SSH tunnel from the port 8080 on the SSH bastion (through local port 2222) to local port 80
	ssh-tunnel &
	PID_SSH=$!
	sleep 10s
	while true; do
		if pid-exists ${PID_PORT} && pid-exists ${PID_SSH}; then
			echo "$(timestamp) *** [INFO] Everyone up" >> tunnel.log
			sleep 10m
		else
			if ! pid-exists ${PID_PORT}; then
				echo "$(timestamp) *** [WARNING]: port-forward down!" >> tunnel.log
			fi
			if ! pid-exists ${PID_SSH}; then
				echo "$(timestamp) *** [WARNING]: ssh-tunnel down!" >> tunnel.log
			fi
			break
		fi

	done

done
