#!/bin/bash
#******************************************************************************
# Licensed Materials - Property of IBM
# (c) Copyright IBM Corporation 2020. All Rights Reserved.
#
# Note to U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.
#******************************************************************************

#******************************************************************************
# PREREQUISITES:
#   - Logged into cluster on the OC CLI (https://docs.openshift.com/container-platform/4.4/cli_reference/openshift_cli/getting-started-cli.html)
#
# PARAMETERS:
#   -u : <username> (string), Defaults to "admin"
#   -p : <password> (string), must be supplied
#
# USAGE:
#   Changing both the username and password
#     ./change-cs-credentials -u administrator -p my-super-long-password-for-administrator

function usage() {
  echo "Usage: $0 -u <username> -p <password>"
}

CURRENT_DIR=$(dirname $0)
NEW_USERNAME="admin"
NEW_PASSWORD=""

while getopts "u:p:" opt; do
  case ${opt} in
  u)
    NEW_USERNAME="$OPTARG"
    ;;
  p)
    NEW_PASSWORD="$OPTARG"
    ;;
  \?)
    usage
    exit
    ;;
  esac
done

if [ -z $NEW_PASSWORD ]; then
  usage
  echo "-p to set the password is not optional"
  exit 1
fi

function output_time() {
  SECONDS=${1}
  if ((SECONDS > 59)); then
    printf "%d minutes, %d seconds" $((SECONDS / 60)) $((SECONDS % 60))
  else
    printf "%d seconds" $SECONDS
  fi
}

function cloudctl_login() {
  cp_console=${1}
  cp_username=${2}
  cp_password=${3}
  time=0
  wait_time=5
  while true; do
    # TODO if ! cloudctl login -a https://${cp_console} -u ${cp_username} -p "${cp_password}" -n default --skip-ssl-validation --skip-helm-config --skip-kubectl-config >/dev/null 2>&1; then
    if ! cloudctl login -a https://${cp_console} -u ${cp_username} -p "${cp_password}" -n default --skip-ssl-validation --skip-helm-config --skip-kubectl-config ; then
      echo "WARNING: Unable to login to the console as user '${cp_username}' with the given password" 1>&2
    else
      echo "INFO: cloudctl login succeeded"
      break
    fi
    if [ $time -gt 900 ]; then
      echo "ERROR: Exiting as failed to login using cloudctl"
      exit 1
    fi
    echo "INFO: Waiting up to 15 minutes to login using cloudctl. Waited for $(output_time $time)."
    ((time = time + $wait_time))
    sleep $wait_time
  done
}

echo "INFO: Waiting for the platform-auth-idp-credentials secret to appear"
time=0
wait_time=5
while ! oc get secrets platform-auth-idp-credentials -n ibm-common-services; do
  if [ $time -gt 3600 ]; then
    echo "ERROR: Exiting as the secret 'platform-auth-idp-credentials' does not exist in the namespace 'ibm-common-services'"
    exit 1
  fi

  echo "INFO: Waiting up to 60 minutes for Common Services platform-auth-idp-credentials to appear. Waited for $(output_time $time)."
  ((time = time + $wait_time))
  sleep $wait_time
done
echo "INFO: Found the secret platform-auth-idp-credentials in the namespace 'ibm-common-services'"

echo "INFO: Waiting for Common Services console route"
time=0
wait_time=5
export CP_CONSOLE=$(oc get routes -n ibm-common-services cp-console -o jsonpath='{.spec.host}')
while [ -z $CP_CONSOLE ]; do
  if [ $time -gt 3600 ]; then
    echo "ERROR: Exiting as the Common Services console route has still not been created"
    exit 1
  fi

  echo "INFO: Waiting up to 60 minutes for Common Services console route to appear. Waited for $(output_time $time)."
  ((time = time + $wait_time))
  sleep $wait_time

  export CP_CONSOLE=$(oc get routes -n ibm-common-services cp-console -o jsonpath='{.spec.host}')
done

