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
#   -n : NAMESPACE (string), namespace - Default: cp4i
#   -u : API_BASE_URL (string), base url for the api endpoints - DEFAULT: result of (oc get routes -n $NAMESPACE | grep ace-ddd-api-dev-http-ace | awk '{print $2}')/drivewayrepair")
#   -t : RETRY_INTERVAL (integer), time in seconds between each load of data - DEFAULT: 5 (seconds)
#   -a : APIC (true/false), whether apic integration is enabled - DEFAULT: false
#   -c : TABLE_CLEANUP (true/false), whether to delete all rows from the test table - DEFAULT: false
#   -d : DEBUG (true/false), whether to enable debug output - DEFAULT: false
#   -i : CONDENSED_INFO (true/false), whether to show the full post response or a condensed version - DEFAULT: false
#   -s : SAVE_ROW_AFTER_RUN (true/false), whether to save each row in the database after a run or delete it - DEFAULT: false
#   -z : NUMBER_OF_CALLS (integer), run continuous load calls fixed number of times.
#   -p : <POSTGRES_NAMESPACE> (string), Namespace where postgres is setup, Defaults to value for '<NAMESPACE>'
#   -b : <DDD_TYPE> (string), Driveway dent deletion demo type for postgres credential, Defaults to "dev"
#
# USAGE:
#   CAUTION - running without TABLE_CLEANUP enabled can result in data leftover in the postgres table
#
#   With defaults values
#     ./continuous-load.sh
#
#   With cleanup and custom retry time
#     ./continuous-load.sh -t 2 -c

function usage() {
  echo "Usage: $0 [-n NAMESPACE] [-u API_BASE_URL] [-t RETRY_INTERVAL] [-p POSTGRES_NAMESPACE] [-b DDD_TYPE] [-acdisz]"
  exit 1
}

function divider() {
  echo -e "\n-------------------------------------------------------------------------------------------------------------------\n"
}

NAMESPACE="cp4i"
RETRY_INTERVAL=5
APIC=false
TABLE_CLEANUP=false
DEBUG=false
CONDENSED_INFO=false
SAVE_ROW_AFTER_RUN=false
GET_ERROR=0
POST_ERROR=0
CALLS_DONE=0
TICK="\xE2\x9C\x85"
CROSS="\xE2\x9D\x8C"
ALL_DONE="\xF0\x9F\x92\xAF"
INFO="\xE2\x84\xB9"
POSTGRES_NAMESPACE=$NAMESPACE
DDD_TYPE="dev"
DEFAULT_POSTGRES_CREDENTIAL_SECRET="postgres-credential-ddd"

while getopts "n:u:t:p:b:z:acdis" opt; do
  case ${opt} in
  n)
    NAMESPACE="$OPTARG"
    ;;
  u)
    API_BASE_URL="$OPTARG"
    ;;
  t)
    RETRY_INTERVAL="$OPTARG"
    ;;
  a)
    APIC=true
    ;;
  c)
    TABLE_CLEANUP=true
    ;;
  d)
    DEBUG=true
    ;;
  i)
    CONDENSED_INFO=true
    ;;
  s)
    SAVE_ROW_AFTER_RUN=true
    ;;
  z)
    NUMBER_OF_CALLS="$OPTARG"
    ;;
  p)
    POSTGRES_NAMESPACE="$OPTARG"
    ;;
  b)
    DDD_TYPE="$OPTARG"
    ;;
  \?)
    usage
    ;;
  esac
done

echo "[INFO] Driveway dent deletion demo type: '$DDD_TYPE'"
DB_USER=$(echo $NAMESPACE | sed 's/-/_/g')_${DDD_TYPE}_ddd
DB_NAME=db_${DB_USER}
DB_PASS=$(oc get secret -n $NAMESPACE ${DEFAULT_POSTGRES_CREDENTIAL_SECRET}-${DDD_TYPE} --template={{.data.password}} | base64 --decode)
DB_POD=$(oc get pod -n $POSTGRES_NAMESPACE -l name=postgresql -o jsonpath='{.items[].metadata.name}')
echo "[INFO] Username name is: '$DB_USER'"
echo "[INFO] Database name is: '$DB_NAME'"

CURL_OPTS=(-s -L -S -k)
if [[ $APIC == true ]]; then
  $DEBUG && echo "[DEBUG] apic integration enabled"
  ENDPOINT_SECRET_NAME="ddd-${DDD_TYPE}-api-endpoint-client-id"
  API_BASE_URL=$(oc get secret -n $NAMESPACE ${ENDPOINT_SECRET_NAME} -o jsonpath='{.data.api}' | base64 --decode)
  API_CLIENT_ID=$(oc get secret -n $NAMESPACE ${ENDPOINT_SECRET_NAME} -o jsonpath='{.data.cid}' | base64 --decode)
  echo -e "[INFO] api base url: ${API_BASE_URL}\n[INFO] client id: ${API_CLIENT_ID}"
fi
if [ -z "${API_BASE_URL}" ]; then
  API_BASE_URL=$(echo "https://$(oc get routes -n $NAMESPACE | grep ddd-${DDD_TYPE}-ace-api-https | awk '{print $2}')/drivewayrepair")
  echo "[INFO] api base URL: ${API_BASE_URL}"
fi

