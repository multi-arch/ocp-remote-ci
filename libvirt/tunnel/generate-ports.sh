#!/bin/bash
set -o nounset
set -o pipefail
set -o errexit

# Default Ports
LIBVIRT_PORT=16509
API_PORT=6443
HTTP_PORT=80
HTTPS_PORT=443

for f in profile_*.yaml ; do filename=${f};
 if [[ ! -f ${filename} ]]; then
 	echo "${filename} file missing"
   exit 0
 fi
ARCH=$(yq eval '.profile.arch' ${filename})
CLUSTER_CAPACITY=$(yq eval '.profile.cluster_capacity' ${filename})
CLUSTER_ID=$(yq eval '.profile.cluster_id' ${filename})

# libvirt ports
yq eval -i '.libvirt.bastion-port='$(( $LIBVIRT_PORT + $CLUSTER_ID ))'' ${filename}
yq eval -i '.libvirt.target-port='$LIBVIRT_PORT'' ${filename}

yq eval -i '.api.bastion-port='$(($API_PORT + $CLUSTER_ID))'' ${filename}
yq eval -i '.api.target-port='$(($API_PORT))'' ${filename}
yq eval -i '.http.bastion-port='$(($HTTP_PORT + $CLUSTER_ID))'' ${filename}
yq eval -i '.http.target-port='$(($HTTP_PORT))'' ${filename}
yq eval -i '.https.bastion-port='$(($HTTPS_PORT + $CLUSTER_ID))'' ${filename}
yq eval -i '.https.target-port='$(($HTTPS_PORT))'' ${filename}

done