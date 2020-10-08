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
#   -n : <namespace> (string), Namespace for deploying the ace integration server. Defaults to 'cp4i'
#   -b : <barfileBranch> (string), Branch where the bar files exist. Defaults to 'main'
#   -d : <barFilePath> (string), Path for the bar files. Defaults to 'ace-api/Demo-eei.bar'
#   -a : <aceISName> (string), Default ace integration server name. Defaults to 'ace-is-eei'
#
#   With defaults values
#     ./ace-integration-server.sh
#
#   With overridden values
#     ./ace-integration-server.sh -n <namespace> -b <barfileBranch> -d <barFilePath> -a <aceISName>

function divider {
  echo -e "\n-------------------------------------------------------------------------------------------------------------------\n"
}

function usage {
    echo "Usage: $0 -n <namespace> -b <barfileBranch> -d <barFilePath> -a <aceISName>"
    divider
    exit 1
}

namespace="cp4i"
barfileBranch="main"
suffix="eei"
barFilePath="ace-api/Demo-$suffix.bar"
aceISName="ace-is-$suffix"
tick="\xE2\x9C\x85"
cross="\xE2\x9D\x8C"
all_done="\xF0\x9F\x92\xAF"
info="\xE2\x84\xB9"
CURRENT_DIR=$(dirname $0)
missingParams="false"

while getopts "n:b:d:a:" opt; do
  case ${opt} in
    n ) namespace="$OPTARG"
      ;;
    b ) barfileBranch="$OPTARG"
      ;;
    d ) barFilePath="$OPTARG"
      ;;
    a ) aceISName="$OPTARG"
      ;;
    \? ) usage;
      ;;
  esac
done

divider
if [[ -z "${namespace// }" ]]; then
  echo -e "$cross ERROR: The namespace for the ace integration server is empty. Please provide a value for '-n' parameter."
  missingParams="true"
fi

if [[ -z "${barfileBranch// }" ]]; then
  echo -e "$cross ERROR: Branch name for the bar file is empty. Please provide a value for '-b' parameter."
  missingParams="true"
fi

if [[ -z "${barFilePath// }" ]]; then
  echo -e "$cross ERROR: Bar file path name is empty. Please provide a value for '-d' parameter."
  missingParams="true"
fi

if [[ -z "${aceISName// }" ]]; then
  echo -e "$cross ERROR: The ace integration server name is empty. Please provide a value for '-a' parameter."
  missingParams="true"
fi

if [[ "$missingParams" == "true" ]]; then
  divider
  usage
fi

echo -e "$info Current directory: $CURRENT_DIR"
echo -e "$info Namespace: $namespace"
echo -e "$info Bile file branch name: $barfileBranch"
echo -e "$info Bar file path: $barFilePath"
echo -e "$info ACE Integration server name: $aceISName"
divider

cat <<EOF | oc apply -f -
apiVersion: appconnect.ibm.com/v1beta1
kind: IntegrationServer
metadata:
  name: $aceISName
  namespace: $namespace
spec:
  adminServerSecure: true
  barURL: >-
    https://raw.githubusercontent.com/IBM/cp4i-deployment-samples/barfileBranch/EventEnabledInsurance/Bar_files/$barFilePath
  designerFlowsOperationMode: local
  license:
    accept: true
    license: L-APEH-BPUCJK
    use: CloudPakForIntegrationProduction
  replicas: 2
  router:
    timeout: 120s
  service:
    endpointType: http
  useCommonServices: true
  version: 11.0.0.10-r1
  configurations:
    - ace-policyproject-$suffix
EOF
divider
