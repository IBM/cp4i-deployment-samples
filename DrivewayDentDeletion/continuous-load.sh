#!/bin/bash
#******************************************************************************
# Licensed Materials - Property of IBM
# (c) Copyright IBM Corporation 2020. All Rights Reserved.
#
# Note to U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.
#******************************************************************************
#
# INSTRUCTIONS
# ------------
#
# 1. Run the script, passing the ACE server's REST API Base URL as an argument:
#       ./continuous-load.sh <api-base-url> <seconds-between-retries (OPTIONAL)>
#       e.g. http://ace-ddd-api-dev-http-ace.<cluster-name>.eu-eb.containers.appdomain.cloud/drivewayrepair 5

function usage {
    echo "Usage: $0 <api-base-url> <seconds-between-retries>"
}

cp_console="$1"
retry_interval="$2"

if [[ -z "${retry_interval}" ]]; then
    retry_interval=5
fi

if [[ -z "${cp_console}" ]]; then
    usage
    exit 2
fi

cp_client_platform=linux-amd64
if [[ $(uname) == Darwin ]]; then
    cp_client_platform=darwin-amd64
fi

while true; do
  # POST
  echo -e "\nPOST request..."
  post_response=$(curl -s -w " %{http_code}" -X POST ${cp_console}/quote -d "{\"Name\": \"Mickey Mouse\",\"EMail\": \"MickeyMouse@us.ibm.com\",\"Address\": \"30DisneyLand\",\"USState\": \"FL\",\"LicensePlate\": \"MMM123\",\"DentLocations\": [{\"PanelType\": \"Door\",\"NumberOfDents\": 2},{\"PanelType\": \"Fender\",\"NumberOfDents\": 1}]}")
  post_response_code=$(echo "${post_response##* }") 

  if [ "$post_response_code" == "200" ]; then
    # The usage of sed here is to prevent an error caused between the -w flag of curl and jq not interacting well
    if [ "$cp_client_platform" == "linux-amd64" ]; then
      quote_id=$(echo "$post_response" | jq '.' | sed '$ d' | jq '.QuoteID')
    else
      quote_id=$(echo "$post_response" | jq '.' | sed -e '$ d' | jq '.QuoteID')
    fi
    echo "SUCCESS - POSTed with response code: ${post_response_code}, and QuoteID: ${quote_id}" 

    # GET
    echo -e "\nGET request..."  
    get_response=$(curl -s -w " %{http_code}" -X GET ${cp_console}/quote?QuoteID=${quote_id})
    get_response_code=$(echo "${get_response##* }")

    if [ "$get_response_code" == "200" ]; then
      echo -e "SUCCESS - GETed with response code: ${get_response_code}, and Response Body:\n"
      if [ "$cp_client_platform" == "linux-amd64" ]; then
        echo ${get_response} | jq '.' | sed '$ d'
      else
        echo ${get_response} | jq '.' | sed -e '$ d'
      fi
    else
      echo "FAILED - Error code: ${get_response_code}"
    fi

    # DELETE 
    echo -e "\nDeleting row from database..."
    oc exec -n postgres -it $(oc get pod -n postgres -l name=postgresql -o jsonpath='{.items[].metadata.name}') \
      -- psql -U admin -d sampledb -c \
    "DELETE FROM quotes WHERE quotes.quoteid = ${quote_id};"
  else
    echo "FAILED - Error code: ${post_response_code}" # End of POST
  fi

  echo -e "\n--------------------------------------------------------------------\n"
  sleep ${retry_interval}
done

# ----------------------------------------------------------------------