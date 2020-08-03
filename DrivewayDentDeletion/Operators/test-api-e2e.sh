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
if [[ $(uname) == Darwin ]]; then
  os_sed_flag="-e"
fi

while getopts "n:ti" opt; do
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

# Check if the integration pods for ACE and MQ are in Ready and Running state
time=0
numberOfReadyRunningDemoPods=$(oc get pods -n ${namespace} | grep -E "int-srv-${imageTag}|mq-ddd-qm-latest" | grep -v pipelinerun | grep 1/1 | awk '{print $3}' | wc -l | xargs)
while [ "$numberOfReadyRunningDemoPods" != "9" ]; do
  if [ $time -gt 30 ]; then
    echo "ERROR: Integration demo pods for ace/mq not in Ready and Running state'"
    exit 1
  fi
  echo "INFO: Waiting upto 30 minutes for all integration demo pods to be in Ready and Running state. Waited ${time} minute(s)."
  time=$((time + 1))
  numberOfReadyRunningDemoPods=$(oc get pods -n ${namespace} | grep -E "int-srv-${imageTag}|mq-ddd-qm-latest" | grep -v pipelinerun | grep 1/1 | awk '{print $3}' | wc -l | xargs)
  echo "INFO: The integration server pods are:"
  oc get pods | grep -E "int-srv-${imageTag}|mq-ddd-qm-latest"
  sleep 60
done

echo "INFO: All demo pods are up, ready and in running state, going ahead with testing API..."
echo "INFO: The integration server and mq pods are:"
oc get pods | grep -E "int-srv-${imageTag}|mq-ddd-qm-latest"

echo -e "\nINFO: POST request..."
export HOST=http://$(oc get routes -n ${namespace} | grep ace-api-int-srv-http | grep -v ace-api-int-srv-https | awk '{print $2}')/drivewayrepair
echo "INFO: Host: ${HOST}"
# curl -X POST ${HOST}/quote -d "{\"Name\": \"Mickey Mouse\",\"EMail\": \"MickeyMouse@us.ibm.com\",\"Address\": \"30DisneyLand\",\"USState\": \"FL\",\"LicensePlate\": \"MMM123\",\"DentLocations\": [{\"PanelType\": \"Door\",\"NumberOfDents\": 2},{\"PanelType\": \"Fender\",\"NumberOfDents\": 1}]}"

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

  # - GET ---
  echo -e "\nINFO: GET request..."
  get_response=$(curl -s -w " %{http_code}" -X GET ${HOST}/quote?QuoteID=${quote_id})
  get_response_code=$(echo "${get_response##* }")

  if [ "$get_response_code" == "200" ]; then
    echo -e "INFO: SUCCESS - GETed with response code: ${get_response_code}, and Response Body:\n"

    if [ "$condensed_info" = true ]; then
      # The usage of sed here is to prevent an error caused between the -w flag of curl and jq not interacting well
      echo ${get_response} | jq '.' | sed $os_sed_flag '$ d' | jq '.[0] | { QuoteID: .QuoteID, Email: .Email }'
    else
      echo ${get_response} | jq '.' | sed $os_sed_flag '$ d'
    fi
  else
    echo "ERROR: FAILED - Error code: ${get_response_code}"
  fi

  echo -e "INFO: \nDeleting row from database..."
  oc exec -n postgres -it $(oc get pod -n postgres -l name=postgresql -o jsonpath='{.items[].metadata.name}') \
    -- psql -U admin -d sampledb -c \
    "DELETE FROM quotes WHERE quotes.quoteid = ${quote_id};"
else
  echo "ERROR: FAILED - Error code: ${post_response_code}" # Failure catch during POST
fi