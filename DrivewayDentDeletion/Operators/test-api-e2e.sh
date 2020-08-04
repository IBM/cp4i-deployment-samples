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
#   -c : <condensed_info> (true/false), whether to show the full post response or a condensed version - DEFAULT: false
#   -n : <namespace> (string), Defaults to "cp4i"
#
#   With defaults values
#     ./test-api-e2e.sh -n <namesapce>

function usage {
    echo "Usage: $0 -n <namespace> -t <imageTag> -c"
}

namespace="cp4i"
condensed_info=false
os_sed_flag=""
totalAceReplicas=0
totalMQReplicas=1
totalDemoPods=1
numberOfMatchesForImageTag=0

if [[ $(uname) == Darwin ]]; then
  os_sed_flag="-e"
fi

while getopts "n:t:c" opt; do
  case ${opt} in
    n ) namespace="$OPTARG"
      ;;
    t ) imageTag="$OPTARG"
      ;;
    c)
      condensed_info=true
      ;;
    \? ) usage; exit
      ;;
  esac
done

# Install jq for testing
sudo apt-get install jq

# Find the total number of replicas for ACE integration servers
allAceIntegrationServers=($(oc get integrationservers -n $namespace | grep ace | awk '{print $1}'))
for eachAceIntegrationServer in ${allAceIntegrationServers[@]}  
  do
    # numberOfeachReplica=$(oc get integrationservers $eachAceIntegrationServer -n $namespace | awk '{print $3}' | sed -n 2p)
    numberOfeachReplica=$(oc get integrationservers $eachAceIntegrationServer -n $namespace -o json | jq -r '.spec.replicas')
    echo "INFO: Number of Replicas for $eachAceIntegrationServer is $numberOfeachReplica"
    totalAceReplicas=$(($totalAceReplicas + $numberOfeachReplica))
done
totalDemoPods=$(($totalAceReplicas + $totalMQReplicas))

echo "INFO: Total number of ACE and MQ demo pods after deployment should be $totalDemoPods"

echo -e "\nINFO: Image tag: '$imageTag' \n"

echo "INFO: Going ahead to wait for all all pipelinerun pods to be completed..."

# Check if the pipelinerun pods are completed or not
time=0
numberOfPipelineRunPods=$(oc get pods -n $namespace | grep main-pipelinerun | grep ${imageTag} | grep Completed | wc -l | xargs)
while [ "$numberOfPipelineRunPods" != "10" ]; do
  if [ $time -gt 10 ]; then
    echo "ERROR: All pipeline run pods did not complete within 15 minutes"
    exit 1
  fi

  if [[ $(oc get pods -n $namespace | grep main-pipelinerun | grep ${imageTag} | grep Completed) ]]; then
    echo -e "\nINFO: The current state of pipelinerun pods are:"
    oc get pods -n $namespace | grep main-pipelinerun | grep ${imageTag} | grep Completed
  else
    echo "No matching pipelinerun pods found for the image tag '$imageTag'"
  fi

  echo -e "\nINFO: Waiting upto 10 minutes for all pipelinerun pods to be completed. Waited ${time} minute(s)."
  time=$((time + 1))
  numberOfPipelineRunPods=$(oc get pods -n $namespace | grep main-pipelinerun | grep ${imageTag} | grep Completed | wc -l | xargs)
  sleep 60
done

echo -e "\nINFO: All pipelinerun pods are completed, going ahead to wait for all related pods to be available...\n"
echo "INFO: The completed pipeline run pods are:"
oc get pods -n $namespace | grep main-pipelinerun | grep ${imageTag} | grep Completed

echo -e "\nINFO: Checking if the integration pods for ACE and MQ are available..."
# Check if the integration pods for ACE and MQ are available
time=0
numberOfAceMQDemoPods=$(oc get pods -n $namespace | grep -E 'mq-ddd-qm|ace-api-int-srv|ace-bernie-int-srv|ace-acme-int-srv|ace-chris-int-srv' | wc -l | xargs)
while [ "$numberOfAceMQDemoPods" != "$totalDemoPods" ]; do
  if [ $time -gt 10 ]; then
    echo "ERROR: All Integration demo pods for ace/mq not found"
    exit 1
  fi

  if [[ $(oc get pods -n $namespace | grep -E 'mq-ddd-qm|ace-api-int-srv|ace-bernie-int-srv|ace-acme-int-srv|ace-chris-int-srv') ]]; then
    echo -e "\nINFO: The available ACE and MQ pods are:"
    oc get pods -n $namespace | grep -E 'mq-ddd-qm|ace-api-int-srv|ace-bernie-int-srv|ace-acme-int-srv|ace-chris-int-srv'
  else
    echo "No available matching demo pods found for ACE/MQ.."
  fi
  
  echo -e "\nINFO: Waiting upto 10 minutes for all ACE and MQ deom pods to appear. Waited ${time} minute(s)."
  time=$((time + 1))
  numberOfAceMQDemoPods=$(oc get pods -n $namespace | grep -E 'mq-ddd-qm|ace-api-int-srv|ace-bernie-int-srv|ace-acme-int-srv|ace-chris-int-srv' | wc -l | xargs)
  sleep 60
