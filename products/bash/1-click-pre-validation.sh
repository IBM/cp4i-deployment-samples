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
#   -r : <navReplicaCount> (string), Platform navigator replica count, Defaults to "3"
#   -u : <csDefaultAdminUser> (string), Common services default admin username, Defaults to "admin"
#   -d : <demoPreparation> (string), If all demos are to be setup. Defaults to "false"
#   -n : <namespace> (string), Namespace for the 1-click validation. Defaults to "cp4i"
#
# USAGE:
#   With defaults values
#     ./1-click-pre-validation.sh 
#
#   Overriding the namespace and release-name
#     ./1-click-pre-validation.sh -n <namespace> -r <navReplicaCount> -u <csDefaultAdminUser> -d <demoPreparation>

function divider() {
  echo -e "\n-------------------------------------------------------------------------------------------------------------------\n"
}

function usage() {
  echo "Usage: $0 -n <namespace> -r <navReplicaCount> -u <csDefaultAdminUser> -d <demoPreparation>"
  divider
  exit 1
}

navReplicaCount="3"
csDefaultAdminUser="admin"
demoPreparation="false"
CURRENT_DIR=$(dirname $0)
tick="\xE2\x9C\x85"
cross="\xE2\x9D\x8C"
all_done="\xF0\x9F\x92\xAF"
info="\xE2\x84\xB9"
missingParams="false"
namespace="cp4i"
MIN_OCP_VERSION=4.10
MAX_OCP_VERSION=4.12

while getopts "p:r:u:d:n:" opt; do
  case ${opt} in
  n)
    namespace="$OPTARG"
    ;;
  r)
    navReplicaCount="$OPTARG"
    ;;
  u)
    csDefaultAdminUser="$OPTARG"
    ;;
  d)
    demoPreparation="$OPTARG"
    ;;
  \?)
    usage
    ;;
  esac
done

if [[ -z "${namespace// /}" ]]; then
  echo -e "$cross ERROR: 1-click validation namespace is empty. Please provide a value for '-n' parameter."
  missingParams="true"
fi

if [[ -z "${navReplicaCount// /}" ]]; then
  echo -e "$cross ERROR: 1-click validation platform navigator replica count is empty. Please provide a value for '-r' parameter."
  missingParams="true"
fi

if [[ -z "${csDefaultAdminUser// /}" ]]; then
  echo -e "$cross ERROR: 1-click validation default admin username is empty. Please provide a value for '-u' parameter."
  missingParams="true"
fi

if [[ -z "${demoPreparation// /}" ]]; then
  echo -e "$cross ERROR: 1-click validation demo preparation parameter is empty. Please provide a value for '-d' parameter."
  missingParams="true"
fi

if [[ "$missingParams" == "true" ]]; then
  divider
  usage
fi

divider
echo -e "$info Current directory: $CURRENT_DIR"
echo -e "$info Project name: $namespace"
echo -e "$info Common services admin username: $csDefaultAdminUser"
echo -e "$info Platform navigator replica count: $navReplicaCount"
echo -e "$info Setup all demos: $demoPreparation"
divider

export check=0

# CPU/Memory requirements when demoPreparation is true
demo_products="ACE, ACE Designer, APIC, Event Streams, PostgreSQL and Asset Repository"
cpu_req=77.95
mem_req_gi=154.5
total_cpu=0.0
total_mem_gi=0.0

if [[ "${demoPreparation}" == "true" || "${drivewayDentDeletionDemo}" == "true" || "${eventEnabledInsuranceDemo}" == "true" || "${cognitiveCarRepairDemo}" == "true" || "${mappingAssistDemo}" == "true" || "${weatherChatbotDemo}" == "true" ]]; then
  for row in $(oc get node -o json | jq -r '.items[] | { name: .metadata.name, cpu: .status.allocatable.cpu, mem: .status.allocatable.memory } | @base64'); do
    _jq() {
      echo ${row} | base64 --decode | jq -r ${1}
    }
    _cpu() {
      if [[ "$1" == "null" ]]; then
        echo "null"
      else
        units=$(echo $1 | sed 's/[^a-zA-Z]*//g')
        value=$(echo $1 | sed 's/[^0-9.]*//g')
        if [ "$units" = "m" ]; then
          value=$(jq -n "$value/1000")
        fi
        echo "${value}"
      fi
    }
    _memGiB() {
      if [[ "$1" == "null" ]]; then
        echo "null"
      else
        units=$(echo $1 | sed 's/[^a-zA-Z]*//g')
        value=$(echo $1 | sed 's/[^0-9.]*//g')
        if [ "$units" = "Ki" ]; then
          value=$(jq -n "$value/1048576")
        elif [ "$units" = "Mi" ]; then
          value=$(jq -n "$value/1024")
        elif [ "$units" = "Gi" ]; then
          value=$(jq -n "$value")
        elif [ "$units" = "Ti" ]; then
          value=$(jq -n "$value*1048576")
        else
          value="null"
        fi
        echo "${value}"
      fi
    }

    name=$(_jq '.name')
    cpu=$(_cpu $(_jq '.cpu'))
    mem_gi=$(_memGiB $(_jq '.mem'))
    printf "%s: cpus=%.1f mem=%.1f GiB\n" "$name" $cpu $mem_gi
    total_cpu=$(jq -n "$total_cpu+$cpu")
    total_mem_gi=$(jq -n "$total_mem_gi+$mem_gi")
  done
  printf "Total: cpus=%.1f mem=%.1f GiB\n" $total_cpu $total_mem_gi

  divider

  if [ $(jq -n "$total_cpu < $cpu_req") == "true" ]; then
    printf "$cross ERROR: You have %0.1f allocatable cores. Minimum CPU requirement for ${demo_products} is %0.1f cores\n" $total_cpu $cpu_req
    check=1
  else
    echo -e "$tick INFO: You have enough allocatable cpu for the demo"
  fi

  if [ $(jq -n "$total_mem_gi < $mem_req_gi") == "true" ]; then
    printf "$cross ERROR: You have %0.1f GiB of allocatable memory. Minimum memory requirement for ${demo_products} is %0.1f GiB\n" $total_mem_gi $mem_req_gi
    check=1
  else
    echo -e "$tick INFO: You have enough allocatable memory for the demo"
  fi
