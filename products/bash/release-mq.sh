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
#   -r : <release-name> (string), Defaults to "demo"
#   -t : <tracing> (string), Defaults to 'false'
#
# USAGE:
#   With defaults values
#     ./release-mq.sh
#
#   Overriding the namespace and release-name
#     ./release-mq.sh -n cp4i-prod -r prod


function usage {
    echo "Usage: $0 -n <namespace> -r <release-name> -t <tracing>"
}

namespace="cp4i"
release_name="demo"
tracing="false"

while getopts "n:r:t:" opt; do
  case ${opt} in
    n ) namespace="$OPTARG"
      ;;
    r ) release_name="$OPTARG"
      ;;
    t ) tracing="$OPTARG"
      ;;
    \? ) usage; exit
      ;;
  esac
done

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
    name: QUICKSTART
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
  version: 9.1.5.0-r2
  web:
    enabled: true
  tracing:
    enabled: ${tracing}
    namespace: ${namespace}
EOF
