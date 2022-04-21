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
#   -a : <HA_ENABLED>, default to false
#   -b : <block-storage-class> (string), Default to "ibmc-block-gold"
#
# USAGE:
#   With defaults values
#     ./release-mq.sh
#
#   Overriding the namespace and release-name
#     ./release-mq.sh -n cp4i -r mq-demo -i image-registry.openshift-image-registry.svc:5000/cp4i/mq-ddd -q mq-qm  -a {HA_ENABLED}

tick="\xE2\x9C\x85"
cross="\xE2\x9D\x8C"
namespace="cp4i"
release_name="mq-demo"
qm_name="QUICKSTART"
tracing_namespace=""
tracing_enabled="false"
CURRENT_DIR=$(dirname $0)
HA_ENABLED="false"
block_storage="ibmc-block-gold"

function divider() {
  echo -e "\n-------------------------------------------------------------------------------------------------------------------\n"
}

function usage() {
  echo "Usage: $0 -n <namespace> -r <release_name> -i <image_name> -q <qm_name> -z <tracing_namespace> [-t]"
  divider
  exit 1
}

while getopts "b:n:r:i:q:z:a:t" opt; do
  case ${opt} in
  b)
    block_storage="$OPTARG"
    ;;
  n)
    namespace="$OPTARG"
    ;;
  r)
    release_name="$OPTARG"
    ;;
  i)
    image_name="$OPTARG"
    ;;
  q)
    qm_name="$OPTARG"
    ;;
  z)
    tracing_namespace="$OPTARG"
    ;;
  t)
    tracing_enabled=true
    ;;
  a)
    HA_ENABLED="$OPTARG"
    ;;
  \?)
    usage
    ;;
  esac
done

source $CURRENT_DIR/license-helper.sh
echo "[DEBUG] MQ license: $(getMQLicense $namespace)"

echo "Current directory: $CURRENT_DIR"
echo "Namespace: $namespace"

# when called from install.sh
if [ "$tracing_enabled" == "true" ]; then
  if [ -z "$tracing_namespace" ]; then tracing_namespace=${namespace}; fi
else
  # assigning value to tracing_namespace b/c empty values causes CR to throw an error
  tracing_namespace=${namespace}
fi

echo "[INFO] tracing is set to $tracing_enabled"

if [[ "$release_name" =~ "ddd" ]]; then
  numberOfContainers=3
elif [[ "$release_name" =~ "eei" ]]; then
  numberOfContainers=1
fi

# -------------------------------------- INSTALL JQ ---------------------------------------------------------------------

divider

echo -e "\nINFO: Checking if jq is pre-installed..."
jqInstalled=false
jqVersionCheck=$(jq --version)

if [ $? -ne 0 ]; then
  jqInstalled=false
else
  jqInstalled=true
fi

JQ=jq
if [[ "$jqInstalled" == "false" ]]; then
  echo "INFO: JQ is not installed, installing jq..."
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "INFO: Installing on linux"
    wget -O jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64
    chmod +x ./jq
    JQ=./jq
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    echo "INFO: Installing on MAC"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
    brew install jq
  fi
fi

echo -e "\nINFO: Installed JQ version is $($JQ --version)"

json=$(oc get configmap -n $namespace operator-info -o json 2>/dev/null)
if [[ $? == 0 ]]; then
  METADATA_NAME=$(echo $json | tr '\r\n' ' ' | $JQ -r '.data.METADATA_NAME')
  METADATA_UID=$(echo $json | tr '\r\n' ' ' | $JQ -r '.data.METADATA_UID')
fi

if [ "$HA_ENABLED" == "false" ]; then
  qmStorageAvailability="
    storage:
      queueManager:
        type: ephemeral
  "
else
  qmStorageAvailability="
    availability:
      type: NativeHA
    storage:
      defaultClass: ${block_storage}
      queueManager:
        type: persistent-claim
  "
fi

if [ -z $image_name ]; then
  time=0
  until cat <<EOF | oc apply -f -; do
apiVersion: mq.ibm.com/v1beta1
kind: QueueManager
metadata:
  name: ${release_name}
  namespace: ${namespace}
  $(if [[ ! -z ${METADATA_UID} && ! -z ${METADATA_NAME} ]]; then
    echo "ownerReferences:
    - apiVersion: integration.ibm.com/v1beta1
      kind: Demo
      name: ${METADATA_NAME}
      uid: ${METADATA_UID}"
  fi)
spec:
  license:
    accept: true
    license: $(getMQLicense $namespace)
    use: NonProduction
  queueManager:
    name: ${qm_name}
${qmStorageAvailability}
  template:
    pod:
      containers:
        - env:
            - name: MQSNOAUT
              value: 'yes'
          name: qmgr
  version: 9.2.4.0-r1
  web:
    enabled: true
  tracing:
    enabled: ${tracing_enabled}
    namespace: ${tracing_namespace}
