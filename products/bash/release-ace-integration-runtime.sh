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
#   -r : <release_name> (string), Defaults to "ace-runtime"
#   -b : <bar file URL> (string), an array of bar file urls, defaults to "[]"
#   -c : <configurations> (string), an array of configuration names, defaults to "[]"
#
# USAGE:
#   With defaults values
#     ./release-ace-integration-runtime.sh
#
#   Overriding the namespace and release-name
#     ./release-ace-integration-runtime.sh -n cp4i -r cp4i-bernie-ace

CURRENT_DIR=$(dirname $0)
source $CURRENT_DIR/utils.sh
namespace="cp4i"
release_name="ace-runtime"
configurations="[]"
bar_file_urls="[]"

function divider() {
  echo -e "\n-------------------------------------------------------------------------------------------------------------------\n"
}

function usage() {
  echo "Usage: $0 -n <namespace> -r <release_name>"
  divider
  exit 1
}

while getopts "b:c:n:r:" opt; do
  case ${opt} in
  b)
    bar_file_urls="$OPTARG"
    ;;
  c)
    configurations="$OPTARG"
    ;;
  n)
    namespace="$OPTARG"
    ;;
  r)
    release_name="$OPTARG"
    ;;
  \?)
    usage
    ;;
  esac
done

if [ "$HA_ENABLED" == "true" ]; then
  replicas="3"
  license_use="AppConnectEnterpriseProduction"
else
  replicas="1"
  license_use="CloudPakForIntegrationNonProduction"
fi

source $CURRENT_DIR/license-helper.sh
echo "[DEBUG] ACE license: $(getACELicense $namespace)"

echo "Current directory: $CURRENT_DIR"
echo "INFO: Release name is: '$release_name'"
echo -e "\nINFO: Bar file URLs: '$bar_file_urls'"
echo -e "\nINFO: Configurations: '$configurations'"
echo -e "INFO: Going ahead to apply the CR for '$release_name'"

divider

YAML=$(cat <<EOF
apiVersion: appconnect.ibm.com/v1beta1
kind: IntegrationRuntime
metadata:
  name: ${release_name}
  namespace: ${namespace}
spec:
  license:
    accept: true
    license: $(getACELicense $namespace)
    use: ${license_use}
  template:
    spec:
      containers:
        - name: runtime
          resources:
            requests:
              cpu: 300m
              memory: 368Mi
  logFormat: basic
  barURL: ${bar_file_urls}
  configurations: $configurations
  version: '12.0'
  replicas: ${replicas}
EOF
)
OCApplyYAML "$namespace" "$YAML"



echo "Wait for the runtime to be ready"
oc wait --for=condition=ready integrationruntimes.appconnect.ibm.com -n ${namespace} ${release_name} --timeout 10m

GOT_SERVICE=false
for i in $(seq 1 30); do
  if oc get svc ${release_name}-ir -n ${namespace}; then
    GOT_SERVICE=true
    break
  else
    echo "Waiting for ace api service named '${release_name}-ir' (Attempt $i of 30)."
    echo "Checking again in 10 seconds..."
    sleep 10
  fi
done
echo $GOT_SERVICE
if [[ "$GOT_SERVICE" == "false" ]]; then
  echo -e "[ERROR] ${CROSS} ace api integration server service doesn't exist"
  exit 1
fi