done

echo -e "\nINFO: All ACE and MQ demo pods are available, going ahead to wait for them to be in ready and running state...\n"
echo "INFO: All available ACE and MQ demo pods are:"
oc get pods -n $namespace | grep -E 'mq-ddd-qm|ace-api-int-srv|ace-bernie-int-srv|ace-acme-int-srv|ace-chris-int-srv'

# Check if the integration pods for ACE and MQ are in Ready and Running state
time=0
numberOfReadyRunningAceMQDemoPods=$(oc get pods -n $namespace | grep -E 'mq-ddd-qm|ace-api-int-srv|ace-bernie-int-srv|ace-acme-int-srv|ace-chris-int-srv' | grep 1/1 | grep Running | awk '{print $3}' | wc -l | xargs)
while [ "$numberOfReadyRunningAceMQDemoPods" != "$totalDemoPods" ]; do
  if [ $time -gt 10 ]; then
    echo "ERROR: Integration demo pods for ace/mq not in Running state"
    exit 1
  fi

  if [[ $(oc get pods -n $namespace | grep -E 'mq-ddd-qm|ace-api-int-srv|ace-bernie-int-srv|ace-acme-int-srv|ace-chris-int-srv' | grep 1/1 | grep Running) ]]; then
    echo -e "\nINFO: The Ready and Running ACE and MQ demo pods are:"
    oc get pods -n $namespace | grep -E 'mq-ddd-qm|ace-api-int-srv|ace-bernie-int-srv|ace-acme-int-srv|ace-chris-int-srv' | grep 1/1 | grep Running
  else
    echo "No available matching demo pods found for ACE/MQ.."
  fi

  echo -e "\nINFO: Waiting upto 10 minutes for all integration demo pods to be in Ready and Running state. Waited ${time} minute(s)."
  time=$((time + 1))
  numberOfReadyRunningAceMQDemoPods=$(oc get pods -n $namespace | grep -E 'mq-ddd-qm|ace-api-int-srv|ace-bernie-int-srv|ace-acme-int-srv|ace-chris-int-srv' | grep 1/1 | grep Running | awk '{print $3}' | wc -l | xargs)
  sleep 60
done

echo -e "\nINFO: All demo pods are up, ready and in running state, going ahead with continuous load testing...\n"
echo "INFO: All Ready and Running ACE and MQ demo pods are:"
oc get pods -n $namespace | grep -E 'mq-ddd-qm|ace-api-int-srv|ace-bernie-int-srv|ace-acme-int-srv|ace-chris-int-srv' | grep 1/1 | grep Running

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"
# Waiting for all ace pods to be deployed with the new image
echo "INFO: Waiting for all ACE demo pods to be deployed with the new image .."

