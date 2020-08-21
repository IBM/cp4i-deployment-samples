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
  exit 1
}

namespace="cp4i"
nav_replicas="2"
tick="\xE2\x9C\x85"
cross="\xE2\x9D\x8C"
all_done="\xF0\x9F\x92\xAF"

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

CURRENT_DIR=$(dirname $0)
echo "Current directory: $CURRENT_DIR"
echo "Namespace: $namespace"
echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

DOCKERCONFIGJSON_ER=$(oc get secret -n ${namespace} ibm-entitlement-key -o json | jq -r '.data.".dockerconfigjson"' | base64 --decode)
if [ -z ${DOCKERCONFIGJSON_ER} ] ; then
  echo "ERROR: Failed to find ibm-entitlement-key secret in the namespace '${namespace}'" 1>&2
  exit 1
fi

export ER_REGISTRY=$(echo "$DOCKERCONFIGJSON_ER" | jq -r '.auths' | jq 'keys[]' | tr -d '"')
export ER_USERNAME=$(echo "$DOCKERCONFIGJSON_ER" | jq -r '.auths."cp.icr.io".username')
export ER_PASSWORD=$(echo "$DOCKERCONFIGJSON_ER" | jq -r '.auths."cp.icr.io".password')

#namespaces for the pipeline
export dev_namespace=${namespace}
export test_namespace=${namespace}-ddd-test

oc project ${dev_namespace}

oc adm policy add-scc-to-group privileged system:serviceaccounts:$dev_namespace

echo "INFO: Namespace passed='${namespace}'"
echo "INFO: Dev Namespace='${dev_namespace}'"
echo "INFO: Test Namespace='${test_namespace}'"

#creating new namespace for test/prod and adding namespace to sa
oc create namespace ${test_namespace}
oc adm policy add-scc-to-group privileged system:serviceaccounts:${test_namespace}

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

echo "INFO: Installing OCP pipelines"
cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: openshift-pipelines-operator
  namespace: openshift-operators
spec:
  channel: ocp-4.4
  name: openshift-pipelines-operator-rh
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

echo "Creating secrets to push images to openshift local registry"
export DOCKER_REGISTRY="image-registry.openshift-image-registry.svc:5000"
export username=image-bot
kubectl -n ${dev_namespace} create serviceaccount image-bot
oc -n ${dev_namespace} policy add-role-to-user registry-editor system:serviceaccount:${dev_namespace}:image-bot
# enable dev namespace to push to test namespace
oc -n ${test_namespace} policy add-role-to-user registry-editor system:serviceaccount:${dev_namespace}:image-bot
export password="$(oc -n ${dev_namespace} serviceaccounts get-token image-bot)"

echo -e "\nCreating secrets to push images to openshift local registry"
oc create -n ${dev_namespace} secret docker-registry cicd-${dev_namespace} --docker-server=${DOCKER_REGISTRY} \
  --docker-username=${username} --docker-password=${password} -o yaml | oc apply -f -

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

# Creating a new secret as the type of entitlement key is 'kubernetes.io/DOCKERCONFIGJSON_ER' but we need secret of type 'kubernetes.io/basic-auth'
# to pull imags from the ER
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
declare -a suffix=("ddd")

for image_project in "${image_projects[@]}" #for_outer
do
  for each_suffix in "${suffix[@]}" #for_inner
  do
    if [[ ("$each_suffix" == "ddd") ]]; then
      echo -e "\nINFO: Configuring postgres in the namespace '$image_project' with the suffix '$each_suffix'\n"
      if ! ${CURRENT_DIR}/configure-postgres.sh -n ${image_project} -s $each_suffix; then
        echo -e "\n$cross ERROR: Failed to configure postgres in the namespace '$image_project' with the suffix '$each_suffix'"
        exit 1
      else
        printf "$tick "
        echo -e "\nINFO: Successfuly configured postgres in the namespace '$image_project' with the suffix '$each_suffix'"
      fi  #${CURRENT_DIR}/configure-postgres.sh -n ${image_project} -s $each_suffix

      echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"
      echo -e "INFO: Creating ace integration server configuration resources in the namespace '$image_project'"

      if ! ${CURRENT_DIR}/../../products/bash/create-ace-config.sh -n ${image_project} -s $each_suffix; then
        printf "$cross "
        echo "ERROR: Failed to configure ace in the namespace '$image_project'  with the suffix '$each_suffix'"
        exit 1
      else
        printf "$tick "
        echo "INFO: Successfuly configured ace in the namespace '$image_project' with the suffix '$each_suffix'"
      fi  #${CURRENT_DIR}/../../products/bash/create-ace-config.sh -n ${image_project} -s $each_suffix
    fi  #("$each_suffix" == "ddd")
  done #for_inner_done
  echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"
done #for_outer_done

echo -e "INFO: Creating secret to pull images from the ER in the '${test_namespace}' namespace\n"

if ! oc get secrets -n ${test_namespace} ibm-entitlement-key; then
  oc create -n ${test_namespace} secret docker-registry ibm-entitlement-key --docker-server=${ER_REGISTRY} \
    --docker-username=${ER_USERNAME} --docker-password=${ER_PASSWORD} -o yaml | oc apply -f -
else
  echo -e "\nINFO: ibm-entitlement-key secret already exists in the '${test_namespace}' namespace"
fi

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

echo "INFO: Creating operator group and subscription in the namespace '${test_namespace}'"

if ! ${CURRENT_DIR}/../../products/bash/deploy-og-sub.sh -n ${test_namespace} ; then
  echo "ERROR: Failed to apply subscriptions and csv in the namespace '$test_namespace'"
  exit 1
fi

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

echo "INFO: Releasing Navigator in the namespace '${test_namespace}'"

if ! ${CURRENT_DIR}/../../products/bash/release-navigator.sh -n ${test_namespace} -r ${nav_replicas} ; then
  echo "ERROR: Failed to release the platform navigator in the namespace '$test_namespace'"
  exit 1
fi

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

echo "INFO: Releasing ACE dashboard in the namespace '${test_namespace}'"

if ! ${CURRENT_DIR}/../../products/bash/release-ace-dashboard.sh -n ${test_namespace} ; then
  echo "ERROR: Failed to release the ace dashboard in the namespace '$test_namespace'"
  exit 1
fi

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"
echo -e "$tick $all_done INFO: All prerequisites for the driveway dent deletion have been applied successfully $all_done $tick"
echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