EOF
    if [ $time -gt 10 ]; then
      echo "ERROR: Exiting installation as timeout waiting for QueueManager to be created"
      exit 1
    fi
    echo "INFO: Waiting up to 10 minutes for QueueManager to be created. Waited ${time} minute(s)."
    time=$((time + 1))
    sleep 60
  done
else

  # --------------------------------------------------- FIND IMAGE TAG ---------------------------------------------------

  divider

  imageTag=${image_name##*:}

  echo "INFO: Image tag found for '$release_name' is '$imageTag'"
  echo "INFO: Image is '$image_name'"
  echo "INFO: Release name is: '$release_name'"

  if [[ -z "$imageTag" ]]; then
    echo "ERROR: Failed to extract image tag from the end of '$image_name'"
    exit 1
  fi

  echo "INFO: Setting up certs for MQ TLS"
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    QM_KEY=$(base64 -w0 $CURRENT_DIR/mq/createcerts/server.key)
    QM_CERT=$(base64 -w0 $CURRENT_DIR/mq/createcerts/server.crt)
    APP_CERT=$(base64 -w0 $CURRENT_DIR/mq/createcerts/application.crt)
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    QM_KEY=$(base64 $CURRENT_DIR/mq/createcerts/server.key)
    QM_CERT=$(base64 $CURRENT_DIR/mq/createcerts/server.crt)
    APP_CERT=$(base64 $CURRENT_DIR/mq/createcerts/application.crt)
  fi


  cat <<EOF | oc apply -f -
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
      SecurityPolicy=UserExternal
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
  if [[ "$?" != "0" ]]; then
    echo -e "$cross [ERROR] Failed to apply ConfigMap/Secret for MQ TLS"
    exit 1
  fi

  echo -e "INFO: Going ahead to apply the CR for '$release_name'"

  divider

  time=0
  until cat <<EOF | oc apply -f -; do
apiVersion: mq.ibm.com/v1beta1
kind: QueueManager
metadata:
  name: ${release_name}
  namespace: ${namespace}
  $(if [[ ! -z ${METADATA_UID} && ! -z ${METADATA_NAME} ]]; then
    echo "ownerReferences:
    - apiVersion: integration.ibm.com/v1beta1
      kind: Demo
      name: ${METADATA_NAME}
      uid: ${METADATA_UID}"
  fi)
spec:
  license:
    accept: true
    license: $(getMQLicense $namespace)
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
${qmStorageAvailability}
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
  version: 9.2.4.0-r1
  web:
    enabled: true
  tracing:
    enabled: ${tracing_enabled}
    namespace: ${tracing_namespace}
EOF
    if [ $time -gt 10 ]; then
      echo "ERROR: Exiting installation as timeout waiting for QueueManager to be created"
      exit 1
    fi
    echo "INFO: Waiting up to 10 minutes for QueueManager to be created. Waited ${time} minute(s)."
    time=$((time + 1))
    sleep 60
  done

  divider

  # -------------------------------------- CHECK FOR NEW IMAGE DEPLOYMENT STATUS ------------------------------------------

  numberOfReplicas=1
  numberOfMatchesForImageTag=0
  time=0

  echo "INFO: Total number of pod for $release_name should be $numberOfReplicas"

  divider

  # wait for 10 minutes for all replica pods to be deployed with new image
  while [ $numberOfMatchesForImageTag -ne $numberOfReplicas ]; do
    if [ $time -gt 60 ]; then
      echo "ERROR: Timed-out trying to wait for all $release_name demo pod(s) to be deployed with a new image containing the image tag '$imageTag'"
      divider
      exit 1
    fi

    numberOfMatchesForImageTag=0

    if [ "${tracing_enabled}" == "true" ]; then
      allCorrespondingPods=$(oc get pods -n $namespace | grep $release_name | grep 3/3 | grep Running | awk '{print $1}')
    else
      allCorrespondingPods=$(oc get pods -n $namespace | grep $release_name | grep 1/1 | grep Running | awk '{print $1}')
    fi

    echo "[INFO] Total pods for mq $allCorrespondingPods"

    for eachMQPod in $allCorrespondingPods; do
      echo -e "\nINFO: For MQ demo pod '$eachMQPod':"
      imageInPod=$(oc get pod $eachMQPod -n $namespace -o json | $JQ -r '.spec.containers[0].image')
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
    oc get pods -n $namespace | grep $release_name | grep Running
    if [[ $? -eq 1 ]]; then
      echo -e "No pods found for '$release_name' yet"
    fi
    if [[ $numberOfMatchesForImageTag != "$numberOfReplicas" ]]; then
      echo -e "\nINFO: Not all $release_name pods have been deployed with the new image having the image tag '$imageTag', retrying for upto 10 minutes for new $release_name demo pods to be deployed with new image. Waited ${time} minute(s)."
      sleep 10
    else
      echo -e "\nINFO: All $release_name demo pods have been deployed with the new image"
    fi
    time=$((time + 1))
    divider
  done
fi
