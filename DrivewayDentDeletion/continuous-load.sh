#!/bin/bash
#******************************************************************************
# Licensed Materials - Property of IBM
# (c) Copyright IBM Corporation 2020. All Rights Reserved.
#
# Note to U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.
#******************************************************************************
# PREREQUISITES:
#   - Logged into cluster on the OC CLI (https://docs.openshift.com/container-platform/4.4/cli_reference/openshift_cli/getting-started-cli.html)
#
# PARAMETERS:
#   -a : <api_base_url> (string), base url for the api endpoints 
#   -t : <retry_interval>, (integer), time in seconds between each load of data
#   -c : <should_cleanup_table> (true/false), whether to delete all rows from the test table
#
# USAGE:
#   CAUTION - running without <should_cleanup_table> enabled can result in data leftover in the postgres table
#
#   With defaults values
#     ./continuous-load.sh 
#
#   With cleanup and custom retry time
#     ./continuous-load.sh -t 2 -c

function usage {
    echo "Usage: $0 -a <api_base_url> -t <retry_interval> -c <should_cleanup_table>"
}

should_cleanup_table=false
api_base_url=$(echo "http://$(oc get routes -n ace | grep ace-ddd-api-dev-http-ace | awk '{print $2}')/drivewayrepair")
retry_interval=5

while getopts ":a:t:c" opt; do
  case ${opt} in
    a ) api_base_url="$OPTARG"
      ;;
    t ) retry_interval="$OPTARG"
      ;;
    c ) should_cleanup_table=true
      ;;
    \? ) usage
      ;;
  esac
done

cp_client_platform=linux-amd64
if [[ $(uname) == Darwin ]]; then
    cp_client_platform=darwin-amd64
fi

function cleanup_table {
  table_name="quotes"
  echo -e "\Clearing '${table_name}' database of all rows..."
  oc exec -n postgres -it $(oc get pod -n postgres -l name=postgresql -o jsonpath='{.items[].metadata.name}') \
      -- psql -U admin -d sampledb -c \
    "TRUNCATE ${table_name};"
}

# Catches any exit signals for cleanup 
if [ "$should_cleanup_table" = true ] ; then
  trap "cleanup_table" EXIT
fi

while true; do
  # - POST ---
  echo -e "\nPOST request..."
  post_response=$(curl -s -w " %{http_code}" -X POST ${api_base_url}/quote -d "{\"Name\": \"Mickey Mouse\",\"EMail\": \"MickeyMouse@us.ibm.com\",\"Address\": \"30DisneyLand\",\"USState\": \"FL\",\"LicensePlate\": \"MMM123\",\"DentLocations\": [{\"PanelType\": \"Door\",\"NumberOfDents\": 2},{\"PanelType\": \"Fender\",\"NumberOfDents\": 1}]}")
  post_response_code=$(echo "${post_response##* }") 

  if [ "$post_response_code" == "200" ]; then
    # The usage of sed here is to prevent an error caused between the -w flag of curl and jq not interacting well
    if [ "$cp_client_platform" == "linux-amd64" ]; then
      quote_id=$(echo "$post_response" | jq '.' | sed '$ d' | jq '.QuoteID')
    else
      quote_id=$(echo "$post_response" | jq '.' | sed -e '$ d' | jq '.QuoteID')
    fi
    echo "SUCCESS - POSTed with response code: ${post_response_code}, and QuoteID: ${quote_id}" 

    # - GET ---
    echo -e "\nGET request..."  
    get_response=$(curl -s -w " %{http_code}" -X GET ${api_base_url}/quote?QuoteID=${quote_id})
    get_response_code=$(echo "${get_response##* }")

    if [ "$get_response_code" == "200" ]; then
      echo -e "SUCCESS - GETed with response code: ${get_response_code}, and Response Body:\n"
      if [ "$cp_client_platform" == "linux-amd64" ]; then
        # The usage of sed here is to prevent an error caused between the -w flag of curl and jq not interacting well
        echo ${get_response} | jq '.' | sed '$ d'
      else
        echo ${get_response} | jq '.' | sed -e '$ d'
      fi
    else
      echo "FAILED - Error code: ${get_response_code}"
    fi

    # - DELETE ---
    echo -e "\nDeleting row from database..."
    oc exec -n postgres -it $(oc get pod -n postgres -l name=postgresql -o jsonpath='{.items[].metadata.name}') \
      -- psql -U admin -d sampledb -c \
    "DELETE FROM quotes WHERE quotes.quoteid = ${quote_id};"
  else
    echo "FAILED - Error code: ${post_response_code}" # Failure catch during POST
  fi

  echo -e "\n--------------------------------------------------------------------\n"
  sleep ${retry_interval}
done