export CP_USERNAME=$(oc get secrets -n ibm-common-services platform-auth-idp-credentials -o jsonpath='{.data.admin_username}' | base64 --decode)
export CP_PASSWORD=$(oc get secrets -n ibm-common-services platform-auth-idp-credentials -o jsonpath='{.data.admin_password}' | base64 --decode)
echo "INFO: CP_USERNAME: ${CP_USERNAME}"
echo "INFO: CP_CONSOLE: ${CP_CONSOLE}"

echo "INFO: Downloading cloudctl"
cp_client_platform=linux-amd64
if [[ $(uname) == Darwin ]]; then
  cp_client_platform=darwin-amd64
fi
mkdir -p ${CURRENT_DIR}/bin
curl -k -sS -o ${CURRENT_DIR}/bin/cloudctl https://${CP_CONSOLE}/api/cli/cloudctl-${cp_client_platform}
chmod +x ${CURRENT_DIR}/bin/*
export PATH=${CURRENT_DIR}/bin:${PATH}

echo "INFO: Doing the cloudctl login"
cloudctl_login "${CP_CONSOLE}" "${CP_USERNAME}" "${CP_PASSWORD}"

if [[ "$CP_PASSWORD" == "$NEW_PASSWORD" ]]; then
  echo "INFO: Password not changed"
else
  echo "INFO: Updating the admin password"
  # TODO if ! cloudctl pm update-secret ibm-common-services platform-auth-idp-credentials -f -d admin_password=${NEW_PASSWORD} >/dev/null 2>&1; then
  if ! cloudctl pm update-secret ibm-common-services platform-auth-idp-credentials -f -d admin_password=${NEW_PASSWORD} ; then
    echo "ERROR: Failed to update the admin password" 1>&2
    exit 1
  fi
  export CP_NEW_PASSWORD=$(oc get secrets -n ibm-common-services platform-auth-idp-credentials -o jsonpath='{.data.admin_password}' | base64 --decode)
  if [[ "$CP_NEW_PASSWORD" == "$NEW_PASSWORD" ]]; then
    echo "INFO: Password changed"
  elif [[ "$CP_NEW_PASSWORD" == "$CP_PASSWORD" ]]; then
    echo "ERROR: Password still the old password"
    export NEW_PASSWORD=${CP_NEW_PASSWORD}
  else
    echo "ERROR: Password something completely different!"
    export NEW_PASSWORD=${CP_NEW_PASSWORD}
  fi
fi

if [[ "$CP_USERNAME" == "$NEW_USERNAME" ]]; then
  echo "INFO: Username not changed"
else
  echo "INFO: Updating the admin username"
  time=0
  wait_time=5
  while true; do
    # TODO if ! cloudctl pm update-secret ibm-common-services platform-auth-idp-credentials -f -d admin_username=${NEW_USERNAME} >/dev/null 2>&1; then
    if ! cloudctl pm update-secret ibm-common-services platform-auth-idp-credentials -f -d admin_username=${NEW_USERNAME} ; then
      echo "WARNING: Failed to update the admin username" 1>&2
    else
      break
    fi
    if [ $time -gt 600 ]; then
      echo "ERROR: Exiting as failed to update the admin username"
      exit 1
    fi
    echo "INFO: Waiting up to 10 minutes to update the admin username. Waited for $(output_time $time)."
    ((time = time + $wait_time))
    sleep $wait_time
  done

  echo "INFO: Updating the clusterrolebinding role-based access control (RBAC) object with the new username"
  str1=$(oc get clusterrolebinding oidc-admin-binding -o json | jq '.subjects[0].name' | sed -e 's/"//g')
  str2=$(cut -d "#" -f2 <<<$str1)
  subjectName0=$(echo "${str1/$str2/$NEW_USERNAME}")
  oc get clusterrolebinding -n ibm-common-services oidc-admin-binding -o json | jq '.subjects[0].name = "'$subjectName0'"' | oc replace -f -
  oc get clusterrolebinding -n ibm-common-services oidc-admin-binding -o json | jq '.subjects[1].name="'$NEW_USERNAME'"' | oc replace -f -
fi

echo "INFO: Checking can cloudctl login using the new username/password"
cloudctl_login ${CP_CONSOLE} ${NEW_USERNAME} ${NEW_PASSWORD}
