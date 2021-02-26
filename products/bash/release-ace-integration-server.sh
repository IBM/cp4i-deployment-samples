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
#   -c : <ace_policy_names> (boolean), Parameter for changing ace config
#   -d : <POLICY_PROJECT_TYPE> (string), Policyproject configuration, Defaults to "policyproject-ddd-dev"
#   -i : <is_image_name> (string), Defaults to "image-registry.openshift-image-registry.svc:5000/cp4i/ace-11.0.0.9-r2:new-1"
#   -n : <namespace> (string), Defaults to "cp4i"
#   -p : <ace_replicas> (int), allow changing the number of pods (replicas), Defaults to 2
#   -r : <is_release_name> (string), Defaults to "ace-is"
#   -t : <tracing_enabled> (boolean), optional flag to enable tracing, Defaults to false
#   -z : <tracing_namespace> (string), Defaults to "-n namespace"
#
# USAGE:
#   With defaults values
#     ./release-ace-integration-server.sh
#
#   Overriding the namespace and release-name
#     ./release-ace-integration-server -d policyproject-ddd-test -n cp4i -r cp4i-bernie-ace

function divider() {
  echo -e "\n-------------------------------------------------------------------------------------------------------------------\n"
}

function usage() {
  echo "Usage: $0 -c <ace_policy_names> -d <POLICY_PROJECT_TYPE> -i <is_image_name> -n <namespace> -p <ace_replicas> -r <is_release_name> -t -z <tracing_namespace>"
  divider
  exit 1
}

tick="\xE2\x9C\x85"
cross="\xE2\x9D\x8C"
namespace="cp4i"
is_image_name=""
is_release_name="ace-is"
tracing_enabled="false"
tracing_namespace=""
CURRENT_DIR=$(dirname $0)
POLICY_PROJECT_TYPE="policyproject-ddd-dev"
ace_replicas="2"
echo "Current directory: $CURRENT_DIR"

while getopts "c:d:i:n:p:r:tz:" opt; do
  case ${opt} in
  c)
    ace_policy_names="$OPTARG"
    ;;
  d)
    POLICY_PROJECT_TYPE="$OPTARG"
    ;;
  i)
    is_image_name="$OPTARG"
    ;;
  n)
    namespace="$OPTARG"
    ;;
  p)
    ace_replicas=$OPTARG
    ;;
  r)
    is_release_name="$OPTARG"
    ;;
  t)
    tracing_enabled=true
    ;;
  z)
    tracing_namespace="$OPTARG"
    ;;
  \?)
    usage
    ;;
  esac
done

if [ "$tracing_enabled" == "true" ]; then
  if [ -z "$tracing_namespace" ]; then tracing_namespace=${namespace}; fi
else
  # assigning value to tracing_namespace b/c empty values causes CR to throw an error
  tracing_namespace=${namespace}
fi

if [[ -z "${ace_policy_names// /}" ]]; then
  ace_policy_names="[keystore-ddd, $POLICY_PROJECT_TYPE, serverconf-ddd, setdbparms-ddd, application.kdb, application.sth, application.jks]"
fi

echo -e "\nINFO: ACE policy configurations: '$ace_policy_names'"

# ------------------------------------------------ FIND IMAGE TAG --------------------------------------------------

imageTag=${is_image_name##*:}

echo "INFO: Image tag found for '$is_release_name' is '$imageTag'"
echo "INFO: Image is '$is_image_name'"
echo "INFO: Release name is: '$is_release_name'"

if [[ -z "$imageTag" ]]; then
  echo "ERROR: Failed to extract image tag from the end of '$is_image_name'"
  exit 1
fi

echo "[INFO] tracing is set to $tracing_enabled"

echo -e "INFO: Going ahead to apply the CR for '$is_release_name'"

divider

cat <<EOF | oc apply -f -
apiVersion: appconnect.ibm.com/v1beta1
kind: IntegrationServer
metadata:
  name: ${is_release_name}
  namespace: ${namespace}
spec:
  adminServerSecure: true
  configurations: $ace_policy_names
  designerFlowsOperationMode: disabled
  license:
    accept: true
    license: L-APEH-BTHFYQ
    use: CloudPakForIntegrationNonProduction
  pod:
   containers:
     runtime:
       image: ${is_image_name}
       resources:
         limits:
           cpu: 300m
           memory: 300Mi
         requests:
           cpu: 300m
           memory: 300Mi
  replicas: ${ace_replicas}
  router:
    timeout: 120s
  service:
    endpointType: https
  useCommonServices: true
  version: 11.0.0.10-r3-eus
  tracing:
    enabled: ${tracing_enabled}
    namespace: ${tracing_namespace}
EOF

if [[ "$?" != "0" ]]; then
  echo -e "$cross [ERROR] Failed to apply IntegrationServer CR"
  exit 1
fi

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
