#!/bin/bash
# Load profile vars
. profile_s390x.sh
. profile_ppc64le.sh

set -o nounset
set -o pipefail
set -o errexit

# Number of clusters that can run on this host
echo "$CLUSTER_CAPACITY"

# Bastion name & credentials
echo "$ENVIRONMENT"
environment=$ENVIRONMENT
token=$TOKEN

# Default Ports
libvirt_port=16509
api_port=6443
http_port=80
https_port=443

# Debug and verify input
if [[ -z "${token:-}" ]]; then
	echo "[FATAL] \${token} must be set to the credentials of the port-forwarder service account."
	exit 1
elif [[ -z "${environment:-}" ]]; then
	echo "[FATAL] \${environment} must be set to specify which bastion to interact with."
	exit 1
fi

function OC() {	./oc --server https://api.ci.openshift.org --token "${token}" --namespace "${environment}" "${@}"
}

function timestamp() {
	# With UTC format.  2020-11-04 06:19:24
	date -u  +"%Y-%m-%d %H:%M:%S"
}

function port-forward() {
	while true; do
		echo "$(timestamp) [INFO] Setting up port-forwarding to connect to the bastion..."
		pod="$( OC get pods --selector component=sshd -o jsonpath={.items[0].metadata.name} )"
		if ! OC port-forward "${pod}" "${1:?Port was not specified}"; then
			echo "$(timestamp) [WARNING] Port-forwarding failed, retrying..."
			sleep 0.1
		fi
	done
}

# This opens an ssh tunnel. It uses port 2222 for the ssh traffic.
# It basically says send traffic from bastion service port $1 to
# local VM port $1 using port 2222 to establish the ssh connection.
function ssh-tunnel() {
	while true; do
		echo "$(timestamp) [INFO] Setting up a reverse SSH tunnel to connect bastion port "${1:?Bastion service port was not specified}" to VM port "${1:?VM port was not specified}"..."
		if ! ssh -N -T root@127.0.0.1 -p 2222 -R "$1:127.0.0.1:$1"; then
			echo "$(timestamp) [WARNING] SSH tunnelling failed, retrying..."
			sleep 0.1
		fi
	done
}

# This isn't used right now, but it allows forwarding udp traffic,
# which is what ipmi uses. It forwards from local port $1 to host
# $2 port 623. It is important that firewalld is configured on $2
# to allow incoming udp traffic connections. This would mean running
# something like `firewall-cmd --add-port=623/udp`
function socat-udp-forward() {
	while true; do
		echo "[INFO] Forwarding udp traffic from localhost $1 to external host"
		if ! socat udp4-recvfrom:"${1:?Local port not specified}",fork,reuseaddr udp4-sendto:"${2:?External host not specified}":623; then
			echo "[WARNING] socat udp port forward failed"
			exit 1
		fi
	done
}

# This forwards tcp traffic from local port $1 to remote host
# $2 on port $3. It is important that firewalld is configured on $2
# to allow incoming tcp traffic connections. This would mean running
# something like `firewall-cmd --add-port=$3/tcp`
function socat-tcp-forward() {
	while true; do
		echo "[INFO] Forwarding tcp traffic from localhost $1 to external host"
		if ! socat tcp-listen:"${1:?Local port not specified}",fork,reuseaddr tcp:"${2:?External host not specified}":"${3:?Remote port not specified}"; then
			echo "[WARNING] socat tcp port forward failed"
			exit 1
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
	port-forward 2222 &
	PID_PORT=$!

	# without a better synchonization library, we just need to wait for the port-forward to run
	sleep 10s

# ${BASTION_PORTS["LIBVIRT"]}:127.0.0.1:16509 \
# ${CLUSTER_PORTS["0,API"]}:127.0.0.1:6443   ${CLUSTER_PORTS["0,HTTP"]}:127.0.0.1:80    ${CLUSTER_PORTS["0,HTTPS"]}:127.0.0.1:443 \
# ${CLUSTER_PORTS["1,API"]}:127.0.0.1:16443  ${CLUSTER_PORTS["1,HTTP"]}:127.0.0.1:10080 ${CLUSTER_PORTS["1,HTTPS"]}:127.0.0.1:10443 \
# ${CLUSTER_PORTS["2,API"]}:127.0.0.1:26443  ${CLUSTER_PORTS["2,HTTP"]}:127.0.0.1:20080 ${CLUSTER_PORTS["2,HTTPS"]}:127.0.0.1:20443 \
# ${CLUSTER_PORTS["3,API"]}:127.0.0.1:36443  ${CLUSTER_PORTS["3,HTTP"]}:127.0.0.1:30080 ${CLUSTER_PORTS["3,HTTPS"]}:127.0.0.1:30443 \
# ${CLUSTER_PORTS["4,API"]}:127.0.0.1:46443  ${CLUSTER_PORTS["4,HTTP"]}:127.0.0.1:40080 ${CLUSTER_PORTS["4,HTTPS"]}:127.0.0.1:40443 \

	# run an SSH tunnel from the port $1 on the SSH bastion (through local port 2222) to local port $1
	ssh-tunnel 16509 &
	for i in $(seq 0 $CLUSTER_CAPACITY); do
	    port=$(( 6443 + $i * (10000) ))
		ssh-tunnel $port &
		port=$(( 80 + $i * (10000) ))
		ssh-tunnel $port &
        port=$(( 443 + $i * (10000) ))
		ssh-tunnel $port &
    done

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

# setup socat port forwarding for connections to vm oc cluster
# socat-tcp-forward ${port} ${vm} ${port} &

for job in $( jobs -p ); do
	wait "${job}"
done
