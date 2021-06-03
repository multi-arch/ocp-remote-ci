#!/bin/bash

set -o nounset
set -o pipefail
set -o errexit

API_SERVER="https://api.build02.gcp.ci.openshift.org:6443"
PORT_FRWD=2223
TOKEN=""

SCRIPT_PATH=$(dirname $0)
filename="${SCRIPT_PATH}/tunnel.sh" #Shell script

if [[ ! -f "${filename}" ]]; then
	echo "${filename} file missing"
	exit 0
fi

chmod +x ${filename}
${filename} ${API_SERVER} ${PORT_FRWD} ${TOKEN}