os_sed_flag=""
if [[ $(uname) == Darwin ]]; then
  os_sed_flag="-e"
fi

function cleanup_table() {
  table_name="quotes"
  echo -e "\Clearing '${table_name}' database of all rows..."
  oc exec -n $POSTGRES_NAMESPACE -it ${DB_POD} -- \
    psql -U ${DB_USER} -d ${DB_NAME} -c \
    "TRUNCATE ${table_name};"
}

# Catches any exit signals for cleanup
if [ "$TABLE_CLEANUP" = true ]; then
  trap "cleanup_table" EXIT
fi

API_AUTH=$(oc get secret -n $NAMESPACE ace-api-creds-ddd -o json | jq -r '.data.auth')

echo "api auth: $API_AUTH"

while true; do
  # - POST ---
  echo -e "\nPOST request..."
  post_response=$(curl ${CURL_OPTS[@]} -w " %{http_code}" -X POST ${API_BASE_URL}/quote \
    -H "authorization: Basic ${API_AUTH}" \
    -H "X-IBM-CLIENT-ID: ${API_CLIENT_ID}" \
    -d "{
      \"Name\": \"Jane Doe\",
      \"EMail\": \"janedoe@example.com\",
      \"Address\": \"123 Fake Road\",
      \"USState\": \"FL\",
      \"LicensePlate\": \"MMM123\",
      \"DentLocations\": [
        {
          \"PanelType\": \"Door\",
          \"NumberOfDents\": 2
        },
        {
          \"PanelType\": \"Fender\",
          \"NumberOfDents\": 1
        }
      ]
    }")

  post_response_code=$(echo "${post_response##* }")
  $DEBUG && echo "[DEBUG] post response: ${post_response}"

  CALLS_DONE=$(($CALLS_DONE + 1))

  if [ "$post_response_code" == "200" ]; then
    # The usage of sed here is to prevent an error caused between the -w flag of curl and jq not interacting well
    quote_id=$(echo "$post_response" | jq '.' | sed $os_sed_flag '$ d' | jq '.QuoteID')

    echo -e "SUCCESS - POSTed with response code: ${post_response_code}, QuoteID: ${quote_id}, and Response Body:\n"
    if [ "$CONDENSED_INFO" = true ]; then
      # The usage of sed here is to prevent an error caused between the -w flag of curl and jq not interacting well
      echo ${post_response} | jq '.' | sed $os_sed_flag '$ d' | jq '{ QuoteID: .QuoteID, Versions: .Versions }'
    else
      echo ${post_response} | jq '.' | sed $os_sed_flag '$ d'
    fi

    # - GET ---
    echo -e "\nGET request..."
    get_response=$(curl ${CURL_OPTS[@]} -w " %{http_code}" -X GET ${API_BASE_URL}/quote?QuoteID=${quote_id} \
      -H "authorization: Basic ${API_AUTH}" \
      -H "X-IBM-CLIENT-ID: ${API_CLIENT_ID}")
    get_response_code=$(echo "${get_response##* }")
    $DEBUG && echo "[DEBUG] get response: ${get_response}"

    if [ "$get_response_code" == "200" ]; then
      echo -e "SUCCESS - GETed with response code: ${get_response_code}, and Response Body:\n"

      if [ "$CONDENSED_INFO" = true ]; then
        # The usage of sed here is to prevent an error caused between the -w flag of curl and jq not interacting well
        echo ${get_response} | jq '.' | sed $os_sed_flag '$ d' | jq '.[0] | { QuoteID: .QuoteID, Email: .Email }'
      else
        echo ${get_response} | jq '.' | sed $os_sed_flag '$ d'
      fi
    else
      echo "FAILED - Error code: ${get_response_code}"
      GET_ERROR=$(($GET_ERROR + 1))
    fi

    # - DELETE ---
    if [ "$SAVE_ROW_AFTER_RUN" = false ]; then
      echo -e "\nDeleting row from database..."
      oc exec -n $POSTGRES_NAMESPACE -it ${DB_POD} -- \
        psql -U ${DB_USER} -d ${DB_NAME} -c \
        "DELETE FROM quotes WHERE quotes.quoteid = ${quote_id};"
    fi
  else
    echo "FAILED - Error code: ${post_response_code}" # Failure catch during POST
    POST_ERROR=$(($POST_ERROR + 1))
  fi

  if [[ ($NUMBER_OF_CALLS) && ("$NUMBER_OF_CALLS" -eq "$CALLS_DONE") ]]; then
    if [[ ("$GET_ERROR" -eq 0) && ("$POST_ERROR" -eq 0) ]]; then
      divider
      echo -e "$INFO INFO: Continuous load testing successfully completed with '$NUMBER_OF_CALLS' call(s) and zero errors."
      exit 0
    fi
  fi

  if [[ ("$GET_ERROR" -gt 0) || ("$POST_ERROR" -gt 0) ]]; then
    divider
    echo -e "$INFO INFO: POST and GET calls made: ${CALLS_DONE}, POST errors: $POST_ERROR, GET errors: $GET_ERROR"
    echo -e "$CROSS ERROR: Continuous load testing failed. Exiting now.."
    divider
    exit 1
  fi

  echo -e "\n--------------------------------------------------------------------\n"
  sleep ${RETRY_INTERVAL}
done
