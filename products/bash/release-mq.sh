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
#   -n : <namespace> (string), Defaults to "cp4i"
#   -r : <release_name> (string), Defaults to "mq-demo"
#   -i : <image_name> (string)
#   -q : <qm_name> (string), Defaults to "QUICKSTART"
#   -z : <tracing_namespace> (string), Defaults to "namespace"
#   -t : <tracing_enabled> (boolean), optional flag to enable tracing, Defaults to false
#
# USAGE:
#   With defaults values
#     ./release-mq.sh
#
#   Overriding the namespace and release-name
#     ./release-mq -n cp4i -r mq-demo -i image-registry.openshift-image-registry.svc:5000/cp4i/mq-ddd -q mq-qm

function usage {
    echo "Usage: $0 -n <namespace> -r <release_name> -i <image_name> -q <qm_name> -z <tracing_namespace> [-t]"
    exit 1
}

namespace="cp4i"
release_name="mq-demo"
qm_name="QUICKSTART"
tracing_namespace=""
tracing_enabled="false"
CURRENT_DIR=$(dirname $0)
echo "Current directory: $CURRENT_DIR"
echo "Namespace: $namespace"

while getopts "n:r:i:q:z:t" opt; do
  case ${opt} in
    n ) namespace="$OPTARG"
      ;;
    r ) release_name="$OPTARG"
      ;;
    i ) image_name="$OPTARG"
      ;;
    q ) qm_name="$OPTARG"
      ;;
    z ) tracing_namespace="$OPTARG"
      ;;
    t ) tracing_enabled=true
      ;;
    \? ) usage; exit
      ;;
  esac
done

echo "INFO: Tracing support currently disabled"
tracing_enabled=false


# when called from install.sh
if [ "$tracing_enabled" == "true" ] ; then
   if [ -z "$tracing_namespace" ]; then tracing_namespace=${namespace} ; fi
else
    # assgining value to tracing_namespace b/c empty values causes CR to throw an error
    tracing_namespace=${namespace}
fi

echo "[INFO] tracing is set to $tracing_enabled"

if [ -z $image_name ]; then

cat << EOF | oc apply -f -
apiVersion: mq.ibm.com/v1beta1
kind: QueueManager
metadata:
  name: ${release_name}
  namespace: ${namespace}
spec:
  license:
    accept: true
    license: L-RJON-BN7PN3
    use: NonProduction
  queueManager:
    name: ${qm_name}
    storage:
      queueManager:
        type: ephemeral
  template:
    pod:
      containers:
        - env:
            - name: MQSNOAUT
              value: 'yes'
          name: qmgr
  version: 9.2.0.0-r1
  web:
    enabled: true
  tracing:
    enabled: ${tracing_enabled}
    namespace: ${tracing_namespace}
EOF

else

# --------------------------------------------------- FIND IMAGE TAG ---------------------------------------------------

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

