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

CURRENT_DIR=$(dirname $0)
source $CURRENT_DIR/utils.sh
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
  YAML=$(cat <<EOF
apiVersion: eventstreams.ibm.com/v1beta2
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
  adminApi: {}
  adminUI: {}
  apicurioRegistry: {}
  collector: {}
  license:
    accept: true
    use: CloudPakForIntegrationProduction
  requestIbmServices:
    iam: true
    monitoring: true
  restProducer: {}
  strimziOverrides:
    kafka:
      authorization:
        type: runas
      config:
        inter.broker.protocol.version: '2.8'
        interceptor.class.names: com.ibm.eventstreams.interceptors.metrics.ProducerMetricsInterceptor
        log.cleaner.threads: 6
        log.message.format.version: '2.8'
        num.io.threads: 24
        num.network.threads: 9
        num.replica.fetchers: 3
        offsets.topic.replication.factor: 3
      listeners:
        - authentication:
            type: scram-sha-512
          name: external
          port: 9094
          tls: true
          type: route
        - authentication:
            type: tls
          name: tls
          port: 9093
          tls: true
          type: internal
      metricsConfig:
        type: jmxPrometheusExporter
        valueFrom:
          configMapKeyRef:
            key: kafka-metrics-config.yaml
            name: metrics-config
      replicas: 3
      storage:
        class: ${storageClass}
        size: 4Gi
        type: persistent-claim
    zookeeper:
      metricsConfig:
         type: jmxPrometheusExporter
         valueFrom:
           configMapKeyRef:
             key: zookeeper-metrics-config.yaml
             name: metrics-config
      replicas: 3
      storage:
        class: ${storageClass}
        size: 2Gi
        type: persistent-claim
  version: latest
EOF
)
else
  YAML=$(cat <<EOF
apiVersion: eventstreams.ibm.com/v1beta2
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
  adminApi: {}
  adminUI: {}
  collector: {}
  license:
    accept: true
    use: CloudPakForIntegrationNonProduction
  requestIbmServices:
    iam: false
    monitoring: false
  restProducer: {}
  schemaRegistry:
    storage:
      type: ephemeral
  security:
    internalTls: NONE
  strimziOverrides:
    kafka:
      config:
        inter.broker.protocol.version: '2.8'
        interceptor.class.names: com.ibm.eventstreams.interceptors.metrics.ProducerMetricsInterceptor
        log.message.format.version: '2.8'
        offsets.topic.replication.factor: 1
        transaction.state.log.min.isr: 1
        transaction.state.log.replication.factor: 1
      listeners:
        - name: plain
          port: 9092
          tls: false
          type: internal
      metricsConfig:
        type: jmxPrometheusExporter
        valueFrom:
          configMapKeyRef:
            key: kafka-metrics-config.yaml
            name: metrics-config
      replicas: 3
      storage:
        type: ephemeral
    zookeeper:
      metricsConfig:
        type: jmxPrometheusExporter
        valueFrom:
          configMapKeyRef:
            key: zookeeper-metrics-config.yaml
            name: metrics-config
      replicas: 3
      storage:
        type: ephemeral
  version: latest
EOF
)
fi
OCApplyYAML "$namespace" "$YAML"
