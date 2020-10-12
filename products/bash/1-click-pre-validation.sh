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
#   -p : <csDefaultAdminPassword> (string), common services default admin password
#   -r : <navReplicaCount> (string), Platform navigator replica count, Defaults to "3"
#   -u : <csDefaultAdminUser> (string), Common services default admin username, Defaults to "admin"
#   -d : <demoPreparation> (string), If all demos are to be setup. Defaults to "false"
#
# USAGE:
#   With defaults values
#     ./1-click-pre-validation.sh -p <csDefaultAdminPassword>
#
#   Overriding the namespace and release-name
#     ./1-click-pre-validation.sh -p <csDefaultAdminPassword> -r <navReplicaCount> -u <csDefaultAdminUser> -d <demoPreparation>

function divider {
    echo -e "\n-------------------------------------------------------------------------------------------------------------------\n"
}

function usage {
    echo "Usage: $0 -p <csDefaultAdminPassword> -r <navReplicaCount> -u <csDefaultAdminUser> -d <demoPreparation>"
    divider
    exit 1
}

navReplicaCount="3"
csDefaultAdminUser="admin"
demoPreparation="false"
CURRENT_DIR=$(dirname $0)
tick="\xE2\x9C\x85"
cross="\xE2\x9D\x8C"
info="\xE2\x84\xB9"
missingParams="false"

while getopts "p:r:u:d:" opt; do
  case ${opt} in
    p ) csDefaultAdminPassword="$OPTARG"
      ;;
    r ) navReplicaCount="$OPTARG"
      ;;
    u ) csDefaultAdminUser="$OPTARG"
      ;;
    d ) demoPreparation="$OPTARG"
      ;;
    \? ) usage;
      ;;
  esac
done

if [[ -z "${csDefaultAdminPassword// }" ]]; then
  echo -e "$cross ERROR: Default admin password is empty. Please provide a value for '-p' parameter."
  missingParams="true"
fi

if [[ -z "${navReplicaCount// }" ]]; then
  echo -e "$cross ERROR: Platform navigator replica count is empty. Please provide a value for '-r' parameter."
  missingParams="true"
fi

if [[ -z "${csDefaultAdminUser// }" ]]; then
  echo -e "$cross ERROR: Default admin username is empty. Please provide a value for '-u' parameter."
  missingParams="true"
fi

if [[ -z "${demoPreparation// }" ]]; then
  echo -e "$cross ERROR: Demo preparation parameter is empty. Please provide a value for '-d' parameter."
  missingParams="true"
fi

if [[ "$missingParams" == "true" ]]; then
  divider
  usage
fi

divider
echo -e "$info Current directory: $CURRENT_DIR"
echo -e "$info Common services admin username: $csDefaultAdminUser"
echo -e "$info Platform navigator replica count: $navReplicaCount"
echo -e "$info Setup all demos: $demoPreparation"
divider

export check=0

# CPU/Memory requirements when demoPreparation is true
demo_products="ACE, ACE Designer, APIC, Event Streams, Tracing, PostgreSQL and Asset Repository"
cpu_req_m=77950
mem_req_gi=155 #rounded up 154.5

# converting GiB to KiB by multiplying by (1024*1024)
mem_req_ki=$(($mem_req_gi * 1048576))

echo "INFO: Validating csDefaultAdminPassword"
export csDefaultAdminPasswordRegex='^[a-zA-Z0-9-]+$'
if [ "${#csDefaultAdminPassword}" -lt 32 ]; then
  echo -e "$cross ERROR: Password should be at least 32 characters long"
  check=1
fi
if ! [[ "$csDefaultAdminPassword" =~ $csDefaultAdminPasswordRegex ]]; then
  echo -e "$cross ERROR: Password can only include number, letter and -"
  check=1
fi

divider

echo "INFO: Validating navReplicaCount"
if [[ $navReplicaCount -le 0 ]]; then
   echo -e "$cross ERROR: navReplicaCount should be greater than 0"
   check=1
fi

divider

echo "INFO: Validating csDefaultAdminUser"
export csDefaultAdminUserRegex='^[a-zA-Z]+$'
if ! [[ "$csDefaultAdminUser" =~ $csDefaultAdminUserRegex   ]]; then
  echo -e "$cross ERROR: Common Services csDefaultAdminUser can contain only letters"
  check=1
fi

divider

