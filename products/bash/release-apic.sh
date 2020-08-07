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

while getopts "n:r:t" opt; do
  case ${opt} in
    n ) namespace="$OPTARG"
      ;;
    r ) release_name="$OPTARG"
      ;;
    t ) tracing=true
      ;;
    \? ) usage; exit
      ;;
  esac
done

cat << EOF | oc apply -f -
apiVersion: apiconnect.ibm.com/v1beta1
kind: APIConnectCluster
metadata:
  name: ${release_name}
  namespace: ${namespace}
spec:
  appVersion: 10.0.0.0
  license:
    accept: true
    use: production
  profile: n3xc4.m16
  gateway:
    openTracing:
      enabled: ${tracing}
      odTracingNamespace: ${namespace}
EOF

time=0
while [ ! "$(oc get cm -n ${namespace} ${release_name}-a7s-mtls-gw)" ]; do
  if [ $time -gt 30 ]; then
    echo "ERROR: No configmap called ${release_name}-a7s-mtls-gw was found"
    exit 1
  fi
  echo "INFO: Waiting for configmap ${release_name}-a7s-mtls-gw Waited ${time} minute(s)."
  time=$((time+1))
  sleep 60
done

oc get cm -n ${namespace} ${release_name}-a7s-mtls-gw -o yaml | sed "s#server_names_hash_bucket_size 128#server_names_hash_bucket_size 256#g"| oc apply -f-

