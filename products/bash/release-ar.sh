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
#   -m : <metadata_name> (string)
#   -u : <metadata_uid> (string)
#
# USAGE:
#   With defaults values
#     ./release-ar.sh
#
#   Overriding the namespace and release-name
#     ./release-ar.sh -n cp4i-prod -r prod
#
#   To add ownerReferences for the demos operator
#     ./release-ar.sh -m metadata_name -u metadata_uid


function usage() {
  echo "Usage: $0 -n <namespace> -r <release-name> -m <metadata_name> -u <metadata_uid>"
}

namespace="cp4i"
release_name="demo"
assetDataVolume="ibmc-file-gold-gid"
couchVolume="ibmc-block-gold"

while getopts "n:r:a:c:m:u:" opt; do
  case ${opt} in
  n)
    namespace="$OPTARG"
    ;;
  r)
    release_name="$OPTARG"
    ;;
  a)
    assetDataVolume="$OPTARG"
    ;;
  c)
    couchVolume="$OPTARG"
    ;;
  m)
    metadata_name="$OPTARG"
    ;;
  u)
    metadata_uid="$OPTARG"
    ;;
  \?)
    usage
    exit
    ;;
  esac
done

cat <<EOF | oc apply -f -
apiVersion: integration.ibm.com/v1beta1
kind: AssetRepository
metadata:
  name: ${release_name}
  namespace: ${namespace}
  $(if [[ ! -z ${metadata_uid} && ! -z ${metadata_name} ]]; then
  echo "ownerReferences:
    - apiVersion: integration.ibm.com/v1beta1
      kind: Demo
      name: ${metadata_name}
      uid: ${metadata_uid}"
  fi)
spec:
  license:
    accept: true
  storage:
    assetDataVolume:
      class: ${assetDataVolume}
    couchVolume:
      class: ${couchVolume}
  version: 2020.3.1-0
EOF
