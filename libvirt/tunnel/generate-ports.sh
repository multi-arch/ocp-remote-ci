#!/bin/bash
set -o nounset
set -o pipefail
set -o errexit

# Default Ports
LIBVIRT_PORT=16509
API_PORT=6443
HTTP_PORT=80
HTTPS_PORT=443

#set -x
declare -a BASTION_SSH_PORTS=( 1033 1043 1053 1063 1073 1083)

for FILENAME in profile_*.yaml
do
	if [[ ! -f ${FILENAME} ]]
	then
		echo "${FILENAME} file missing"
		exit 0
	fi

	ARCH=$(yq eval '.profile.arch' ${FILENAME})
	CLUSTER_CAPACITY=$(yq eval '.profile.cluster_capacity' ${FILENAME})
	CLUSTER_ID=$(yq eval '.profile.cluster_id' ${FILENAME})
        GENERATE_PORTS=$(yq eval '.profile.generate_ports' ${FILENAME})
        if [[ "$GENERATE_PORTS" == "false" ]]; then
          continue
        fi

        # libvirt ports
	yq eval -i '.libvirt.bastion-port='$((${LIBVIRT_PORT} + ${CLUSTER_ID})) ${FILENAME}
	yq eval -i '.libvirt.target-port='${LIBVIRT_PORT} ${FILENAME}
	yq eval -i '.api.bastion-port='$((${API_PORT} + ${CLUSTER_ID})) ${FILENAME}
	yq eval -i '.api.target-port='${API_PORT} ${FILENAME}
	yq eval -i '.http.bastion-port='$((${HTTP_PORT} + ${CLUSTER_ID} + 8000)) ${FILENAME}
	yq eval -i '.http.target-port='${HTTP_PORT} ${FILENAME}
	yq eval -i '.https.bastion-port='$((${HTTPS_PORT} + ${CLUSTER_ID} + 8000)) ${FILENAME}
	yq eval -i '.https.target-port='${HTTPS_PORT} ${FILENAME}
	for CLUSTER_NUM in $(seq 0 $((${CLUSTER_CAPACITY}-1)))
	do
		SSH_PORT=${BASTION_SSH_PORTS[${CLUSTER_NUM}]}
		yq eval -i '.bastion'${CLUSTER_NUM}'ssh.bastion-port='$((${SSH_PORT} + ${CLUSTER_ID})) ${FILENAME}
		yq eval -i '.bastion'${CLUSTER_NUM}'ssh.target-port=22' ${FILENAME}
	done
done
