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
#   -n : <NAMESPACE> (string), defaults to "cp4i"
#   -s : <USER_DB_SUFFIX> (string), defaults to ""
#   -a : <APIC_ENABLED> (boolean) (optional), Defaults to false
#   -p : <POSTGRES_NAMESPACE> (string), Namespace where postgres is setup, Defaults to the value of <NAMESPACE>
#   -d : <DDD_TYPE> (string), Driveway dent deletion demo type for postgres credential, Defaults to "dev"
#
#   With default values
#     ./test-api-e2e.sh

function divider() {
  echo -e "\n-------------------------------------------------------------------------------------------------------------------\n"
}

function usage() {
  echo "Usage: $0 -n <NAMESPACE> -s <USER_DB_SUFFIX> -p <POSTGRES_NAMESPACE> -d <DDD_TYPE> -a"
  divider
  exit 1
}

CURRENT_DIR=$(dirname $0)
TICK="\xE2\x9C\x85"
CROSS="\xE2\x9D\x8C"
NAMESPACE="cp4i"
APIC=false
os_sed_flag=""
POSTGRES_NAMESPACE=$NAMESPACE
DDD_TYPE="dev"

if [[ $(uname) == Darwin ]]; then
  os_sed_flag="-e"
fi

while getopts "n:p:s:ad:" opt; do
  case ${opt} in
  n)
    NAMESPACE="$OPTARG"
    ;;
  s)
    USER_DB_SUFFIX="$OPTARG"
    ;;
  p)
    POSTGRES_NAMESPACE="$OPTARG"
    ;;
  a)
    APIC=true
    ;;
  d)
    DDD_TYPE="$OPTARG"
    ;;
  \?)
    usage
    exit
    ;;
  esac
done

echo "Namespace passed: $NAMESPACE"
echo "User name suffix: $USER_DB_SUFFIX"
echo "Postgres namespace passed: $POSTGRES_NAMESPACE"
echo "Driveway dent deletion demo type: '$DDD_TYPE'"
divider

# -------------------------------------- INSTALL JQ ---------------------------------------------------------------------

echo -e "\nINFO: Checking if jq is pre-installed..."
jqInstalled=false
jqVersionCheck=$(jq --version)

if [ $? -ne 0 ]; then
  jqInstalled=false
else
  jqInstalled=true
fi

JQ=jq
if [[ "$jqInstalled" == "false" ]]; then
  echo "INFO: JQ is not installed, installing jq..."
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "INFO: Installing on linux"
    wget -O jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64
    chmod +x ./jq
    JQ=./jq
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    echo "INFO: Installing on MAC"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
    brew install jq
  fi
fi

echo -e "\n$TICK INFO: Installed JQ version is $($JQ --version)"

divider

# -------------------------------------- TEST E2E API ------------------------------------------
# BASE_PATH=/basepath, all ready contains /
HOST=https://$(oc get routes -n ${NAMESPACE} | grep ddd-${DDD_TYPE}-ace-api-https | awk '{print $2}')/drivewayrepair
if [[ $APIC == true ]]; then
  # Grab bearer token
  echo "[INFO]  Getting the host and client id..."
  ENDPOINT_SECRET_NAME="ddd-${DDD_TYPE}-api-endpoint-client-id"
  HOST=$(oc get secret -n ${NAMESPACE} ${ENDPOINT_SECRET_NAME} -o jsonpath='{.data.api}' | base64 --decode)
  CLIENT_ID=$(oc get secret -n ${NAMESPACE} ${ENDPOINT_SECRET_NAME} -o jsonpath='{.data.cid}' | base64 --decode)
  $DEBUG && echo "[DEBUG] Client id: ${CLIENT_ID}"
  [[ $CLIENT_ID == "null" ]] && echo -e "[ERROR] ${CROSS} Couldn't get client id" && exit 1
fi

echo "INFO: Host: ${HOST}"

DB_USER=$(echo ${NAMESPACE}_${DDD_TYPE}_${USER_DB_SUFFIX} | sed 's/-/_/g')
DB_NAME="db_${DB_USER}"
DB_POD=$(oc get pod -n $POSTGRES_NAMESPACE -l name=postgresql -o jsonpath='{.items[].metadata.name}')
echo "INFO: Username name is: '${DB_USER}'"
echo "INFO: Database name is: '${DB_NAME}'"

divider

echo -e "INFO: Testing E2E API now..."

