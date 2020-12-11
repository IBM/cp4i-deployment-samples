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
#   -r : <dashboard-release-name> (string), Defaults to "ace-dashboard-demo"
#   -m : <metadata_name> (string)
#   -u : <metadata_uid> (string)
#
# USAGE:
#   With defaults values
#     ./release-ace-dashboard.sh
#
#   Overriding the namespace and release-name
#     ./release-ace-dashboard.sh -n cp4i-prod -r prod
#
#   To add ownerReferences for the demos operator
#     ./release-ace-dashboard.sh -m metadata_name -u metadata_uid

function usage() {
  echo "Usage: $0 -n <namespace> -r <dashboard-release-name> -m <metadata_name> -u <metadata_uid>"
}

namespace="cp4i"
dashboard_release_name="ace-dashboard-demo"
storage="ibmc-file-gold-gid"
production="false"
while getopts "n:r:s:m:u:p" opt; do
  case ${opt} in
  n)
    namespace="$OPTARG"
    ;;
  r)
    dashboard_release_name="$OPTARG"
    ;;
  s)
    storage="$OPTARG"
    ;;
  m)
    metadata_name="$OPTARG"
    ;;
  u)
    metadata_uid="$OPTARG"
    ;;
  p)
    production="true"
    ;;
  \?)
    usage
    exit
    ;;
  esac
done

echo "INFO: Release ACE Dashboard..."
echo "INFO: Namespace: '$namespace'"
echo "INFO: Dashboard Release Name: '$dashboard_release_name'"

use="CloudPakForIntegrationNonProduction"

if [[ "$production" == "true" ]]; then
  echo "Production Mode Enabled"
  use="CloudPakForIntegrationProduction"

fi

cat <<EOF | oc apply -f -
apiVersion: appconnect.ibm.com/v1beta1
kind: Dashboard
metadata:
  name: ${dashboard_release_name}
  namespace: ${namespace}
  $(if [[ ! -z ${metadata_uid} && ! -z ${metadata_name} ]]; then
  echo "ownerReferences:
    - apiVersion: integration.ibm.com/v1beta1
      kind: Demo
      name: ${metadata_name}
      uid: ${metadata_uid}
      controller: true
      blockOwnerDeletion: true"
  fi)
spec:
  license:
    accept: true
    license: L-APEH-BPUCJK
    use: ${use}
  replicas: 1
  storage:
    class: ${storage}
    size: 5Gi
    type: persistent-claim
  useCommonServices: true
  version: 11.0.0.10
EOF