while [ $numberOfMatchesForImageTag -ne $totalDemoPods ]; do
  if [ $time -gt 10 ]; then
    echo "ERROR: Timed-out trying to match latest ACE pods deployed with a new image containing the image tag '$imageTag'"
    exit 1
  fi
  numberOfMatchesForImageTag=0
  for eachAceIntegrationServer in ${allAceIntegrationServers[@]}  
    do
      allCorrespondingPods=$(oc get pods -n $namespace | grep $eachAceIntegrationServer | grep 1/1 | grep Running | awk '{print $1}')
      echo -e "\nINFO: For ACE Integration server '$eachAceIntegrationServer':"
      for eachAcePod in $allCorrespondingPods
        do
          imageInPod=$(oc get pod $eachAcePod -n $namespace -o json | jq -r '.spec.containers[0].image')
          echo "INFO: Image present in the pod '$eachAcePod' is '$imageInPod'"
          if [[ $imageInPod =~ "$imageTag" ]]; then
            echo "INFO: Image tag matches.."
            numberOfMatchesForImageTag=$((numberOfMatchesForImageTag + 1))
          else
            echo "INFO: Image tag '$imageTag' is not present in the image of the pod '$eachAcePod'"
          fi
      done
  done

  mqDemoPod=$(oc get pods -n $namespace | grep mq-ddd-qm | awk '{print $1}')
  echo -e "\nINFO: For MQ demo pod '$mqDemoPod':"
  demoPodMQImage=$(oc get pod $mqDemoPod -n $namespace -o json | jq -r '.spec.containers[0].image')
  echo "INFO: Image present in the pod '$mqDemoPod' is '$demoPodMQImage'"
  if [[ $demoPodMQImage =~ "latest" ]]; then
    echo "INFO: Image tag matches for MQ demo pod.."
    numberOfMatchesForImageTag=$((numberOfMatchesForImageTag + 1))
  else
    echo "INFO: Image tag 'latest' is not present in the image of the MQ demo pod '$mqDemoPod'"
  fi

  echo -e "\nINFO: Total ACE and MQ demo pods deployed with new image are: $numberOfMatchesForImageTag"
  echo -e "\nINFO: All current ACE and MQ demo pods are:"
  oc get pods -n $namespace | grep -E 'mq-ddd-qm|ace-api-int-srv|ace-bernie-int-srv|ace-acme-int-srv|ace-chris-int-srv'
  if [[ $numberOfMatchesForImageTag != "$totalDemoPods" ]]; then
    echo -e "\nINFO: Not all image tags present in all ACE demo pod, retrying for upto 10 minutes for new ACE demo pods te be deployed with new image. Waited ${time} minute(s)."
    sleep 60
  else
    echo -e "\nINFO: All ACE and MQ demo pods have been deployed with the new image"
  fi
  time=$((time + 1))
  echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------"
done

export HOST=http://$(oc get routes -n ${namespace} | grep ace-api-int-srv-http | grep -v ace-api-int-srv-https | awk '{print $2}')/drivewayrepair
echo "INFO: Host: ${HOST}"

echo -e "\nINFO: POST request..."

post_response=$(curl -s -w " %{http_code}" -X POST ${HOST}/quote -d "{\"Name\": \"Mickey Mouse\",\"EMail\": \"MickeyMouse@us.ibm.com\",\"Address\": \"30DisneyLand\",\"USState\": \"FL\",\"LicensePlate\": \"MMM123\",\"DentLocations\": [{\"PanelType\": \"Door\",\"NumberOfDents\": 2},{\"PanelType\": \"Fender\",\"NumberOfDents\": 1}]}")
post_response_code=$(echo "${post_response##* }")

if [ "$post_response_code" == "200" ]; then
  # The usage of sed here is to prevent an error caused between the -w flag of curl and jq not interacting well
  quote_id=$(echo "$post_response" | jq '.' | sed $os_sed_flag '$ d' | jq '.QuoteID')

  echo -e "INFO: SUCCESS - POSTed with response code: ${post_response_code}, QuoteID: ${quote_id}, and Response Body:\n"
  if [ "$condensed_info" = true ]; then
    # The usage of sed here is to prevent an error caused between the -w flag of curl and jq not interacting well
    echo ${post_response} | jq '.' | sed $os_sed_flag '$ d' | jq '{ QuoteID: .QuoteID, Versions: .Versions }'
  else
    echo ${post_response} | jq '.' | sed $os_sed_flag '$ d'
  fi

  echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------"
  # - GET ---
  echo -e "\nINFO: GET request..."
  get_response=$(curl -s -w " %{http_code}" -X GET ${HOST}/quote?QuoteID=${quote_id})
  get_response_code=$(echo "${get_response##* }")

  if [ "$get_response_code" == "200" ]; then
    echo -e "INFO: SUCCESS - GET with response code: ${get_response_code}, and Response Body:\n"

    if [ "$condensed_info" = true ]; then
      # The usage of sed here is to prevent an error caused between the -w flag of curl and jq not interacting well
      echo ${get_response} | jq '.' | sed $os_sed_flag '$ d' | jq '.[0] | { QuoteID: .QuoteID, Email: .Email }'
    else
      echo ${get_response} | jq '.' | sed $os_sed_flag '$ d'
    fi
  else
    echo "ERROR: FAILED - Error code: ${get_response_code}"
    exit 1
  fi

  echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------"
  # Delete from the database
  echo -e "INFO: \nDeleting row from database..."
  oc exec -n postgres -it $(oc get pod -n postgres -l name=postgresql -o jsonpath='{.items[].metadata.name}') \
    -- psql -U admin -d sampledb -c \
    "DELETE FROM quotes WHERE quotes.quoteid = ${quote_id};"
  
else
  echo "ERROR: Post request failed - Error code: ${post_response_code}" # Failure catch during POST
  exit 1
fi
echo -e "----------------------------------------------------------------------------------------------------------------------------------------------------------"