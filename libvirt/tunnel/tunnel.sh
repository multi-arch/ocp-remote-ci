#!/bin/bash

set -o nounset
set -o pipefail
set -o errexit

SCRIPT_PATH=$(dirname $0)
filename="${SCRIPT_PATH}/profile_${HOSTNAME}.yaml" #HOSTNAME

if [[ ! -f "${filename}" ]]; then
	echo "${filename} file missing"
	exit 0
fi

# Load profile vars
ARCH=$(yq eval '.profile.arch' ${filename})
CLUSTER_CAPACITY=$(yq eval '.profile.cluster_capacity' ${filename})
CLUSTER_ID=$(yq eval '.profile.cluster_id' ${filename})
ENVIRONMENT=$(yq eval '.profile.environment' ${filename})
TOKEN=$(yq eval '.profile.token' ${filename})

# port-forward
PORT_FRWD=2222

# Debug and verify input
if [[ -z "${TOKEN:-}" ]]; then
	echo "[FATAL] \${token} must be set to the credentials of the port-forwarder service account."
	exit 1
elif [[ -z "${ENVIRONMENT:-}" ]]; then
	echo "[FATAL] \${environment} must be set to specify which bastion to interact with."
	exit 1
elif [[ -z "${CLUSTER_CAPACITY:-}" ]]; then
	echo "[FATAL] \${CLUSTER_CAPACITY} must be set to specify cluster capacity."
	exit 1
elif [[ -z "${CLUSTER_ID:-}" ]]; then
	echo "[FATAL] \${CLUSTER_ID} must be set to specify cluster."
	exit 1
fi

# Declaring and setting Bastion and Local ports
PORTS="-R $(yq eval '.libvirt.bastion-port' ${filename}):127.0.0.1:$(yq eval '.libvirt.target-port' ${filename})"
for i in $(seq 0 $(( $CLUSTER_CAPACITY-1 )) ); do
		PORTS+=" -R $(yq eval '.libvirt-'$ARCH-$CLUSTER_ID-$i'.api.bastion-port' ${filename}):127.0.0.1:$(yq eval '.libvirt-'$ARCH-$CLUSTER_ID-$i'.api.target-port' ${filename}) 
				 -R $(yq eval '.libvirt-'$ARCH-$CLUSTER_ID-$i'.http.bastion-port' ${filename}):127.0.0.1:$(yq eval '.libvirt-'$ARCH-$CLUSTER_ID-$i'.http.target-port' ${filename}) 
				 -R $(yq eval '.libvirt-'$ARCH-$CLUSTER_ID-$i'.https.bastion-port' ${filename}):127.0.0.1:$(yq eval '.libvirt-'$ARCH-$CLUSTER_ID-$i'.https.target-port' ${filename}) "
done

if echo "${PORTS}" | grep null 2> /dev/null; then
	echo "Error: yq returned null in PORTS variable creation"
	echo "PORTS=${PORTS}"
	exit 1
fi

function OC() {	
	oc --server https://api.build01.ci.devcluster.openshift.com:6443 --token "${TOKEN}" --namespace "${ENVIRONMENT}" "${@}"
}

function timestamp() {
	# With UTC format.  2020-11-04 06:19:24
	date -u  +"%Y-%m-%d %H:%M:%S"
}

function port-forward() {
	LAST_GOOD_DATE=$(date +%s)

	echo "$(timestamp) [INFO] Setting up port-forwarding to connect to the bastion..."

	while true; do
		CURRENT_GOOD_DATE=$(date +%s)
		# Have we been unsuccessful for 15 minutes?
		if (( CURRENT_GOOD_DATE - LAST_GOOD_DATE > 15*60 )); then
			# Houston, we have a problem
			echo "$(timestamp) *** [ERROR] port-forward: CURRENT_GOOD_DATE=${CURRENT_GOOD_DATE} > LAST_GOOD_DATE=${LAST_GOOD_DATE}"
			break
		fi

		pod="$( OC get pods --selector component=sshd -o jsonpath={.items[0].metadata.name} )"
		if ! OC port-forward "${pod}" "${1:?Port was not specified}"; then
			echo "$(timestamp) [WARNING] Port-forwarding failed, retrying..."
			sleep 30s
		fi
	done

	echo "$(timestamp) [INFO] Exiting port-forward"
}

