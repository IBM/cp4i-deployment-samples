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
#
# USAGE:
#   With defaults values
#     ./release-ar.sh
#
#   Overriding the namespace and release-name
#     ./release-ar -n cp4i-prod -r prod

function usage {
    echo "Usage: $0 -n <namespace> -r <release-name>"
}

namespace="cp4i"
release_name="demo"

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
apiVersion: integration.ibm.com/v1beta1
kind: AssetRepository
metadata:
  name: ${release_name}
  namespace: ${namespace}
spec:
  license:
    accept: true
  storage:
    assetDataVolume:
      class: ibmc-file-gold-gid
    couchVolume:
      class: ibmc-block-gold
  version: 2020.2.1.1-0
EOF