imageTag=${image_name##*:}

echo "INFO: Image tag found for '$release_name' is '$imageTag'"
echo "INFO: Image is '$image_name'"
echo "INFO: Release name is: '$release_name'"

if [[ -z "$imageTag" ]]; then
  echo "ERROR: Failed to extract image tag from the end of '$image_name'"
  exit 1
fi

echo "INFO: Setting up certs for MQ TLS"
QM_KEY=$(cat $CURRENT_DIR/mq/createcerts/server.key | base64 -w0)
QM_CERT=$(cat $CURRENT_DIR/mq/createcerts/server.crt | base64 -w0)
APP_CERT=$(cat $CURRENT_DIR/mq/createcerts/application.crt | base64 -w0)

cat << EOF | oc apply -f -
---
kind: ConfigMap
apiVersion: v1
metadata:
  name: mtlsmqsc
  namespace: $namespace
data:
  example.ini: |-
    Service:
      Name=AuthorizationService
      EntryPoints=14
      SecurityPolicy=User
---
kind: Secret
apiVersion: v1
metadata:
  name: mqcert
  namespace: $namespace
data:
  tls.key: $QM_KEY
  tls.crt: $QM_CERT
  app.crt: $APP_CERT
type: Opaque
EOF


echo -e "INFO: Going ahead to apply the CR for '$release_name'"

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

cat << EOF | oc apply -f -
apiVersion: mq.ibm.com/v1beta1
kind: QueueManager
metadata:
  name: ${release_name}
  namespace: ${namespace}
spec:
  license:
    accept: true
    license: L-RJON-BN7PN3
    use: NonProduction
  pki:
    keys:
      - name: default
        secret:
          items:
            - tls.key
            - tls.crt
          secretName: mqcert
    trust:
      - name: app
        secret:
          items:
            - app.crt
          secretName: mqcert
  queueManager:
    image: ${image_name}
    imagePullPolicy: Always
    name: ${qm_name}
    storage:
      queueManager:
        type: ephemeral
    ini:
      - configMap:
          items:
            - example.ini
          name: mtlsmqsc
  template:
    pod:
      containers:
        - env:
            - name: MQS_PERMIT_UNKNOWN_ID
              value: 'true'
          name: qmgr
  version: 9.2.0.0-r1
  web:
    enabled: true
  tracing:
    enabled: ${tracing_enabled}
    namespace: ${tracing_namespace}
EOF

  # -------------------------------------- Register Tracing ---------------------------------------------------------------------
oc get secrets icp4i-od-store-cred -n ${namespace}
if [ $? -ne 0 ] && [ "$tracing_enabled" == "true"  ] ; then
 echo "[INFO] secret icp4i-od-store-cred does not exist in ${namespace}, running tracing registration"
    echo "Tracing_Namespace= ${tracing_namespace}"
    echo "Namespace= ${namespace}"
      if ! ${CURRENT_DIR}/register-tracing.sh -n $tracing_namespace -a ${namespace} ; then
        echo "INFO: Running with test environment flag"
        echo "ERROR: Failed to register tracing in project '$namespace'"
        exit 1
      fi
 else
    if [ "$tracing_enabled" == "false" ]; then
        echo "[INFO] Tracing Registration not need. Tracing set to $tracing_enabled"
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
  else
    jqInstalled=true
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
    fi
  fi

  echo -e "\nINFO: Installed JQ version is $(./jq --version)"

  echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

  # -------------------------------------- CHECK FOR NEW IMAGE DEPLOYMENT STATUS ------------------------------------------

  numberOfReplicas=1
  numberOfMatchesForImageTag=0
  time=0

  echo "INFO: Total number of pod for $release_name should be $numberOfReplicas"

  echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

  # wait for 10 minutes for all replica pods to be deployed with new image
  while [ $numberOfMatchesForImageTag -ne $numberOfReplicas ]; do
    if [ $time -gt 10 ]; then
      echo "ERROR: Timed-out trying to wait for all $release_name demo pod(s) to be deployed with a new image containing the image tag '$imageTag'"
      echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"
      exit 1
    fi

    numberOfMatchesForImageTag=0

  if [ "${tracing_enabled}" == "true" ]; then
    allCorrespondingPods=$(oc get pods -n $namespace | grep $release_name | grep 3/3 | grep Running | awk '{print $1}')
  else
    allCorrespondingPods=$(oc get pods -n $namespace | grep $release_name | grep 1/1 | grep Running | awk '{print $1}')
  fi

  echo "[INFO] Total pods for mq $allCorrespondingPods"

    for eachMQPod in $allCorrespondingPods
      do
        echo -e "\nINFO: For MQ demo pod '$eachMQPod':"
        imageInPod=$(oc get pod $eachMQPod -n $namespace -o json | ./jq -r '.spec.containers[0].image')
        echo "INFO: Image present in the pod '$eachMQPod' is '$imageInPod'"
        if [[ $imageInPod == *:$imageTag ]]; then
          echo "INFO: Image tag matches.."
          numberOfMatchesForImageTag=$((numberOfMatchesForImageTag + 1))
        else
          echo "INFO: Image tag '$imageTag' is not present in the image of the MQ demo pod '$eachMQPod'"
        fi
    done

    echo -e "\nINFO: Total $release_name demo pods deployed with new image: $numberOfMatchesForImageTag"
    echo -e "\nINFO: All current $release_name demo pods are:\n"
    oc get pods -n $namespace | grep $release_name | grep 1/1 | grep Running
    if [[ $? -eq 1 ]]; then
      echo -e "No Ready and Running pods found for '$release_name' yet"
    fi
    if [[ $numberOfMatchesForImageTag != "$numberOfReplicas" ]]; then
      echo -e "\nINFO: Not all $release_name pods have been deployed with the new image having the image tag '$imageTag', retrying for upto 10 minutes for new $release_name demo pods to be deployed with new image. Waited ${time} minute(s)."
      sleep 60
    else
      echo -e "\nINFO: All $release_name demo pods have been deployed with the new image"
    fi
    time=$((time + 1))
    echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------"
  done
fi
