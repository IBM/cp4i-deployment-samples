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
#   -r : <REPO> (string), Defaults to 'https://github.com/IBM/cp4i-deployment-samples.git'
#   -b : <BRANCH> (string), Defaults to 'main'
#   -t : <TKN-path> (string), Default to 'tkn'
#   -g : <DEFAULT_BLOCK_STORAGE> (string), Default to 'cp4i-block-performance'
#
#   With defaults values
#     ./build.sh
#
#   With overridden values
#     ./build.sh -n <namespace> -r <REPO> -b <BRANCH> -g <DEFAULT_BLOCK_STORAGE>

function divider() {
  echo -e "\n-------------------------------------------------------------------------------------------------------------------\n"
}

function usage() {
  echo "Usage: $0 -n <namespace> -r <REPO> -b <BRANCH> -t <TKN-path> -g <DEFAULT_BLOCK_STORAGE>"
  divider
  exit 1
}

namespace="cp4i"
tick="\xE2\x9C\x85"
cross="\xE2\x9D\x8C"
all_done="\xF0\x9F\x92\xAF"
SUFFIX="eei"
POSTGRES_NAMESPACE=
REPO="https://github.com/IBM/cp4i-deployment-samples.git"
BRANCH="main"
TKN=tkn
DEFAULT_BLOCK_STORAGE="cp4i-block-performance"

while getopts "n:r:b:t:f:g:" opt; do
  case ${opt} in
  n)
    namespace="$OPTARG"
    ;;
  r)
    REPO="$OPTARG"
    ;;
  b)
    BRANCH="$OPTARG"
    ;;
  t)
    TKN="$OPTARG"
    ;;
  f)
    echo "-f ignored as file storage no longer needed"
    ;;
  g)
    DEFAULT_BLOCK_STORAGE="$OPTARG"
    ;;
  \?)
    usage
    ;;
  esac
done

POSTGRES_NAMESPACE=${POSTGRES_NAMESPACE:-$namespace}

if [[ -z "${namespace// /}" || -z "${REPO// /}" || -z "${BRANCH// /}" || -z "${TKN// /}" || -z "${DEFAULT_BLOCK_STORAGE// /}" ]]; then
  echo -e "$cross ERROR: Mandatory parameters are empty"
  usage
fi

CURRENT_DIR=$(dirname $0)
echo "INFO: Current directory: '$CURRENT_DIR'"
echo "INFO: Namespace: '$namespace'"
echo "INFO: Suffix for the postgres is: '$SUFFIX'"
echo "INFO: Repo: '$REPO'"
echo "INFO: Branch: '$BRANCH'"
echo "INFO: TKN: '$TKN'"
echo "INFO: Default block storage class: '$DEFAULT_BLOCK_STORAGE'"

divider

echo "INFO: Creating pvc for EEI in the '$namespace' namespace"
if cat $CURRENT_DIR/pvc.yaml |
  sed "s#{{DEFAULT_BLOCK_STORAGE}}#$DEFAULT_BLOCK_STORAGE#g;" |
  oc apply -n $namespace -f -; then
  echo -e "\n$tick INFO: Successfully created the pvc in the '$namespace' namespace"
else
  echo -e "\n$cross ERROR: Failed to create the pvc in the '$namespace' namespace"
  exit 1
fi

divider

echo "INFO: Create build and deploy tekton tasks"
if cat $CURRENT_DIR/../../CommonPipelineResources/cicd-tasks.yaml |
  sed "s#{{NAMESPACE}}#$namespace#g;" |
  oc apply -n ${namespace} -f -; then
  echo -e "\n$tick INFO: Successfully applied build and deploy tekton tasks in the '$namespace' namespace"
else
  echo -e "\n$cross ERROR: Failed to apply build and deploy tekton tasks in the '$namespace' namespace"
  exit 1
fi

divider

CONFIGURATIONS="[serverconf-$SUFFIX, keystore-$SUFFIX, application.kdb, application.sth, application.jks, policyproject-$SUFFIX, setdbparms-$SUFFIX]"

