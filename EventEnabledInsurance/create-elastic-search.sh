#!/bin/bash
#******************************************************************************
# Licensed Materials - Property of IBM
# (c) Copyright IBM Corporation 2019. All Rights Reserved.
#
# Note to U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.
#******************************************************************************

# PREREQUISITES:
#   - Logged into cluster on the OC CLI (https://docs.openshift.com/container-platform/4.4/cli_reference/openshift_cli/getting-started-cli.html)
#
# PARAMETERS:
#   -n : <ELASTIC_NAMESPACE> (string), Defaults to 'elasticsearch'
#   -n : <NAMESPACE> (string), Defaults to 'cp4i'
#
#   With defaults values
#     ./create-elastic-search.sh
#
#   With overridden values
#     ./create-elastic-search.sh -n <NAMESPACE> -e <ELASTIC_NAMESPACE>

function usage() {
  echo "Usage: $0 -n <NAMESPACE> -e <ELASTIC_NAMESPACE>"
  exit 1
}

tick="\xE2\x9C\x85"
cross="\xE2\x9D\x8C"
all_done="\xF0\x9F\x92\xAF"
SUFFIX="eei"
ELASTIC_CR_NAME="elasticsearch-$SUFFIX"
NAMESPACE="cp4i"
ELASTIC_NAMESPACE="elasticsearch"
ELASTIC_SUBCRIPTION_NAME="elastic-cloud-eck"

while getopts "n:e:" opt; do
  case ${opt} in
  n)
    NAMESPACE="$OPTARG"
    ;;
  e)
    ELASTIC_NAMESPACE="$OPTARG"
    ;;
  \?)
    usage
    ;;
  esac
done

if [[ -z "${NAMESPACE// }" || -z "${ELASTIC_NAMESPACE// }" ]]; then
  echo -e "$cross ERROR: Mandatory parameters are missing"
  usage
fi

CURRENT_DIR=$(dirname $0)
echo "INFO: Current directory: '$CURRENT_DIR'"
echo "INFO: Namespace: '$ELASTIC_NAMESPACE'"
echo "INFO: Elastic search CR name: '$ELASTIC_CR_NAME'"
echo "INFO: Namespace: $NAMESPACE"
echo "INFO: Elastic search subscription: '$ELASTIC_SUBCRIPTION_NAME'"
echo "INFO: Suffix is: '$SUFFIX'"

oc create namespace $ELASTIC_NAMESPACE

oc project $ELASTIC_NAMESPACE

function output_time {
  SECONDS=${1}
  if((SECONDS>59));then
    printf "%d minutes, %d seconds" $((SECONDS/60)) $((SECONDS%60))
  else
    printf "%d seconds" $SECONDS
  fi
}

function wait_for_subscription {
  ELASTIC_NAMESPACE=${1}
  NAME=${2}

  phase=""
  time=0
  wait_time=5
  until [[ "$phase" == "Succeeded" ]]; do
    csv=$(oc get subscription -n ${ELASTIC_NAMESPACE} ${NAME} -o json | jq -r .status.currentCSV)
    wait=0
    if [[ "$csv" == "null" ]]; then
      echo "Waited for $(output_time $time), not got csv for subscription $NAME"
      wait=1
    else
      phase=$(oc get csv -n ${ELASTIC_NAMESPACE} $csv -o json | jq -r .status.phase)
      if [[ "$phase" != "Succeeded" ]]; then
        echo "Waited for $(output_time $time), csv $csv not in Succeeded phase, currently: $phase"
        wait=1
      fi
    fi

    if [[ "$wait" == "1" ]]; then
      ((time=time+$wait_time))
      if [ $time -gt 1200 ]; then
        echo "ERROR: Failed after waiting for 20 minutes for $NAME"
        exit 1
      fi

      sleep $wait_time
    fi
  done
  echo "$NAME has succeeded"
}

cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: $ELASTIC_NAMESPACE-og
  namespace: $ELASTIC_NAMESPACE
spec:
  targetNamespaces:
    - $ELASTIC_NAMESPACE

---

apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  generation: 1
  name: $ELASTIC_SUBCRIPTION_NAME
  namespace: $ELASTIC_NAMESPACE
spec:
  channel: stable
  installPlanApproval: Automatic
  name: elastic-cloud-eck
  source: community-operators
  sourceNamespace: openshift-marketplace
  startingCSV: elastic-cloud-eck.v1.2.1
EOF

wait_for_subscription $ELASTIC_NAMESPACE $ELASTIC_SUBCRIPTION_NAME

cat <<EOF | oc apply -f -
apiVersion: elasticsearch.k8s.elastic.co/v1
kind: Elasticsearch
metadata:
  name: $ELASTIC_CR_NAME
  namespace: $ELASTIC_NAMESPACE
spec:
  version: 7.9.1
  nodeSets:
    - name: default
      config:
        node.master: true
        node.data: true
        node.ingest: true
        node.attr.attr_name: attr_value
        node.store.allow_mmap: false
      podTemplate:
        metadata:
          labels:
            name: $ELASTIC_CR_NAME
            demo: eei
        spec:
          containers:
            - name: elasticsearch
              resources:
                requests:
                  memory: 4Gi
                  cpu: 1
                limits:
                  memory: 4Gi
                  cpu: 2
      count: 3
EOF

time=0
ES_CR_STATE=$(oc get elasticsearch -n $ELASTIC_NAMESPACE $ELASTIC_CR_NAME -o json | jq -r '.status.phase')
while [ "$ES_CR_STATE" != "Ready" ]; do
  if [ $time -gt 10 ]; then
    echo "ERROR: Timed-out waiting for elastic search CR to be ready"
    echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"
    exit 1
  fi

  oc get elasticsearch -n $ELASTIC_NAMESPACE $ELASTIC_CR_NAME -o json | jq -r '.status.phase'
  echo -e "\nINFO: The elastic search CR is not yet ready, waiting for upto 10 minutes. Waited ${time} minute(s)."
  time=$((time + 1))
  sleep 60
  ES_CR_STATE=$(oc get elasticsearch -n $ELASTIC_NAMESPACE $ELASTIC_CR_NAME -o json | jq -r '.status.phase')
done

echo -e "INFO: The elastic search CR is now ready:\n"
oc get elasticsearch -n $ELASTIC_NAMESPACE

echo -e "INFO: The pods for the elastic search:\n"
oc get pods -n $ELASTIC_NAMESPACE --selector='elasticsearch.k8s.elastic.co/cluster-name='${ELASTIC_CR_NAME}''

echo -e "INFO: The elastic search service:\n"
oc get service -n $ELASTIC_NAMESPACE $ELASTIC_CR_NAME-es-http

ELASTIC_PASSWORD=$(oc get secret $ELASTIC_CR_NAME-es-elastic-user -n $ELASTIC_NAMESPACE -o go-template='{{.data.elastic | base64decode}}')
ELASTIC_USER="elastic"
echo -e "INFO: Got the password for elastic search\n"

echo -e "\nINFO: Creating secret for elastic search connector"
cat << EOF | oc apply -f -
apiVersion: v1
kind: Secret
metadata:
  namespace: $NAMESPACE
  name: eei-elastic-credential
type: Opaque
stringData:
  connector.properties: |-
    dbPassword: $ELASTIC_PASSWORD
    dbUser: $ELASTIC_USER
EOF