# This opens an ssh tunnel. It uses port 2222 for the ssh traffic.
# It basically says send traffic from bastion service port to
# local VM port using port 2222 to establish the ssh connection.
function ssh-tunnel() {
	LAST_GOOD_DATE=$(date +%s)

	echo "$(timestamp) [INFO] Setting up a reverse SSH tunnel to connect bastion port "${@:?Bastion service port and local service port was not specified}"..."

	while true; do
		CURRENT_GOOD_DATE=$(date +%s)
		# Have we been unsuccessful for 15 minutes?
		if (( CURRENT_GOOD_DATE - LAST_GOOD_DATE > 15*60 )); then
			# Houston, we have a problem
			echo "$(timestamp) *** [ERROR] ssh-tunnel: CURRENT_GOOD_DATE=${CURRENT_GOOD_DATE} > LAST_GOOD_DATE=${LAST_GOOD_DATE}"
			break
		fi

		if ! ssh -N -T root@127.0.0.1 -p ${PORT_FRWD} $@; then
			echo "$(timestamp) [WARNING] SSH tunnelling failed, retrying..."
			sleep 30s
		fi
	done

	echo "$(timestamp) [INFO] Exiting ssh-tunnel"
}

function pid-exists() {
	kill -0 $1 2>/dev/null
	return $?
}

trap "kill 0" SIGINT

PID_PORT=-1
PID_SSH=-1
LAST_GOOD_DATE=$(date +%s)

while true; do

	if [[ ${PID_PORT} > 1 ]] && pid-exists ${PID_PORT}; then
		echo "$(timestamp) *** [WARNING] Killing old port-forward (${PID_PORT})"
		kill -9 ${PID_PORT}
	fi
	if [[ ${PID_SSH} > 1 ]] && pid-exists ${PID_SSH}; then
		echo "$(timestamp) *** [WARNING] Killing old ssh-tunnel (${PID_SSH})"
		kill -9 ${PID_SSH}
	fi

	CURRENT_GOOD_DATE=$(date +%s)
	# Have we been unsuccessful for 15 minutes?
	if (( CURRENT_GOOD_DATE - LAST_GOOD_DATE > 15*60 )); then
		# Houston, we have a problem
		"$(timestamp) *** [ERROR] main: CURRENT_GOOD_DATE=${CURRENT_GOOD_DATE} > LAST_GOOD_DATE=${LAST_GOOD_DATE}"
		break
	fi

	# set up port forwarding from the SSH bastion to the local port 2222 --> ${PORT_FRWD}
	port-forward ${PORT_FRWD} &
	PID_PORT=$!

	# without a better synchonization library, we just need to wait for the port-forward to run
	sleep 5s

	# we need to authorize the host without asking the user a question
	ssh-keygen -f ~/.ssh/known_hosts -R "[127.0.0.1]:${PORT_FRWD}"
	ssh-keyscan -p ${PORT_FRWD} 127.0.0.1 >> ~/.ssh/known_hosts

	# run an SSH tunnel from the port on the SSH bastion (through local port 2222) to local port 
	ssh-tunnel ${PORTS} &
	PID_SSH=$!

	# without a better synchonization library, we just need to wait for the ssh-tunnel to run
	sleep 5s

	while true; do
		if pid-exists ${PID_PORT} && pid-exists ${PID_SSH}; then
			LAST_GOOD_DATE=$(date +%s)
			echo "$(timestamp) *** [INFO] Everyone up"
			sleep 10m
		else
			if ! pid-exists ${PID_PORT}; then
				echo "$(timestamp) *** [WARNING]: port-forward down!"
			fi
			if ! pid-exists ${PID_SSH}; then
				echo "$(timestamp) *** [WARNING]: ssh-tunnel down!"
			fi
			break
		fi
	done

done

[ -n "${PID_PORT} ] && (( ${PID_PORT} > 1 )) && kill -9 ${PID_PORT}
[ -n "${PID_SSH} ] && (( ${PID_SSH} > 1 )) && kill -9 ${PID_SSH}

# We should always loop and never exit successfully
exit 1