if [[ "${demoPreparation}" == "true" ]]; then
  echo "INFO: Checking for cluster size for demo"
  count=0
  num_nodes=$(oc get nodes -o=name | wc -w)
  if [ $num_nodes -eq 0 ]; then
    while true; do
      num_nodes=$(oc get nodes -o=name | wc -w)
      if [ $num_nodes -ne 0 ]; then break; fi
      if [ $count -eq 10  ]; then echo "Error: Nodes not found after 10 mins"; exit 1; fi
      echo "INFO: Waiting for the nodes to become available"
      count=$((count+1))
      sleep 60
    done
  fi
  echo "INFO: Total number of nodes= $num_nodes"

  divider

  total_cpu=0
  total_mem=0
  i=0

  while [ $i -lt $num_nodes ]; do
    count=0
    node=$(oc get node -o jsonpath="{.items[$i].metadata.name}")
    if [[ $? -ne 0 ]]; then
      while true; do
        node=$(oc get node -o jsonpath="{.items[$i].metadata.name}")
        if [ $? -eq 0 ]; then break; fi
        if [ $count -eq 10  ]; then echo "Error: nodes not found after 10 attempts"; exit 1; fi
        echo "INFO: Waiting to fetch nodes"
        count=$((count+1))
        sleep 10
      done
    fi

    echo $node
    count=0
    cpu_nodes=$(oc get node $node -o jsonpath="{.status.allocatable.cpu}")
    if [[ $? -ne 0 ]]; then
      while true; do
        cpu_nodes=$(oc get node $node -o jsonpath="{.status.allocatable.cpu}")
        if [ $? -eq 0 ]; then break; fi
        if [ $count -eq 10  ]; then echo "Error: CPU not found after 10 attempts"; exit 1; fi
        echo "INFO: Waiting to fetch CPUs info from the nodes"
        count=$((count+1))
        sleep 10
      done
    fi
    #checking the cpu unit if its cores we convert it to m
    echo "  cpu = $cpu_nodes"
    cpu_unit=$(echo $cpu_nodes | sed 's/[^a-zA-Z]*//g')
    if [ -z "$cpu_unit" ]; then
      cpu_nodes=$(( $cpu_nodes * 1000 ))
      echo "  Converted to ${cpu_nodes}m";
      total_cpu=$((total_cpu + $cpu_nodes))
    else
      total_cpu=$((total_cpu + $(echo $cpu_nodes | sed 's/[^0-9]*//g')))
    fi

    count=0
    mem_nodes=$(oc get node $node -o jsonpath="{.status.allocatable.memory}")
    if [[ $? -ne 0 ]]; then
      while true; do
        mem_nodes=$(oc get node $node -o jsonpath="{.status.allocatable.memory}")
        if [ $? -eq 0 ]; then break; fi
        if [ $count -eq 10  ]; then echo "Error: Memory not found after 10 attempts"; exit 1; fi
        echo "INFO: Waiting to fetch memory info from the nodes"
        count=$((count+1))
        sleep 10
      done
    fi
    echo "  memory = $mem_nodes"
    mem_unit=$(echo $mem_nodes | sed 's/[^a-zA-Z]*//g')

    # This is the if to make sure the integer limit of bash is not exceeded
    if [ $total_mem -lt $mem_req_ki ]; then
        if [ "$mem_unit" = "Mi" ]; then
          tmp=$(echo $mem_nodes | sed 's/[^0-9]*//g')
          mem_nodes=$(( $tmp * 1024 ))
          echo "  Converted to ${mem_nodes} KiB";
          total_mem=$((total_mem + $mem_nodes))
        elif [ "$mem_unit" = "Gi" ]; then
          tmp=$(echo $mem_nodes | sed 's/[^0-9]*//g')
          mem_nodes=$(( ($tmp * 1024) * 1024 ))
          echo "  Converted to ${mem_nodes} KiB";
          total_mem=$((total_mem + $mem_nodes))
        elif [ -z "$mem_unit" ]; then
          tmp=$(echo $mem_nodes | sed 's/[^0-9]*//g')
          mem_nodes=$(( $tmp / 1024 ))
          echo "  Converted to ${mem_nodes} KiB";
          total_mem=$((total_mem + $mem_nodes))
        elif [ "$mem_unit" = "Ti" ] || [ "$mem_unit" = "Pi" ] || [ "$mem_unit" = "Ei" ] ; then
           echo "  Memory meets the requirements of the Demo"
           total_mem=${mem_req_ki}
        else
          total_mem=$((total_mem + $(echo $mem_nodes | sed 's/[^0-9]*//g')))
        fi
    fi #[ $total_mem -lt 2147483647 ]
    i=$((i+1))
  done

  divider

  mem_gi=$(( ($total_mem / 1024) / 1024))
  if [ ${mem_gi} -lt ${mem_req_gi} ]; then
    echo -e "$cross ERROR: You have $mem_gi GiB of allocatable memory. Minimum memory requirement for ${demo_products} is ${mem_req_gi} GiB"
    check=1
  else
    echo -e "$tick INFO: You have enough allocatable memory for the demo"
  fi

  divider

  if [ ${total_cpu} -lt ${cpu_req_m} ]; then
    echo -e "$cross ERROR: You have ${total_cpu}m allocatable cores. Minimum CPU needed for ${demo_products} is ${cpu_req_m}m cores"
    check=1
  else
    echo -e "$tick INFO: You have enough allocatable cpu for the demo"
  fi

  divider

fi #demoPreparation

if [[ $check -ne 0 ]]; then
  exit 1
fi
