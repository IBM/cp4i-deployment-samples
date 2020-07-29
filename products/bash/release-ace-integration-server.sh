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
#   -r : <is-release-name> (string), Defaults to "ace-is"
#   -i : <is-image-name> (string), Defaults to "image-registry.openshift-image-registry.svc:5000/cp4i/ace-11.0.0.9-r2:new-1"
#
# USAGE:
#   With defaults values
#     ./release-ace-is.sh
#
#   Overriding the namespace and release-name
#     ./release-ace-is -n cp4i -r cp4i-bernie-ace

function usage {
    echo "Usage: $0 -n <namespace> -r <is-release-name> -e <is-image-name>"
}

namespace="cp4i"
is_release_name="ace-is"
is_image_name="image-registry.openshift-image-registry.svc:5000/cp4i/ace-11.0.0.9-r2:new-1"
while getopts "n:r:i:" opt; do
  case ${opt} in
    n ) namespace="$OPTARG"
      ;;
    r ) is_release_name="$OPTARG"
      ;;
    i ) is_image_name="$OPTARG"
      ;;
    \? ) usage; exit
      ;;
  esac
done

cat << EOF | oc apply -f -
apiVersion: appconnect.ibm.com/v1beta1
kind: IntegrationServer
metadata:
  name: ${is_release_name}
  namespace: ${namespace}
spec:
  pod:
   containers:
     runtime:
       image: ${is_image_name}
  configurations:
  - ace-policyproject
  designerFlowsOperationMode: disabled
  license:
    accept: true
    license: L-AMYG-BQ2E4U
    use: CloudPakForIntegrationProduction
  replicas: 2
  router:
    timeout: 120s
  service:
    endpointType: http
  useCommonServices: true
  version: 11.0.0
EOF
