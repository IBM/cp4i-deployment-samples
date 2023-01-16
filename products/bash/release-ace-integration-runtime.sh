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
# PARAMETERS:
#   -n : <namespace> (string), Defaults to "cp4i"
#   -r : <release_name> (string), Defaults to "ace-runtime"
#   -b : <bar file URL> (string), an array of bar file urls, defaults to "[]"
#   -c : <configurations> (string), an array of configuration names, defaults to "[]"
#
# USAGE:
#   With defaults values
#     ./release-ace-integration-runtime.sh
#
#   Overriding the namespace and release-name
#     ./release-ace-integration-runtime.sh -n cp4i -r cp4i-bernie-ace

CURRENT_DIR=$(dirname $0)
source $CURRENT_DIR/utils.sh
namespace="cp4i"
release_name="ace-runtime"
configurations="[]"
bar_file_urls="[]"

function divider() {
  echo -e "\n-------------------------------------------------------------------------------------------------------------------\n"
}

function usage() {
  echo "Usage: $0 -n <namespace> -r <release_name>"
  divider
  exit 1
}

while getopts "b:c:n:r:" opt; do
  case ${opt} in
  b)
    bar_file_urls="$OPTARG"
    ;;
  c)
    configurations="$OPTARG"
    ;;
  n)
    namespace="$OPTARG"
    ;;
  r)
    release_name="$OPTARG"
    ;;
  \?)
    usage
    ;;
  esac
done

if [ "$HA_ENABLED" == "true" ]; then
  replicas="3"
  license_use="AppConnectEnterpriseProduction"
else
  replicas="1"
  license_use="CloudPakForIntegrationNonProduction"
fi

source $CURRENT_DIR/license-helper.sh
echo "[DEBUG] ACE license: $(getACELicense $namespace)"

echo "Current directory: $CURRENT_DIR"
echo "INFO: Release name is: '$release_name'"
echo -e "\nINFO: Bar file URLs: '$bar_file_urls'"
echo -e "\nINFO: Configurations: '$configurations'"
echo -e "INFO: Going ahead to apply the CR for '$release_name'"

divider

YAML=$(cat <<EOF
apiVersion: appconnect.ibm.com/v1beta1
kind: IntegrationRuntime
metadata:
  name: ${release_name}
  namespace: ${namespace}
spec:
  license:
    accept: true
    license: $(getACELicense $namespace)
    use: ${license_use}
  template:
    spec:
      containers:
        - name: runtime
          resources:
            requests:
              cpu: 300m
              memory: 368Mi
  logFormat: basic
  barURL: ${bar_file_urls}
  configurations: $configurations
  version: '12.0'
  replicas: ${replicas}
EOF
)
OCApplyYAML "$namespace" "$YAML"

echo "TODO How to wait for the runtime to be ready?"

exit 0

timer=0
echo "[INFO] tracing is set to $tracing_enabled"
if [ "$tracing_enabled" == "true" ]; then
  while ! oc get secrets icp4i-od-store-cred -n ${namespace}; do
    echo "Waiting for the secret icp4i-od-store-cred to get created"
    if [ $timer -gt 30 ]; then
      echo "Secret icp4i-od-store-cred didn't get created in  ${namespace}, going to create the secret next "
      break
      timer=$((timer + 1))
    fi
    sleep 10
  done
fi
# -------------------------------------- INSTALL JQ ---------------------------------------------------------------------

divider

echo -e "\nINFO: Checking if jq is pre-installed..."
jqInstalled=false
jqVersionCheck=$(jq --version)

if [ $? -ne 0 ]; then
  jqInstalled=false
  JQ=./jq
else
  jqInstalled=true
  JQ=jq
fi

if [[ "$jqInstalled" == "false" ]]; then
  echo "INFO: JQ is not installed, installing jq..."
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "INFO: Installing on linux"
    wget -O jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64
    chmod +x ./jq
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    echo "INFO: Installing on MAC"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
    brew install jq
    JQ=jq
  fi
fi

echo -e "\nINFO: Installed JQ version is $($JQ --version)"

divider

# -------------------------------------- FIND TOTAL ACE REPLICAS DEPLOYED -----------------------------------------------

numberOfReplicas=$(oc get integrationservers $is_release_name -n $namespace -o json | $JQ -r '.spec.replicas')
echo "INFO: Number of Replicas for '$is_release_name' is $numberOfReplicas"
echo -e "\nINFO: Total number of ACE integration server '$is_release_name' related pods after deployment should be $numberOfReplicas"
divider

# -------------------------------------- CHECK FOR NEW IMAGE DEPLOYMENT STATUS ------------------------------------------

echo "INFO: Image tag for '$is_release_name' is '$imageTag'"

numberOfMatchesForImageTag=0
time=0

# wait for 10 minutes for all replica pods to be deployed with new image
while [ "$numberOfMatchesForImageTag" -ne "$numberOfReplicas" ]; do
  if [ $time -gt 90 ]; then
    echo "ERROR: Timed-out trying to wait for all $is_release_name demo pods to be deployed with a new image containing the image tag '$imageTag'"
    divider
    exit 1
  fi

  numberOfMatchesForImageTag=0

  if [ "${tracing_enabled}" == "true" ]; then
    allCorrespondingPods=$(oc get pods -n $namespace | grep $is_release_name | grep 3/3 | grep Running | awk '{print $1}')
  else
    allCorrespondingPods=$(oc get pods -n $namespace | grep $is_release_name | grep 1/1 | grep Running | awk '{print $1}')
  fi

  echo -e "[INFO] Total pods for ACE Integration Server:\n$allCorrespondingPods"

  echo -e "\nINFO: For ACE Integration server '$is_release_name':"
  for eachAcePod in $allCorrespondingPods; do
    imageInPod=$(oc get pod $eachAcePod -n $namespace -o json | $JQ -r '.spec.containers[0].image')
    echo "INFO: Image present in the pod '$eachAcePod' is '$imageInPod'"
    if [[ $imageInPod == *:$imageTag ]]; then
      echo "INFO: Image tag matches.."
      numberOfMatchesForImageTag=$((numberOfMatchesForImageTag + 1))
    else
      echo "INFO: Image tag '$imageTag' is not present in the image of the pod '$eachAcePod'"
    fi
  done

  echo -e "\nINFO: Total $is_release_name demo pods deployed with new image: $numberOfMatchesForImageTag"
  echo -e "\nINFO: All current $is_release_name demo pods are:\n"
  oc get pods -n $namespace | grep $is_release_name | grep Running
  if [[ $? -eq 1 ]]; then
    echo -e "No pods found for $is_release_name yet"
  fi
  if [[ $numberOfMatchesForImageTag != "$numberOfReplicas" ]]; then
    echo -e "\nINFO: Not all $is_release_name pods have been deployed with the new image having the image tag '$imageTag', retrying for upto 10 minutes for new $is_release_name demo pods to be deployed with new image. Waited ${time} minute(s)."
    sleep 10
  else
    echo -e "\nINFO: All $is_release_name demo pods have been deployed with the new image"
  fi
  time=$((time + 1))
  divider
done

GOT_SERVICE=false
for i in $(seq 1 30); do
  if oc get svc ${is_release_name}-is -n ${namespace}; then
    GOT_SERVICE=true
    break
  else
    echo "Waiting for ace api service named '${is_release_name}-is' (Attempt $i of 30)."
    echo "Checking again in 10 seconds..."
    sleep 10
  fi
done
echo $GOT_SERVICE
if [[ "$GOT_SERVICE" == "false" ]]; then
  echo -e "[ERROR] ${CROSS} ace api integration server service doesn't exist"
  exit 1
fi
