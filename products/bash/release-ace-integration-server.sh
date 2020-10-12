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
#   -r : <is_release_name> (string), Defaults to "ace-is"
#   -i : <is_image_name> (string), Defaults to "image-registry.openshift-image-registry.svc:5000/cp4i/ace-11.0.0.9-r2:new-1"
#   -z : <tracing_namespace> (string), Defaults to "-n namespace"
#   -t : <tracing_enabled> (boolean), optional flag to enable tracing, Defaults to false
#
# USAGE:
#   With defaults values
#     ./release-ace-integration-server.sh
#
#   Overriding the namespace and release-name
#     ./release-ace-integration-server -n cp4i -r cp4i-bernie-ace

function usage {
  echo "Usage: $0 -n <namespace> -r <is_release_name> -i <is_image_name> -t -z <tracing_namespace>"
  exit 1
}

namespace="cp4i"
is_release_name="ace-is"
is_image_name=""
tracing_namespace=""
tracing_enabled="false"
CURRENT_DIR=$(dirname $0)
echo "Current directory: $CURRENT_DIR"

while getopts "n:r:i:z:t" opt; do
  case ${opt} in
  n)
    namespace="$OPTARG"
    ;;
  r)
    is_release_name="$OPTARG"
    ;;
  i)
    is_image_name="$OPTARG"
    ;;
  z)
    tracing_namespace="$OPTARG"
    ;;
  t)
    tracing_enabled=true
    ;;
  \?)
    usage
    exit
    ;;
  esac
done

echo "INFO: Tracing support currently disabled"
tracing_enabled=false

if [ "$tracing_enabled" == "true" ] ; then
   if [ -z "$tracing_namespace" ]; then tracing_namespace=${namespace} ; fi
else
    # assgining value to tracing_namespace b/c empty values causes CR to throw an error
    tracing_namespace=${namespace}
fi

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

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

cat <<EOF | oc apply -f -
apiVersion: appconnect.ibm.com/v1beta1
kind: IntegrationServer
metadata:
  name: ${is_release_name}
  namespace: ${namespace}
spec:
  pod:
   containers:
     runtime:
       image: ${is_image_name}
  configurations:
  - ace-keystore
  - ace-policyproject-ddd
  - ace-serverconf
  - ace-setdbparms
  - application.kdb
  - application.sth
  - application.jks
  designerFlowsOperationMode: disabled
  license:
    accept: true
    license: L-APEH-BPUCJK
    use: CloudPakForIntegrationProduction
  replicas: 2
  router:
    timeout: 120s
  service:
    endpointType: https
  useCommonServices: true
  version: 11.0.0.10-r1
  tracing:
    enabled: ${tracing_enabled}
    namespace: ${tracing_namespace}
EOF

timer=0
echo "[INFO] tracing is set to $tracing_enabled"
if [ "$tracing_enabled" == "true" ]; then
  while ! oc get secrets icp4i-od-store-cred -n ${namespace}; do
    echo "Waiting for the secret icp4i-od-store-cred to get created"
    if [ $timer -gt 5 ]; then
      echo "Secret icp4i-od-store-cred didn't get created in  ${namespace}, going to create the secret next "
      break
      timer=$((timer + 1))
    fi
    sleep 60
  done

  # -------------------------------------- Register Tracing ---------------------------------------------------------------------
  if  ! oc get secrets icp4i-od-store-cred -n ${namespace} ; then
    echo "[INFO] secret icp4i-od-store-cred does not exist in ${namespace}, running tracing registration"
    echo "Tracing_Namespace= ${tracing_namespace}"
    echo "Namespace= ${namespace}"
    if ! ${CURRENT_DIR}/register-tracing.sh -n $tracing_namespace -a ${namespace} ; then
      echo "INFO: Running with test environment flag"
      echo "ERROR: Failed to register tracing in project '$namespace'"
      exit 1
    fi
  else
    echo "[INFO] secret icp4i-od-store-cred exist, no need to run tracing registration"
  fi
fi
# -------------------------------------- INSTALL JQ ---------------------------------------------------------------------

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

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

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

# -------------------------------------- FIND TOTAL ACE REPLICAS DEPLOYED -----------------------------------------------

numberOfReplicas=$(oc get integrationservers $is_release_name -n $namespace -o json | $JQ -r '.spec.replicas')
echo "INFO: Number of Replicas for '$is_release_name' is $numberOfReplicas"
echo -e "\nINFO: Total number of ACE integration server '$is_release_name' related pods after deployment should be $numberOfReplicas"
echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

# -------------------------------------- CHECK FOR NEW IMAGE DEPLOYMENT STATUS ------------------------------------------

echo "INFO: Image tag for '$is_release_name' is '$imageTag'"

numberOfMatchesForImageTag=0
time=0

# wait for 10 minutes for all replica pods to be deployed with new image
while [ $numberOfMatchesForImageTag -ne $numberOfReplicas ]; do
  if [ $time -gt 15 ]; then
    echo "ERROR: Timed-out trying to wait for all $is_release_name demo pods to be deployed with a new image containing the image tag '$imageTag'"
    echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"
    exit 1
  fi

  numberOfMatchesForImageTag=0

  if [ "${tracing_enabled}" == "true" ]; then
    allCorrespondingPods=$(oc get pods -n $namespace | grep $is_release_name | grep 3/3 | grep Running | awk '{print $1}')
  else
    allCorrespondingPods=$(oc get pods -n $namespace | grep $is_release_name | grep 1/1 | grep Running | awk '{print $1}')
  fi

  echo "[INFO] Total pods for ACE Integration Server $allCorrespondingPods"

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
  oc get pods -n $namespace | grep $is_release_name | grep 1/1 | grep Running
  if [[ $? -eq 1 ]]; then
    echo -e "No Ready and Running pods found for $is_release_name yet"
  fi
  if [[ $numberOfMatchesForImageTag != "$numberOfReplicas" ]]; then
    echo -e "\nINFO: Not all $is_release_name pods have been deployed with the new image having the image tag '$imageTag', retrying for upto 10 minutes for new $is_release_name demo pods te be deployed with new image. Waited ${time} minute(s)."
    sleep 60
  else
    echo -e "\nINFO: All $is_release_name demo pods have been deployed with the new image"
  fi
  time=$((time + 1))
  echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------"
done
