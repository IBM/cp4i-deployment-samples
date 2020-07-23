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
#   -i : <image-name> (string), Defaults to "image-registry.openshift-image-registry.svc:5000/cp4i/mq-ddd"
#
# USAGE:
#   With defaults values
#     ./release-mq.sh
#
#   Overriding the namespace and release-name
#     ./release-mq -n cp4i -r demo -i image-registry.openshift-image-registry.svc:5000/cp4i/mq-ddd:some-tag

function usage {
    echo "Usage: $0 -n <namespace> -r <release-name> -i <image-name>"
}

namespace="cp4i"
release_name="demo"
image_name="image-registry.openshift-image-registry.svc:5000/cp4i/mq-ddd"

while getopts "n:r:i:" opt; do
  case ${opt} in
    n ) namespace="$OPTARG"
      ;;
    r ) release_name="$OPTARG"
      ;;
    i ) image_name="$OPTARG"
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
    image: ${image_name}
    imagePullPolicy: Always
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
EOF
