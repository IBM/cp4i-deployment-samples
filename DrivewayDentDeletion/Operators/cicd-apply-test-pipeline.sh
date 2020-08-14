#!/bin/bash
#******************************************************************************
# Licensed Materials - Property of IBM
# (c) Copyright IBM Corporation 2019. All Rights Reserved.
#
# Note to U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.
#****

# PREREQUISITES:
#   - Logged into cluster on the OC CLI (https://docs.openshift.com/container-platform/4.4/cli_reference/openshift_cli/getting-started-cli.html)
#
# PARAMETERS:
#   -n : <namespace> (string), Defaults to 'cp4i'
#   -t : <imageTag> (string), Defaults to 'cp4i-test'
#
#   With defaults values
#     ./test-api-e2e.sh
#
#   With overridden values
#     ./test-api-e2e.sh -n <namespace> -t <imageTag>

function usage() {
  echo "Usage: $0 -n <namespace>"
}

# default vars
namespace="cp4i"
imageTag="cp4i-test"
tick="\xE2\x9C\x85"
cross="\xE2\x9D\x8C"
all_done="\xF0\x9F\x92\xAF"
sum=0

while getopts "n:t:" opt; do
  case ${opt} in
  n)
    namespace="$OPTARG"
    ;;
  t)
    imageTag="$OPTARG"
    ;;
  \?)
    usage
    exit
    ;;
  esac
done

echo -e "\nINFO: Get pods:\n"
oc get pods

# echo -e "\nINFO: Check all namespaces:\n"
# oc projects

# echo "INFO: Check who am i - oc:"
# oc whoami

# echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

# echo "Image Tag passed: '$imageTag'"
# echo "INFO: Namespace: '$namespace'"
# echo "INFO: Dev Namespace: '$namespace-ddd-dev'"
# echo "INFO: Test Namespace: '$namespace-ddd-test'"

# echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

# if ! oc project $namespace-ddd-dev >/dev/null 2>&1 ; then
#   printf "$cross "
#   echo "ERROR: The dev namespace '$namespace-ddd-dev' does not exist"
#   exit 1
# else
#   printf "$tick "
#   echo "INFO: The dev namespace '$namespace-ddd-dev' exists"
# fi

# if ! oc project $namespace-ddd-test >/dev/null 2>&1 ; then
#   printf "$cross "
#   echo "ERROR: The test namespace '$namespace-ddd-test' does not exist"
#   exit 1
# else
#   printf "$tick "
#   echo "INFO: The test namespace '$namespace-ddd-test' exists"
# fi

# echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

# # switch namespace
# oc project $namespace-ddd-dev

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

ls -lFA $PWD

# create tekton tasks for deploy and test in test namesace
echo "INFO: Create tekton tasks for deploy and test in test namesace"
if cat /workspace/git-source/DrivewayDentDeletion/Operators/cicd-test/cicd-test-tasks.yaml |
  sed "s#{{NAMESPACE}}#$namespace#g;" |
  sed "s#{{IMAGETAG}}#$imageTag#g;" |
  oc apply -f -; then
  printf "$tick "
  echo "Successfully applied tekton tasks for deploy and test in test namesace"
else
  printf "$cross "
  echo "Failed to apply tekton tasks for deploy and test in test namesace"
  sum=$((sum + 1))
fi

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

# create the pipeline to run tasks to deploy to test namespace
echo "INFO: Create the pipeline to run tasks todeploy to test namespace"
if oc apply -f /workspace/git-source/DrivewayDentDeletion/Operators/cicd-test/cicd-test-pipeline.yaml; then
  printf "$tick "
  echo "Successfully applied the pipeline to run tasks to deploy to test namespace"
else
  printf "$cross "
  echo "Failed to apply the pipeline to run tasks to deploy to test namespace"
  sum=$((sum + 1))
fi

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

if [[ $sum -gt 0 ]]; then
  printf "$cross "
  echo "ERROR: Pipeline and tasks for deploy and test for test namespace has not been configured successfully, exiting now."
  exit 1
else
  printf "$tick  $all_done "
  echo "Successfully applied the pipeline and tasks for deploy and test for test namespace"
fi

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"