fi #demoPreparation

if [[ $(oc get node -o json | jq -r '.items[].metadata.labels["ibm-cloud.kubernetes.io/zone"]' | uniq | wc -l | xargs) != 1 ]]; then
  echo -e "$cross ERROR: This Software Catalog installer does not support multi-zone (MZR) clusters - see https://ibm.biz/cp4i-swcat-limitations for more details, or please try again with a cluster with all nodes in a single zone"
  check=1
else
  echo -e "$tick INFO: Cluster nodes are all in a single zone"
fi

if [[ ! -z $namespace ]] && [[ "${demoPreparation}" == "true" ]]; then
  if [ "${#namespace}" -gt 9 ]; then
    echo -e "$cross ERROR: When using demo preparation the project name must be 9 characters long or less"
    check=1
  else
    echo -e "$tick INFO: Project name length ok"
  fi
fi

if [[ $navReplicaCount -le 0 ]]; then
  echo -e "$cross ERROR: Platform navigator replica count should be greater than 0"
  check=1
else
  echo -e "$tick INFO: Platform navigator replica count ok"
fi

export csDefaultAdminUserRegex='^[a-zA-Z]+$'
if ! [[ "$csDefaultAdminUser" =~ $csDefaultAdminUserRegex ]]; then
  echo -e "$cross ERROR: Common Services admin username can contain only letters"
  check=1
else
  echo -e "$tick INFO: Common Services admin username ok"
fi

OCP_VERSION=$(oc version -o json | jq -r '.openshiftVersion')
OCP_MAJOR_VERSION=$(echo $OCP_VERSION | cut -f1 -d'.')
OCP_MINOR_VERSION=$(echo $OCP_VERSION | cut -f2 -d'.')
MIN_OCP_MAJOR_VERSION=$(echo $MIN_OCP_VERSION | cut -f1 -d'.')
MIN_OCP_MINOR_VERSION=$(echo $MIN_OCP_VERSION | cut -f2 -d'.')
MAX_OCP_MAJOR_VERSION=$(echo $MAX_OCP_VERSION | cut -f1 -d'.')
MAX_OCP_MINOR_VERSION=$(echo $MAX_OCP_VERSION | cut -f2 -d'.')
OCP_VERSION_OK=true
if [ "$OCP_MAJOR_VERSION" -lt "$MIN_OCP_MAJOR_VERSION" ] || ([ "$OCP_MAJOR_VERSION" -eq "$MIN_OCP_MAJOR_VERSION" ] && [ "$OCP_MINOR_VERSION" -lt "$MIN_OCP_MINOR_VERSION" ]); then
  echo -e "$cross ERROR: The Openshift version (${OCP_VERSION}) of the cluster is too low, ${MIN_OCP_VERSION} is the minimum currently supported"
  check=1
  OCP_VERSION_OK=false
fi
if [ "$OCP_MAJOR_VERSION" -gt "$MAX_OCP_MAJOR_VERSION" ] || ([ "$OCP_MAJOR_VERSION" -eq "$MAX_OCP_MAJOR_VERSION" ] && [ "$OCP_MINOR_VERSION" -gt "$MAX_OCP_MINOR_VERSION" ]); then
  echo -e "$cross ERROR: The Openshift version (${OCP_VERSION}) of the cluster is too high, ${MAX_OCP_VERSION} is the maximum currently supported"
  check=1
  OCP_VERSION_OK=false
fi
if [ "$OCP_VERSION_OK" == "true" ]; then
  echo -e "$tick INFO: The Openshift version (${OCP_VERSION}) is supported. Minimum version is ${MIN_OCP_VERSION} and maximum version is ${MAX_OCP_VERSION}"
fi

echo 'Output of "oc get nodes" for info:'
oc get nodes

divider

if [[ $check -ne 0 ]]; then
  echo -e "$cross ERROR: Rerun the installation after fixing the above validation errors (no need to delete the schematics workspace)."
  exit 1
else
  echo -e "$tick $all_done INFO: All validation checks passed $all_done $tick"
fi
