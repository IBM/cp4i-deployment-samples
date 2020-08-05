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
#   -n : <namespace> (string), Defaults to "cp4i"
#   -t : <imageTag> (string), Default is empty
#
#   With defaults values
#     ./test-api-e2e.sh -n <namesapce>

function usage {
    echo "Usage: $0 -n <namespace> -t <imageTag> -c"
}

namespace="cp4i"
os_sed_flag=""
totalAceReplicas=0
totalMQReplicas=1
totalDemoPods=0
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
    \? ) usage; exit
      ;;
  esac
done

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

echo "INFO: Image tag: '$imageTag'"

# -------------------------------------- INSTALL JQ ------------------------------------------

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

# Install jq for testing
echo "INFO: Installing jq..."
wget -O jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64
chmod +x ./jq
cp jq /usr/bin
echo -e "\nINFO: Installed JQ version is $(jq --version)"

# -------------------------------------- FIND TOTAL ACE REPLICAS DEPLOYED ------------------------------------------

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"
# Find the total number of replicas for ACE integration servers
allAceIntegrationServers=($(oc get integrationservers -n $namespace | grep ace | awk '{print $1}'))
for eachAceIntegrationServer in ${allAceIntegrationServers[@]}  
  do
    numberOfeachReplica=$(oc get integrationservers $eachAceIntegrationServer -n $namespace -o json | jq -r '.spec.replicas')
    echo "INFO: Number of Replicas for $eachAceIntegrationServer is $numberOfeachReplica"
    totalAceReplicas=$(($totalAceReplicas + $numberOfeachReplica))
done

totalDemoPods=$(($totalAceReplicas + $totalMQReplicas))

echo -e "\nINFO: Total number of ACE and MQ demo pods after deployment should be $totalDemoPods"

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

echo "INFO: Going ahead to wait for all ACE and MQ pipelinerun pods to be completed..."

# -------------------------------------- WAIT FOR PIPELINE RUN PODS TO COMPLETE ------------------------------------------

# Check if the pipelinerun pods for ACE and MQ (build and deploy) have completed or not
time=0
numberOfPipelineRunPods=$(oc get pods -n $namespace | grep main-pipelinerun | grep ${imageTag} | grep Completed | grep -v api-test | wc -l | xargs)
while [ "$numberOfPipelineRunPods" != "10" ]; do
  if [ $time -gt 10 ]; then
    echo "ERROR: All pipeline run pods did not complete within 15 minutes"
    echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"
    exit 1
  fi

  mainPipelineRunPodsAceMq=$(oc get pods -n $namespace | grep main-pipelinerun | grep ${imageTag} | grep Completed | grep -v api-test)
  if [[ $mainPipelineRunPodsAceMq ]]; then
    echo -e "\nINFO: The current state of pipelinerun pods are:"
    echo $mainPipelineRunPodsAceMq
  else
    echo "No matching pipelinerun pods found for the image tag '$imageTag' yet"
  fi

  echo -e "\nINFO: Waiting upto 10 minutes for all pipelinerun pods to be completed. Waited ${time} minute(s)."
  time=$((time + 1))
  numberOfPipelineRunPods=$(oc get pods -n $namespace | grep main-pipelinerun | grep ${imageTag} | grep Completed | grep -v api-test | wc -l | xargs)
  sleep 60
done

echo -e "\nINFO: All pipelinerun pods are completed, going ahead to wait for all related pods to be available...\n"
echo "INFO: The completed pipeline run pods are:"
oc get pods -n $namespace | grep main-pipelinerun | grep ${imageTag} | grep Completed | grep -v api-test

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

# -------------------------------------- CHECK AVAILABLE, READY AND RUNNING ACE/MQ DEMO PODS ------------------------------------------

echo -e "\nINFO: Checking if the integration pods for ACE and MQ are available, ready and in running state..."
# Check if the integration pods for ACE and MQ are available, ready and in running state
time=0
numberOfAceMQDemoPods=$(oc get pods -n $namespace | grep -E 'mq-ddd-qm|ace-api-int-srv|ace-bernie-int-srv|ace-acme-int-srv|ace-chris-int-srv' | grep 1/1 | grep Running | wc -l | xargs)
while [ "$numberOfAceMQDemoPods" != "$totalDemoPods" ]; do
  if [ $time -gt 10 ]; then
    echo "ERROR: All Integration demo pods for ace/mq not found or are not in ready and running state"
    echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"
    exit 1
  fi

  if [[ $(oc get pods -n $namespace | grep -E 'mq-ddd-qm|ace-api-int-srv|ace-bernie-int-srv|ace-acme-int-srv|ace-chris-int-srv' | grep 1/1 | grep Running) ]]; then
    echo -e "\nINFO: The current state of ACE and MQ pods are:"
    oc get pods -n $namespace | grep -E 'mq-ddd-qm|ace-api-int-srv|ace-bernie-int-srv|ace-acme-int-srv|ace-chris-int-srv' | grep 1/1 | grep Running
  else
    echo "No matching available, ready and running demo pods found for ACE/MQ yet.."
  fi
  
  echo -e "\nINFO: Waiting upto 10 minutes for all ACE and MQ demo pods to be available, ready and in running state. Waited ${time} minute(s)."
  time=$((time + 1))
  numberOfAceMQDemoPods=$(oc get pods -n $namespace | grep -E 'mq-ddd-qm|ace-api-int-srv|ace-bernie-int-srv|ace-acme-int-srv|ace-chris-int-srv' | grep 1/1 | grep Running | wc -l | xargs)
  sleep 60
