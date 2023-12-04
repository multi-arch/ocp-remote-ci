#!/usr/bin/env bash
set -xeu

APICI_BUILD01="\<apici_build01\>"
APICI_BUILD02="\<apici_build02\>"
declare -a APICIS=( apici_build01 apici_build02 )

function restart_apici ()
{
	for APICI in ${APICIS[@]}
	do
		sudo systemctl stop ${APICI}.service || true
		sudo install --owner=root --group=root --mode=0644 ./libvirt/tunnel/${APICI}.service /usr/lib/systemd/system/
	done
	sudo systemctl daemon-reload
	for APICI in ${APICIS[@]}
	do
		sudo systemctl start ${APICI}.service
		sudo systemctl status ${APICI}.service
	done
}

function restart_haproxy ()
{
	sudo /bin/cp ./libvirt/haproxy/haproxy_$(hostname).cfg /etc/haproxy/haproxy.cfg
	sudo systemctl restart haproxy.service
	sudo systemctl status haproxy.service
}

function my_sha ()
{
	local F=${1}

	SUM=$(sudo sha1sum ${F} | cut -f1 -d' ')
	RC=${PIPESTATUS[0]}
	echo ${SUM}

	return ${RC}
}

function shas_unmodified ()
{
	local -n ARRAY1=$1
	local -n ARRAY2=$2
	local LENGTH=${#ARRAY1[@]}

	for (( I = 0; I < LENGTH; I++ ))
	do
		if [[ ${ARRAY1[${I}]} != ${ARRAY2[${I}]} ]]
		then
			return 1
		fi
	done

	return 0
}

if [[ ! -v NAMESPACE ]]
then
	echo "ERROR: NAMESPACE environment variable must be set!"
	exit 1
fi
if [[ -z "${NAMESPACE}" ]]
then
	echo "ERROR: NAMESPACE environment variable must have a value!"
	exit 1
fi
case ${NAMESPACE} in
	"bastion-ppc64le-libvirt"|"bastion-z")
	;;
	"*")
		echo "ERROR: Invalid NAMESPACE value of ${NAMESPACE}"
		exit 1
	;;
esac

# If APICI_SINGLE is set then validate and reset APICIS array to this CI
if [[ -n ${APICI_SINGLE:-""} ]]
then
	APICIVALUE="\<${APICI_SINGLE}\>"
	if [[ ${APICIS[*]} =~ ${APICIVALUE} ]]
	then
		APICIS=( "${APICI_SINGLE}" )
	else
		echo "ERROR: Invalid APICI_SINGLE value of ${APICI_SINGLE}"
		exit 1
	fi
fi


if [[ ${APICIS[*]} =~ $APICI_BUILD01 ]]
then
	if [[ ! -v LOGIN_TOKEN_B01 ]]
	then
		echo "ERROR: LOGIN_TOKEN_B01 environment variable must be set!"
		exit 1
	fi
	if [[ -z "${LOGIN_TOKEN_B01}" ]]
	then
		echo "ERROR: LOGIN_TOKEN_B01 environment variable must have a value!"
		exit 1
	fi
fi
if [[ ${APICIS[*]} =~ $APICI_BUILD02 ]]
then
	if [[ ! -v LOGIN_TOKEN_B02 ]]
	then
		echo "ERROR: LOGIN_TOKEN_B02 environment variable must be set!"
		exit 1
	fi
	if [[ -z "${LOGIN_TOKEN_B02}" ]]
	then
		echo "ERROR: LOGIN_TOKEN_B02 environment variable must have a value!"
		exit 1
	fi
fi

declare -a PROGRAMS=( git oc jq )
for PROGRAM in ${PROGRAMS[@]}
do
	if ! hash ${PROGRAM}
	then
		echo "ERROR: ${PROGRAM} must be installed!"
		exit 1
	fi
done

if [[ -z "$(hostname)" ]]
then
	echo "ERROR: the hostname command must resolve to a name!"
	exit 1
fi
if ! sudo ls / > /dev/null 2>&1;
then
	echo "ERROR: passwordless sudo required!"
	exit 1
fi

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
#SCRIPT_DIR="/home/ocp/ocp-remote-ci"						# For hacking

if [[ ! -d "${SCRIPT_DIR}" ]]
then
	echo "ERROR: Directory ${SCRIPT_DIR} doesn't exist!"
	exit 1
fi

cd "${SCRIPT_DIR}"