API_AUTH=$(oc get secret -n $NAMESPACE ace-api-creds-ddd -o json | $JQ -r '.data.auth')
echo "api auth: $API_AUTH"

# ------- Post to the database -------
echo "request url: $HOST/quote"
post_response=$(curl -ksw " %{http_code}" -X POST $HOST/quote \
  -H "authorization: Basic ${API_AUTH}" \
  -H "X-IBM-Client-Id: ${CLIENT_ID}" \
  -H "content-type: application/json" \
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
  }
")
echo "[DEBUG] post response: ${post_response}"
post_response_code=$(echo "${post_response##* }")

if [ "$post_response_code" == "200" ]; then
  # The usage of sed here is to prevent an error caused between the -w flag of curl and jq not interacting well
  quote_id=$(echo "$post_response" | $JQ '.' | sed $os_sed_flag '$ d' | $JQ '.QuoteID')

  echo -e "$TICK INFO: SUCCESS - POST with response code: ${post_response_code}, QuoteID: ${quote_id}, and Response Body:\n"
  # The usage of sed here is to prevent an error caused between the -w flag of curl and jq not interacting well
  echo ${post_response} | $JQ '.' | sed $os_sed_flag '$ d'

  divider

  # ------- Get from the database -------
  echo -e "\nINFO: GET request..."
  get_response=$(curl -ksw " %{http_code}" ${HOST}/quote?QuoteID=${quote_id} -H "authorization: Basic ${API_AUTH}" -H "X-IBM-Client-Id: ${CLIENT_ID}")
  get_response_code=$(echo "${get_response##* }")

  if [ "$get_response_code" == "200" ]; then
    echo -e "$TICK INFO: SUCCESS - GET with response code: ${get_response_code}, and Response Body:\n"
    # The usage of sed here is to prevent an error caused between the -w flag of curl and jq not interacting well
    echo ${get_response} | $JQ '.' | sed $os_sed_flag '$ d'

    divider

    #  ------- Get row to confirm post -------
    echo -e "\nINFO: Select and print the row as user '${DB_USER}' from database '${DB_NAME}' with id '$quote_id' to confirm POST and GET..."
    if ! oc exec -n $POSTGRES_NAMESPACE -it ${DB_POD} \
      -- psql -U ${DB_USER} -d ${DB_NAME} -c \
      "SELECT * FROM quotes WHERE quotes.quoteid=${quote_id};"; then
      echo -e "\n$CROSS ERROR: Cannot get row with quote id '$quote_id' to confirm POST and GET"
      divider
      exit 1
    else
      echo -e "\n$TICK INFO: Successfully got row to confirm POST and GET"
    fi

  else
    echo "$CROSS ERROR: FAILED - Error code: ${get_response_code}"
    divider
    exit 1
  fi

  divider
  # ------- Delete from the database -------
  echo -e "\nINFO: Deleting row from database '${DB_NAME}' as user '${DB_USER}' with quote id '$quote_id'..."
  if ! oc exec -n $POSTGRES_NAMESPACE -it ${DB_POD} \
    -- psql -U ${DB_USER} -d ${DB_NAME} -c \
    "DELETE FROM quotes WHERE quotes.quoteid=${quote_id};"; then
    echo -e "\n$CROSS ERROR: Cannot delete the row with quote id '$quote_id'"
    divider
    exit 1
  else
    echo -e "\n$TICK INFO: Successfully deleted the row with quote id '$quote_id'"
  fi

  divider

  #  ------- Get row output and check for '0 rows' in output to confirm deletion -------
  echo -e "\nINFO: Confirming the deletion of the row with the quote id '$quote_id' from database '${DB_NAME}' as the user '${DB_USER}'..."
  oc exec -n $POSTGRES_NAMESPACE -it ${DB_POD} \
    -- psql -U ${DB_USER} -d ${DB_NAME} -c \
    "SELECT * FROM quotes WHERE quotes.quoteid=${quote_id};" |
    grep '0 rows'

  if [ $? -eq 0 ]; then
    echo -e "\n$TICK INFO: Successfully confirmed deletion of row with quote id '$quote_id'"
  else
    echo -e "\n$CROSS ERROR: Deletion of the row with quote id '$quote_id' failed"
    divider
    exit 1
  fi

else
  # Failure catch during POST
  echo "$CROSS ERROR: Post request failed - Error code: ${post_response_code}"
  divider
  exit 1
fi
divider