echo "INFO: Creating the pipeline to build and deploy the EEI apps in '$namespace' namespace"
if cat $CURRENT_DIR/pipeline.yaml |
  sed "s#{{NAMESPACE}}#$namespace#g;" |
  sed "s#{{CONFIGURATIONS}}#'$CONFIGURATIONS'#g;" |
  sed "s#{{FORKED_REPO}}#$REPO#g;" |
  sed "s#{{BRANCH}}#$BRANCH#g;" |
  oc apply -n ${namespace} -f -; then
  echo -e "\n$tick INFO: Successfully applied the pipeline to build and deploy the EEI apps in '$namespace' namespace"
else
  echo -e "\n$cross ERROR: Failed to apply the pipeline to build and deploy the EEI apps in '$namespace' namespace"
  exit 1
fi #pipeline.yaml

divider

PIPELINERUN_UID=$(
  LC_ALL=C tr -dc 'a-z0-9' </dev/urandom | head -c 5
  echo
)
PIPELINE_RUN_NAME="eei-build-pipelinerun-${PIPELINERUN_UID}"

echo "INFO: Creating the pipelinerun for the EEI apps in the '$namespace' namespace with name '$PIPELINE_RUN_NAME'"
if cat $CURRENT_DIR/pipelinerun.yaml |
  sed "s#{{PIPELINE_RUN_NAME}}#$PIPELINE_RUN_NAME#g;" |
  oc apply -n ${namespace} -f -; then
  echo -e "\n$tick INFO: Successfully applied the pipelinerun for the EEI apps in the '$namespace' namespace"
else
  echo -e "\n$cross ERROR: Failed to apply the pipelinerun for the EEI apps in the '$namespace' namespace"
  exit 1
fi #pipelinerun.yaml

divider

pipelinerunSuccess="false"
echo -e "INFO: Displaying the pipelinerun logs in the '$namespace' namespace: \n"
if ! $TKN pipelinerun logs -n $namespace -f $PIPELINE_RUN_NAME; then
  echo -e "\n$cross ERROR: Failed to get the pipelinerun logs successfully"
fi

divider

echo -e "INFO: The pipeline run in the '$namespace' namespace:\n"
oc get pipelinerun -n $namespace $PIPELINE_RUN_NAME

echo -e "\nINFO: The task runs in the '$namespace' namespace:\n"
oc get taskrun -n $namespace

if [[ "$(oc get pipelinerun -n $namespace $PIPELINE_RUN_NAME -o json | jq -r '.status.conditions[0].status')" == "True" ]]; then
  pipelinerunSuccess="true"
fi

echo -e "\nINFO: Going ahead to delete the pipelinerun instance to delete the related pods and the pvc"

divider

if oc delete pipelinerun -n $namespace $PIPELINE_RUN_NAME; then
  echo -e "\n$tick INFO: Deleted the pipelinerun with the uid '$PIPELINERUN_UID'"
else
  echo -e "$cross ERROR: Failed to delete the pipelinerun with the uid '$PIPELINERUN_UID'"
fi

divider

if oc delete pvc buildah-ace-rest-eei -n $namespace; then
  echo -e "\n$tick INFO: Deleted the pvc 'buildah-ace-rest-eei'"
else
  echo -e "$cross ERROR: Failed to delete the pvc 'buildah-ace-rest-eei'"
fi

divider

if oc delete pvc buildah-ace-db-writer-eei -n $namespace; then
  echo -e "\n$tick INFO: Deleted the pvc 'buildah-ace-db-writer-eei'"
else
  echo -e "$cross ERROR: Failed to delete the pvc 'buildah-ace-db-writer-eei'"
fi

divider

if [[ "$pipelinerunSuccess" == "false" ]]; then
  echo -e "\n$cross ERROR: The pipelinerun did not succeed\n"
  exit 1
else
  echo -e "\n$tick INFO: The eei demo related applications have been deployed, but with zero replicas.\n"
  oc get deployment -n $namespace -l demo=eei
  echo -e "\n$tick INFO: To start the quote simulator app run the command 'oc scale deployment/quote-simulator-eei --replicas=1'"
  echo -e "$tick INFO: To start the projection claims app run the command 'oc scale deployment/projection-claims-eei --replicas=1'"
  PC_ROUTE=$(oc get route -n $namespace projection-claims-eei --template='https://{{.spec.host}}/getalldata')
  echo -e "$tick INFO: To view the projection claims (once the app is running), navigate to:\n${PC_ROUTE}"
fi
divider
