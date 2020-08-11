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

function usage {
    echo "Usage: $0 -n <namespace> -r <release-name>"
}

namespace="cp4i"
release_name="es-demo"

while getopts "n:r:" opt; do
  case ${opt} in
    n ) namespace="$OPTARG"
      ;;
    r ) release_name="$OPTARG"
      ;;
    \? ) usage; exit
      ;;
  esac
done

cat << EOF | oc apply -f -
apiVersion: eventstreams.ibm.com/v1beta1
kind: EventStreams
metadata:
  name: ${release_name}
  namespace: ${namespace}
spec:
  version: 10.0.0
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
      replicas: 1
      config:
        inter.broker.protocol.version: '2.5'
        interceptor.class.names: com.ibm.eventstreams.interceptors.metrics.ProducerMetricsInterceptor
        log.message.format.version: '2.5'
        offsets.topic.replication.factor: 1
        transaction.state.log.min.isr: 1
        transaction.state.log.replication.factor: 1
      listeners:
        plain: {}
      metrics: {}
      storage:
        type: ephemeral
    zookeeper:
      replicas: 1
      metrics: {}
      storage:
        type: ephemeral
EOF
