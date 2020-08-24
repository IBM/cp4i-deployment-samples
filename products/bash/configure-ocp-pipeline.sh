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
#   -n : <namespace> (string), Defaults to 'cp4i'
#
#   With defaults values
#     ./configure-ocp-pipeline.sh
#
#   With overridden values
#     ./configure-ocp-pipeline.sh -n <namespace>

function usage {
  echo "Usage: $0 -n <namespace>"
  exit 1
}

namespace="cp4i"

while getopts "n:" opt; do
  case ${opt} in
    n ) namespace="$OPTARG"
      ;;
    \? ) usage; exit
      ;;
  esac
done

echo -e "\nINFO: Adding permissions to '$namespace' to run tekton tasks..."
oc adm policy add-scc-to-group privileged system:serviceaccounts:$namespace

echo "INFO: Creating 'image-bot' service account to create a secret to push to the openshift local registry"
export DOCKER_REGISTRY="image-registry.openshift-image-registry.svc:5000"
export username=image-bot
kubectl -n ${namespace} create serviceaccount image-bot
export password="$(oc -n ${namespace} serviceaccounts get-token image-bot)"
echo -e "\nINFO: Adding permission for '$namespace' to write images to openshift local registry in the '$namespace'"
oc -n ${namespace} policy add-role-to-user registry-editor system:serviceaccount:${namespace}:image-bot
echo -e "\nCreating secret to push images to openshift local registry"
oc create -n ${namespace} secret docker-registry cicd-${namespace} --docker-server=${DOCKER_REGISTRY} \
  --docker-username=${username} --docker-password=${password} -o yaml | oc apply -f -

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"
