#!/bin/bash
set -o nounset
set -o pipefail
set -o errexit

# Default Ports
LIBVIRT_PORT=16509
API_PORT=6444
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

for i in $(seq 0 $(( $CLUSTER_CAPACITY-1 )) ); do
    yq eval -i '.libvirt-'$ARCH-$CLUSTER_ID-$i'.api.bastion-port='$(($API_PORT + $CLUSTER_ID + 10000 * $i))'' ${filename}
    yq eval -i '.libvirt-'$ARCH-$CLUSTER_ID-$i'.api.target-port='$(($API_PORT + 1 + 10000 * $i))'' ${filename}
    yq eval -i '.libvirt-'$ARCH-$CLUSTER_ID-$i'.http.bastion-port='$(($HTTP_PORT + $CLUSTER_ID + 8000 + 10000 * $i))'' ${filename}
    yq eval -i '.libvirt-'$ARCH-$CLUSTER_ID-$i'.http.target-port='$(($HTTP_PORT + + 8000 + 10000 * $i))'' ${filename}
    yq eval -i '.libvirt-'$ARCH-$CLUSTER_ID-$i'.https.bastion-port='$(($HTTPS_PORT + $CLUSTER_ID + 8000 + 10000 * $i))'' ${filename}
    yq eval -i '.libvirt-'$ARCH-$CLUSTER_ID-$i'.https.target-port='$(($HTTPS_PORT + 8000 + 10000 * $i))'' ${filename}
   
done
 yq eval -i '.libvirt-'$ARCH-$CLUSTER_ID'-*.*.target-ip="127.0.0.1"' ${filename}
done