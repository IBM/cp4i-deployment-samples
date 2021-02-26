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
#   -r : <release-name> (string), Defaults to "es-demo"
#
# USAGE:
#   With defaults values
#     ./release-es.sh
#
#   Overriding the namespace and release-name
#     ./release-es.sh -n cp4i-prod -r prod

function usage() {
  echo "Usage: $0 -n <namespace> -r <release-name>"
}

namespace="cp4i"
release_name="es-demo"
production="false"
storageClass=""

while getopts "n:r:pc:" opt; do
  case ${opt} in
  n)
    namespace="$OPTARG"
    ;;
  r)
    release_name="$OPTARG"
    ;;
  p)
    production="true"
    ;;
  c)
    storageClass="$OPTARG"
    ;;
  \?)
    usage
    exit
    ;;
  esac
done

json=$(oc get configmap -n $namespace operator-info -o json 2> /dev/null)
if [[ $? == 0 ]]; then
  METADATA_NAME=$(echo $json | tr '\r\n' ' ' | jq -r '.data.METADATA_NAME')
  METADATA_UID=$(echo $json | tr '\r\n' ' ' | jq -r '.data.METADATA_UID')
fi

if [ "$production" == "true" ]; then
  echo "Production Mode Enabled"
  cat <<EOF | oc apply -f -
apiVersion: eventstreams.ibm.com/v1beta1
kind: EventStreams
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
  version: 10.2.0-eus
  license:
    accept: true
    use: CloudPakForIntegrationProduction
  adminApi: {}
  adminUI: {}
  apicurioRegistry: {}
  collector: {}
  restProducer: {}
  strimziOverrides:
    kafka:
      replicas: 3
      authorization:
        type: runas
      config:
        inter.broker.protocol.version: '2.6'
        interceptor.class.names: com.ibm.eventstreams.interceptors.metrics.ProducerMetricsInterceptor
        log.cleaner.threads: 6
        log.message.format.version: '2.6'
        num.io.threads: 24
        num.network.threads: 9
        num.replica.fetchers: 3
        offsets.topic.replication.factor: 3
      listeners:
        external:
          authentication:
            type: scram-sha-512
          type: route
        tls:
          authentication:
            type: tls
      metrics: {}
      storage:
        class: ${storageClass}
        size: 4Gi
        type: persistent-claim
    zookeeper:
      replicas: 3
      metrics: {}
      storage:
        class: ${storageClass}
        size: 2Gi
        type: persistent-claim
EOF
else
  cat <<EOF | oc apply -f -
apiVersion: eventstreams.ibm.com/v1beta1
kind: EventStreams
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
  version: 10.2.0-eus
  license:
    accept: true
    use: CloudPakForIntegrationNonProduction
  adminApi: {}
  adminUI: {}
  collector: {}
  restProducer: {}
  schemaRegistry:
    storage:
      type: ephemeral
  security:
    internalTls: NONE
  strimziOverrides:
    kafka:
      replicas: 3
      config:
        inter.broker.protocol.version: '2.6'
        interceptor.class.names: com.ibm.eventstreams.interceptors.metrics.ProducerMetricsInterceptor
        log.message.format.version: '2.6'
        offsets.topic.replication.factor: 1
        transaction.state.log.min.isr: 1
        transaction.state.log.replication.factor: 1
      listeners:
        plain: {}
      metrics: {}
      storage:
        type: ephemeral
    zookeeper:
      replicas: 3
      metrics: {}
      storage:
        type: ephemeral
EOF

fi
