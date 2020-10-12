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
#   -r : <release-name> (string), Defaults to "ademo"
#   -t : optional flag to enable tracing
#
# USAGE:
#   With defaults values
#     ./release-apic.sh
#
#   Overriding the namespace and release-name
#     ./release-apic -n cp4i-prod -r prod

function usage {
    echo "Usage: $0 -n <namespace> -r <release-name> [-t]"
}

namespace="cp4i"
release_name="ademo"
tracing="false"
production="false"

while getopts "n:r:tp" opt; do
  case ${opt} in
    n ) namespace="$OPTARG"
      ;;
    r ) release_name="$OPTARG"
      ;;
    t ) tracing=true
      ;;
    p ) production="true"
    ;;
    \? ) usage; exit
      ;;
  esac
done

echo "INFO: Tracing support currently disabled"
tracing="false"
profile="n3xc4.m16"
if [[ "$production" == "true" ]]
then 
echo "Production Mode Enabled"
profile="n12xc4.m12"

fi
cat << EOF | oc apply -f -
apiVersion: apiconnect.ibm.com/v1beta1
kind: APIConnectCluster
metadata:
  name: ${release_name}
  namespace: ${namespace}
  labels:
    app.kubernetes.io/instance: apiconnect
    app.kubernetes.io/managed-by: ibm-apiconnect
    app.kubernetes.io/name: apiconnect-production
spec:
  version: 10.0.1.0
  license:
    accept: true
    use: production
  profile: ${profile}
  gateway:
    openTracing:
      enabled: ${tracing}
      odTracingNamespace: ${namespace}
EOF