done

echo -e "\nINFO: All ACE and MQ demo pods are available, ready and in running state, going ahead to wait for them to be in ready and running state...\n"
echo "INFO: All available, ready and running ACE and MQ demo pods are:"
oc get pods -n $namespace | grep -E 'mq-ddd-qm|ace-api-int-srv|ace-bernie-int-srv|ace-acme-int-srv|ace-chris-int-srv' | grep 1/1 | grep Running

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

# -------------------------------------- CHECK FOR NEW IMAGE DEPLOYMENT STATUS IN ACE AND MQ DEMO PODS ------------------------------------------

# Waiting for all ace pods to be deployed with the new image
echo "INFO: Checking and waiting for all ACE demo pods to be deployed with the new image .."

while [ $numberOfMatchesForImageTag -ne $totalDemoPods ]; do
  if [ $time -gt 10 ]; then
    echo "ERROR: Timed-out trying to wait for all ACE and MQ pods to be deployed with a new image containing the image tag '$imageTag' for ACE and 'latest' for MQ."
    echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"
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
  echo -e "\nINFO: All current ACE and MQ demo pods are:\n"
  oc get pods -n $namespace | grep -E 'mq-ddd-qm|ace-api-int-srv|ace-bernie-int-srv|ace-acme-int-srv|ace-chris-int-srv' | grep 1/1 | grep Running
  if [[ $numberOfMatchesForImageTag != "$totalDemoPods" ]]; then
    echo -e "\nINFO: Not all ACE/MQ pods have been deployed with the new image, retrying for upto 10 minutes for new ACE and MQ demo pods te be deployed with new image. Waited ${time} minute(s)."
    sleep 60
  else
    echo -e "\nINFO: All ACE and MQ demo pods have been deployed with the new image"
  fi
  time=$((time + 1))
  echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------"
done

# -------------------------------------- TEST E2E API ------------------------------------------

export HOST=http://$(oc get routes -n ${namespace} | grep ace-api-int-srv-http | grep -v ace-api-int-srv-https | awk '{print $2}')/drivewayrepair
echo "INFO: Host: ${HOST}"

echo -e "\nINFO: Testing E2E API now..."

# ------- Post to the database -------
post_response=$(curl -s -w " %{http_code}" -X POST ${HOST}/quote -d "{\"Name\": \"Mickey Mouse\",\"EMail\": \"MickeyMouse@us.ibm.com\",\"Address\": \"30DisneyLand\",\"USState\": \"FL\",\"LicensePlate\": \"MMM123\",\"DentLocations\": [{\"PanelType\": \"Door\",\"NumberOfDents\": 2},{\"PanelType\": \"Fender\",\"NumberOfDents\": 1}]}")
post_response_code=$(echo "${post_response##* }")

if [ "$post_response_code" == "200" ]; then
  # The usage of sed here is to prevent an error caused between the -w flag of curl and jq not interacting well
  quote_id=$(echo "$post_response" | jq '.' | sed $os_sed_flag '$ d' | jq '.QuoteID')

  echo -e "INFO: SUCCESS - POST with response code: ${post_response_code}, QuoteID: ${quote_id}, and Response Body:\n"
  # The usage of sed here is to prevent an error caused between the -w flag of curl and jq not interacting well
  echo ${post_response} | jq '.' | sed $os_sed_flag '$ d'

  echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------"

  # ------- Get from the database -------
  echo -e "\nINFO: GET request..."
  get_response=$(curl -s -w " %{http_code}" -X GET ${HOST}/quote?QuoteID=${quote_id})
  get_response_code=$(echo "${get_response##* }")

  if [ "$get_response_code" == "200" ]; then
    echo -e "INFO: SUCCESS - GET with response code: ${get_response_code}, and Response Body:\n"
    # The usage of sed here is to prevent an error caused between the -w flag of curl and jq not interacting well
    echo ${get_response} | jq '.' | sed $os_sed_flag '$ d'
  else
    echo "ERROR: FAILED - Error code: ${get_response_code}"
    echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"
    exit 1
  fi

  echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------"
  # ------- Delete from the database -------
  echo -e "\nINFO: Deleting row from database..."
  echo "INFO: Deleting the row with quote id $quote_id from the database"
  oc exec -n postgres -it $(oc get pod -n postgres -l name=postgresql -o jsonpath='{.items[].metadata.name}') \
    -- psql -U admin -d sampledb -c \
    "DELETE FROM quotes WHERE quotes.quoteid=${quote_id};"

  echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------"

  #  ------- Get row to confirm deletion -------
  echo -e "\nINFO: Select and print the row from database with '$quote_id' to confirm deletion"
  oc exec -n postgres -it $(oc get pod -n postgres -l name=postgresql -o jsonpath='{.items[].metadata.name}') \
    -- psql -U admin -d sampledb -c \
    "SELECT * FROM quotes WHERE quotes.quoteid=${quote_id};"
  
else
  # Failure catch during POST
  echo "ERROR: Post request failed - Error code: ${post_response_code}"
  exit 1
fi
echo -e "----------------------------------------------------------------------------------------------------------------------------------------------------------"