function get_token ()
{
	local LOGIN_TOKEN=$1
	local SERVER=$2

	oc login --token=${LOGIN_TOKEN} --server=${SERVER} > /dev/null

	STATUS=$(oc get pods --namespace=${NAMESPACE} --selector=component=sshd -o=json | jq --raw-output '.items[].status.containerStatuses[].ready')
	if [ "${STATUS}" == "false" ]
	then
		echo "Error: sshd pod is not ready"
		return 1
	fi

	TOKEN=$(oc sa get-token port-forwarder --namespace=${NAMESPACE})
	if [ -z "${TOKEN}" ]
	then
		echo "Error: oc sa get-token port-forwarder returned an empty token?!"
		return 1
	fi

	echo ${TOKEN}
	return 0
}

if [[ ${APICIS[*]} =~ $APICI_BUILD01 ]]
then
	TOKEN_B01=$(get_token ${LOGIN_TOKEN_B01} "https://api.build01.ci.devcluster.openshift.com:6443")
	RC=$?
	if [ ${RC} -gt 0 ]
	then
		exit 1
	fi
fi

if [[ ${APICIS[*]} =~ $APICI_BUILD02 ]]
then
	TOKEN_B02=$(get_token ${LOGIN_TOKEN_B02} "https://api.build02.gcp.ci.openshift.org:6443")
	RC=$?
	if [ ${RC} -gt 0 ]
	then
		exit 1
	fi
fi
declare -a LIBVIRT_FILES
declare -a LIBVIRT_FILES_OLD_SHA

LIBVIRT_FILES=("libvirt/tunnel/tunnel.sh")
for APICI in ${APICIS[@]}
do
	LIBVIRT_FILES+=("libvirt/tunnel/$APICI.service")
done

case ${NAMESPACE} in
	"bastion-ppc64le-libvirt")
		LIBVIRT_FILES+=(
"libvirt/tunnel/profile_C155F2U31.yaml"
"libvirt/tunnel/profile_C155F2U33.yaml"
"libvirt/tunnel/profile_C155F2U35.yaml"
		)
	;;
	"bastion-z")
		LIBVIRT_FILES+=(
"libvirt/tunnel/profile_lnxocp01.yaml"
"libvirt/tunnel/profile_lnxocp01.yaml"
		)
	;;
esac

for FILE in ${LIBVIRT_FILES[@]}
do
	SUM=$(sudo sha1sum ${FILE} | cut -f1 -d' ')
	LIBVIRT_FILES_OLD_SHA+=( ${SUM} )
done

OLD_INSTALL_CI_SHA1SUM=$(my_sha ${SCRIPT_DIR}/install-ci.sh)
RC=$?
if [ ${RC} -gt 0 ]
then
	exit 1
fi

if [[ ! -v BRANCH ]]
then
	BRANCH="master"
fi

git reset --hard HEAD
git clean -fxd .
git checkout ${BRANCH}
git fetch
git checkout -m origin/${BRANCH} install-ci.sh

NEW_INSTALL_CI_SHA1SUM=$(my_sha ${SCRIPT_DIR}/install-ci.sh)
RC=$?
if [ ${RC} -gt 0 ]
then
	exit 1
fi

if [[ "${OLD_INSTALL_CI_SHA1SUM}" != "${NEW_INSTALL_CI_SHA1SUM}" ]]
then
	echo "ERROR: install-ci.sh has changed upstream, rerun to reload the script!"
	exit 1
fi

git pull

if [[ ${APICIS[*]} =~ $APICI_BUILD01 ]]
then
	sed -i -e 's,TOKEN=__,TOKEN='${TOKEN_B01}',' libvirt/tunnel/apici_build01.service
fi
if [[ ${APICIS[*]} =~ $APICI_BUILD02 ]]
then
	sed -i -e 's,TOKEN=__,TOKEN='${TOKEN_B02}',' libvirt/tunnel/apici_build02.service
fi

declare -a LIBVIRT_FILES_NEW_SHA

for FILE in ${LIBVIRT_FILES[@]}
do
	SUM=$(sha1sum ${FILE} | cut -f1 -d' ')
	LIBVIRT_FILES_NEW_SHA+=( ${SUM} )
done

if ! shas_unmodified LIBVIRT_FILES_OLD_SHA LIBVIRT_FILES_NEW_SHA
then
	restart_apici
fi

if ! sudo diff ./libvirt/haproxy/haproxy_$(hostname).cfg /etc/haproxy/haproxy.cfg;
then
	restart_haproxy
fi

FILENAME="./libvirt/tunnel/profile_$(hostname).yaml"
CLUSTER_ID=$(yq eval '.profile.cluster_id' ${FILENAME})
declare -a BASTION_SSH_PORTS=( 1033 1043 1053 1063 1073 1083 )
for I in ${BASTION_SSH_PORTS[*]}
do
	sudo firewall-cmd --permanent --zone=libvirt --add-port=$(( ${I} + ${CLUSTER_ID} ))/tcp || true
done
sudo firewall-cmd --reload || true
