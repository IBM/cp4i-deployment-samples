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
#   -r : <nav_replicas> (string), Defaults to '2'
#
#   With defaults values
#     ./prereqs.sh
#
#   With overridden values
#     ./prereqs.sh -n <namespace> -r <nav_replicas>

function usage {
  echo "Usage: $0 -n <namespace> -r <nav_replicas>"
}

export IMAGE_REPO="cp.icr.io"
namespace="cp4i"
nav_replicas="2"

while getopts "n:r:" opt; do
  case ${opt} in
    n ) namespace="$OPTARG"
      ;;
    r ) nav_replicas="$OPTARG"
      ;;
    \? ) usage; exit
      ;;
  esac
done

DOCKERCONFIGJSON=$(oc get secret -n ${namespace} ibm-entitlement-key -o json | jq -r '.data.".dockerconfigjson"' | base64 --decode)
if [ -z ${DOCKERCONFIGJSON} ] ; then
  echo "ERROR: Failed to find ibm-entitlement-key secret in the namespace '${namespace}'" 1>&2
  exit 1
fi

export ER_REGISTRY=$(echo "$DOCKERCONFIGJSON" | jq -r '.auths' | jq 'keys[]' | tr -d '"')
export ER_USERNAME=$(echo "$DOCKERCONFIGJSON" | jq -r '.auths."cp.icr.io".username')
export ER_PASSWORD=$(echo "$DOCKERCONFIGJSON" | jq -r '.auths."cp.icr.io".password')

#namespaces for the pipeline
export dev_namespace=${namespace}-ddd-dev
export test_namespace=${namespace}-ddd-test

oc create namespace ${dev_namespace}
oc project ${dev_namespace}

oc adm policy add-scc-to-group privileged system:serviceaccounts:$dev_namespace

echo "INFO: Namespace passed='${namespace}'"
echo "INFO: Dev Namespace='${dev_namespace}'"
echo "INFO: Test Namespace='${test_namespace}'"
cd "$(dirname $0)"

#creating new namespace for test/prod and adding namespace to sa
oc create namespace ${test_namespace}
oc adm policy add-scc-to-group privileged system:serviceaccounts:${test_namespace}

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

echo "INFO: Installing tekton and its pre-reqs"
oc apply --filename https://storage.googleapis.com/tekton-releases/pipeline/previous/v0.12.1/release.yaml
echo "INFO: Installing tekton triggers"
oc apply -f https://storage.googleapis.com/tekton-releases/triggers/previous/v0.5.0/release.yaml
echo "INFO: Waiting for tekton and triggers deployment to finish..."
oc wait -n tekton-pipelines --for=condition=available deployment --timeout=20m tekton-pipelines-controller \
  tekton-pipelines-webhook tekton-triggers-controller tekton-triggers-webhook

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

echo "Creating secrets to push images to openshift local registry"
export DOCKER_REGISTRY="image-registry.openshift-image-registry.svc:5000"
export username=image-bot
kubectl -n ${dev_namespace} create serviceaccount image-bot
oc -n ${dev_namespace} policy add-role-to-user registry-editor system:serviceaccount:${dev_namespace}:image-bot
# enable dev namespace to push to test namespace
oc -n ${test_namespace} policy add-role-to-user registry-editor system:serviceaccount:${dev_namespace}:image-bot
export password="$(oc -n ${dev_namespace} serviceaccounts get-token image-bot)"

echo "Creating secrets to push images to openshift local registry"
oc create -n ${dev_namespace} secret docker-registry cicd-${dev_namespace} --docker-server=${DOCKER_REGISTRY} \
  --docker-username=${username} --docker-password=${password} -o yaml | oc apply -f -

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

# Creating a new secret as the type of entitlement key is 'kubernetes.io/dockerconfigjson' but we need secret of type 'kubernetes.io/basic-auth' to pull imags from the ER
echo "Creating secret to pull base images from Entitled Registry"
cat << EOF | oc apply --namespace ${dev_namespace} -f -
apiVersion: v1
kind: Secret
metadata:
  name: er-pull-secret
  annotations:
    tekton.dev/docker-0: ${ER_REGISTRY}
type: kubernetes.io/basic-auth
stringData:
  username: ${ER_USERNAME}
  password: ${ER_PASSWORD}
EOF

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

echo "Waiting for postgres to be ready"
oc wait -n postgres --for=condition=available deploymentconfig --timeout=20m postgresql

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

declare -a image_projects=("${dev_namespace}" "${test_namespace}")

for image_project in "${image_projects[@]}"
do
  echo "INFO: Configuring postgres in the namespace '$image_project'"
  if ! ${PWD}/configure-postgres.sh -n ${image_project} ; then
    echo -e "\nERROR: Failed to configure postgres in the namespace '$image_project'" 1>&2
    exit 1
  fi

  echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

  echo "INFO: Making 'create-ace-config.sh' executable"
  if ! chmod +x ${PWD}/../../products/bash/create-ace-config.sh ; then
    echo "ERROR: Failed to make 'create-ace-config.sh' executable in the namespace '$image_project'" 1>&2
    exit 1
  fi

  echo -e "\nINFO: Creating ace integration server configuration resources in the namespace '$image_project'"
  if ! ${PWD}/../../products/bash/create-ace-config.sh -n ${image_project} ; then
    echo "ERROR: Failed to make 'create-ace-config.sh' executable in the namespace '$image_project'" 1>&2
    exit 1
  fi

  echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

  echo "INFO: Creating secret to pull images from the ER"
  if ! oc get secrets -n ${image_project} ibm-entitlement-key; then
    oc create -n ${image_project} secret docker-registry ibm-entitlement-key --docker-server=${ER_REGISTRY} \
      --docker-username=${ER_USERNAME} --docker-password=${ER_PASSWORD} -o yaml | oc apply -f -
  else
    echo "INFO: ibm-entitlement-key secret already exists"
  fi

  echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

  echo "INFO: Creating operator group and subscription in the namespace '${image_project}'"
  if ! ${PWD}/../../products/bash/deploy-og-sub.sh -n ${image_project} ; then
    echo "ERROR: Failed to apply subscriptions and csv in the namespace '$image_project'" 1>&2
    exit 1
  fi

  echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

  echo "INFO: Releasing Navigator in the namespace '${image_project}'"
  if ! ${PWD}/../../products/bash/release-navigator.sh -n ${image_project} -r ${nav_replicas} ; then
    echo "ERROR: Failed to release the platform navigator in the namespace '$image_project'" 1>&2
    exit 1
  fi

  echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

  echo "INFO: Releasing ACE dashboard in the namespace '${image_project}'"
  if ! ${PWD}/../../products/bash/release-ace-dashboard.sh -n ${image_project} ; then
    echo "ERROR: Failed to release the ace dashboard in the namespace '$image_project'" 1>&2
    exit 1
  fi
  echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"
done
