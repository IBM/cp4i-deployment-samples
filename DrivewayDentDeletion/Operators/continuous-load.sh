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
#   -a : <api_base_url> (string), base url for the api endpoints - DEFAULT: the result of (oc get routes -n ace | grep ace-ddd-api-dev-http-ace | awk '{print $2}')/drivewayrepair")
#   -t : <retry_interval>, (integer), time in seconds between each load of data - DEFAULT: 5 (seconds)
#   -c : <should_cleanup_table> (true/false), whether to delete all rows from the test table - DEFAULT: false
#   -i : <condensed_info> (true/false), whether to show the full post response or a condensed version - DEFAULT: false
#   -s : <save_row_after_run> (true/false), whether to save each row in the database after a run or delete it DEFAULT: false
#   -n : <namespace> (string), Defaults to "cp4i"
#
# USAGE:
#   CAUTION - running without <should_cleanup_table> enabled can result in data leftover in the postgres table
#
#   With defaults values
#     ./continuous-load.sh
#
#   With cleanup and custom retry time
#     ./continuous-load.sh -t 2 -c

function usage() {
  echo "Usage: $0 -n <namespace> -a <api_base_url> -t <retry_interval> -c -i -s"
  exit 1
}

NAMESPACE="cp4i"
should_cleanup_table=false
condensed_info=false
save_row_after_run=false
retry_interval=5

while getopts "n:a:t:cis" opt; do
  case ${opt} in
    n )
      NAMESPACE="$OPTARG"
      ;;
    a)
      api_base_url="$OPTARG"
      ;;
    t)
      retry_interval="$OPTARG"
      ;;
    c)
      should_cleanup_table=true
      ;;
    i)
      condensed_info=true
      ;;
    s)
      save_row_after_run=true
      ;;
    \?)
      usage
      ;;
  esac
done

DB_USER=$(echo ${NAMESPACE} | sed 's/-/_/g')
DB_NAME=db_${DB_USER}
DB_PASS=$(oc get secret -n ${NAMESPACE} postgres-credential --template={{.data.password}} | base64 --decode)
DB_POD=$(oc get pod -n postgres -l name=postgresql -o jsonpath='{.items[].metadata.name}')
DB_SVC="$(oc get cm postgres-config -o json | jq '.data["postgres.env"] | split("\n  ")' | grep DATABASE_SERVICE_NAME | cut -d "=" -f 2- | tr -dc '[a-z0-9-]\n').postgres.svc.cluster.local"
echo "INFO: Username name is: '${DB_USER}'"
echo "INFO: Database name is: '${DB_NAME}'"

if [ -z "${api_base_url}" ]; then
  api_base_url=$(echo "http://$(oc get routes -n ${NAMESPACE} | grep ace-api-int-srv-http | grep -v ace-api-int-srv-https | awk '{print $2}')/drivewayrepair")
fi

echo "API base URL: $api_base_url"

os_sed_flag=""
if [[ $(uname) == Darwin ]]; then
  os_sed_flag="-e"
fi

function cleanup_table() {
  table_name="quotes"
  echo -e "\Clearing '${table_name}' database of all rows..."
  oc exec -n postgres -it ${DB_POD} \
    -- psql -U ${DB_USER} -d ${DB_NAME} -h ${DB_SVC} -c \
    "TRUNCATE ${table_name};"
}

# Catches any exit signals for cleanup
if [ "$should_cleanup_table" = true ]; then
  trap "cleanup_table" EXIT
fi

while true; do
  # - POST ---
  echo -e "\nPOST request..."
  post_response=$(curl -s -w " %{http_code}" -X POST ${api_base_url}/quote -d "{\"Name\": \"Mickey Mouse\",\"EMail\": \"MickeyMouse@us.ibm.com\",\"Address\": \"30DisneyLand\",\"USState\": \"FL\",\"LicensePlate\": \"MMM123\",\"DentLocations\": [{\"PanelType\": \"Door\",\"NumberOfDents\": 2},{\"PanelType\": \"Fender\",\"NumberOfDents\": 1}]}")
  post_response_code=$(echo "${post_response##* }")

  if [ "$post_response_code" == "200" ]; then
    # The usage of sed here is to prevent an error caused between the -w flag of curl and jq not interacting well
    quote_id=$(echo "$post_response" | jq '.' | sed $os_sed_flag '$ d' | jq '.QuoteID')

    echo -e "SUCCESS - POSTed with response code: ${post_response_code}, QuoteID: ${quote_id}, and Response Body:\n"
    if [ "$condensed_info" = true ]; then
      # The usage of sed here is to prevent an error caused between the -w flag of curl and jq not interacting well
      echo ${post_response} | jq '.' | sed $os_sed_flag '$ d' | jq '{ QuoteID: .QuoteID, Versions: .Versions }'
    else
      echo ${post_response} | jq '.' | sed $os_sed_flag '$ d'
    fi

    # - GET ---
    echo -e "\nGET request..."
    get_response=$(curl -s -w " %{http_code}" -X GET ${api_base_url}/quote?QuoteID=${quote_id})
    get_response_code=$(echo "${get_response##* }")

    if [ "$get_response_code" == "200" ]; then
      echo -e "SUCCESS - GETed with response code: ${get_response_code}, and Response Body:\n"

      if [ "$condensed_info" = true ]; then
        # The usage of sed here is to prevent an error caused between the -w flag of curl and jq not interacting well
        echo ${get_response} | jq '.' | sed $os_sed_flag '$ d' | jq '.[0] | { QuoteID: .QuoteID, Email: .Email }'
      else
        echo ${get_response} | jq '.' | sed $os_sed_flag '$ d'
      fi
    else
      echo "FAILED - Error code: ${get_response_code}"
    fi

    # - DELETE ---
    if [ "$save_row_after_run" = false ]; then
      echo -e "\nDeleting row from database..."
      oc exec -n postgres -it ${DB_POD} \
        -- psql -U ${DB_USER} -d ${DB_NAME} -h ${DB_SVC} -c \
        "DELETE FROM quotes WHERE quotes.quoteid = ${quote_id};"
    fi
  else
    echo "FAILED - Error code: ${post_response_code}" # Failure catch during POST
  fi

  echo -e "\n--------------------------------------------------------------------\n"
  sleep ${retry_interval}
done
