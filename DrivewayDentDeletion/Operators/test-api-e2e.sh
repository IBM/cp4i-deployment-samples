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
#   -r : <RELEASE> (string), defaults to "ademo"
#   -p : <NAMESPACE_SUFFIX> (string), defaults to ""
#   -s : <USER_DB_SUFFIX> (string), defaults to ""
#   -a : <APIC_ENABLED>
#
#   With default values
#     ./test-api-e2e.sh

function usage {
    echo "Usage: $0 -n <NAMESPACE> -r <RELEASE> -p <NAMESPACE_SUFFIX> -s <USER_DB_SUFFIX> -a"
    exit 1
}

CURRENT_DIR=$(dirname $0)
TICK="\xE2\x9C\x85"
CROSS="\xE2\x9D\x8C"
NAMESPACE="cp4i"
RELEASE="ademo"
APIC=false
APP="ddd-app"
os_sed_flag=""
ORG="main-demo"

if [[ $(uname) == Darwin ]]; then
  os_sed_flag="-e"
fi

while getopts "n:r:p:s:a" opt; do
  case ${opt} in
    n ) NAMESPACE="$OPTARG"
      ;;
    r ) RELEASE="$OPTARG"
      ;;
    p ) NAMESPACE_SUFFIX="$OPTARG"
      ;;
    s ) USER_DB_SUFFIX="$OPTARG"
      ;;
    a ) APIC=true
      ;;
    \? ) usage; exit
      ;;
  esac
done

# -------------------------------------- CHECK SUFFIX FOR NAMESPACE, USER AND DATABASE NAME ---------------------------------------------------------------------

echo "Namespace passed: $NAMESPACE"
echo "User name suffix: $USER_DB_SUFFIX"

MAIN_NAMESPACE=${NAMESPACE}
if $APIC; then
  PLATFORM_API_EP=$(oc get route -n $MAIN_NAMESPACE ${RELEASE}-mgmt-platform-api -o jsonpath="{.spec.host}")
  [[ -z $PLATFORM_API_EP ]] && echo -e "[ERROR] ${CROSS} APIC platform api route doesn't exit" && exit 1
  $DEBUG && echo "[DEBUG] PLATFORM_API_EP=${PLATFORM_API_EP}"
fi
# check if the namespace is dev or test
if [[ "$NAMESPACE_SUFFIX" == "dev" ]]; then
  NAMESPACE="${NAMESPACE}"
else
  echo "Namespace suffix: $NAMESPACE_SUFFIX"
  NAMESPACE="${NAMESPACE}-${NAMESPACE_SUFFIX}"
  ORG="ddd-demo-test"
fi
CATALOG=${ORG}-catalog

echo "Namespace for postgres: $NAMESPACE"
echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"


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

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

# -------------------------------------- TEST E2E API ------------------------------------------
# BASE_PATH=/basepath, all ready contains /
HOST=https://$(oc get routes -n ${NAMESPACE} | grep ace-api-int-srv-https | awk '{print $2}')/drivewayrepair
if [[ $APIC == true ]]; then
  OUTPUT=""
  function handle_res {
    local body=$1
    local status=$(echo ${body} | $JQ -r ".status")
    $DEBUG && echo "[DEBUG] res body: ${body}"
    $DEBUG && echo "[DEBUG] res status: ${status}"
    if [[ $status == "null" ]]; then
      OUTPUT="${body}"
    elif [[ $status == "400" ]]; then
      if [[ $body == *"already exists"* ]]; then
        OUTPUT="${body}"
        echo "[INFO]  Resource already exists, continuing..."
      else
        echo -e "[ERROR] ${CROSS} Got 400 bad request"
        exit 1
      fi
    elif [[ $status == "409" ]]; then
      OUTPUT="${body}"
      echo "[INFO]  Resource already exists, continuing..."
    else
      echo -e "[ERROR] ${CROSS} Request failed: ${body}..."
      exit 1
    fi
  }

  # Grab bearer token
  echo "[INFO]  Getting bearer token..."
  TOKEN=$(${CURRENT_DIR}/../../products/bash/get-apic-token.sh -n $MAIN_NAMESPACE -r $RELEASE)
  $DEBUG && echo "[DEBUG] Bearer token: ${TOKEN}"
  echo -e "[INFO]  ${TICK} Got bearer token"

  # Get api endpoint
  BASE_PATH=$(grep 'basePath:' ${CURRENT_DIR}/../../products/bash/api.yaml | head -1 | awk '{print $2}')
  HOST="https://$(oc get route -n $MAIN_NAMESPACE ${RELEASE}-gw-gateway -o jsonpath='{.spec.host}')/$ORG/$CATALOG$BASE_PATH"

  # Get client id
  echo "[INFO]  Getting client id..."
  RES=$(curl -kLsS https://$PLATFORM_API_EP/api/catalogs/$ORG/$CATALOG/credentials \
    -H "accept: application/json" \
    -H "authorization: Bearer ${TOKEN}")
  handle_res "${RES}"
  CLIENT_ID=$(echo "${OUTPUT}" | $JQ -r '.results[] | select(.name | contains("'${APP}'")).client_id')
  $DEBUG && echo "[DEBUG] Client id: ${CLIENT_ID}"
  [[ $CLIENT_ID == "null" ]] && echo -e "[ERROR] ${CROSS} Couldn't get client id" && exit 1

  # Store api endpoint & client id in secret
  cat << EOF | oc apply -n ${NAMESPACE} -f -
apiVersion: v1
kind: Secret
metadata:
  name: ddd-api-endpoint-client-id
type: Opaque
stringData:
  api: ${HOST}
  cid: ${CLIENT_ID}
EOF
  echo -e "[INFO]  ${TICK} Got client id"
fi
echo "INFO: Host: ${HOST}"

DB_USER=$(echo ${NAMESPACE}_${USER_DB_SUFFIX} | sed 's/-/_/g')
DB_NAME="db_${DB_USER}"
DB_POD=$(oc get pod -n postgres -l name=postgresql -o jsonpath='{.items[].metadata.name}')
echo "INFO: Username name is: '${DB_USER}'"
echo "INFO: Database name is: '${DB_NAME}'"

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

echo -e "INFO: Testing E2E API now..."

API_AUTH=$(oc get secret -n $NAMESPACE ace-api-creds -o json | $JQ -r '.data.auth')
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

  echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------"

  # ------- Get from the database -------
  echo -e "\nINFO: GET request..."
  get_response=$(curl -ksw " %{http_code}" ${HOST}/quote?QuoteID=${quote_id} -H "authorization: Basic ${API_AUTH}" -H "X-IBM-Client-Id: ${CLIENT_ID}")
  get_response_code=$(echo "${get_response##* }")

  if [ "$get_response_code" == "200" ]; then
    echo -e "$TICK INFO: SUCCESS - GET with response code: ${get_response_code}, and Response Body:\n"
    # The usage of sed here is to prevent an error caused between the -w flag of curl and jq not interacting well
    echo ${get_response} | $JQ '.' | sed $os_sed_flag '$ d'

    echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------"

    #  ------- Get row to confirm post -------
    echo -e "\nINFO: Select and print the row as user '${DB_USER}' from database '${DB_NAME}' with id '$quote_id' to confirm POST and GET..."
    if ! oc exec -n postgres -it ${DB_POD} \
      -- psql -U ${DB_USER} -d ${DB_NAME} -c \
      "SELECT * FROM quotes WHERE quotes.quoteid=${quote_id};"; then
      echo -e "\n$CROSS ERROR: Cannot get row with quote id '$quote_id' to confirm POST and GET"
    else
      echo -e "\n$TICK INFO: Successfully got row to confirm POST and GET"
    fi

  else
    echo "$CROSS ERROR: FAILED - Error code: ${get_response_code}"
    echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"
    exit 1
  fi

  echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------"
  # ------- Delete from the database -------
  echo -e "\nINFO: Deleting row from database '${DB_NAME}' as user '${DB_USER}' with quote id '$quote_id'..."
  if ! oc exec -n postgres -it ${DB_POD} \
    -- psql -U ${DB_USER} -d ${DB_NAME} -c \
    "DELETE FROM quotes WHERE quotes.quoteid=${quote_id};"; then
    echo -e "\n$CROSS ERROR: Cannot delete the row with quote id '$quote_id'"
  else
    echo -e "\n$TICK INFO: Successfully deleted the row with quote id '$quote_id'"
  fi

  echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------"

  #  ------- Get row output and check for '0 rows' in output to confirm deletion -------
  echo -e "\nINFO: Confirming the deletion of the row with the quote id '$quote_id' from database '${DB_NAME}' as the user '${DB_USER}'..."
  oc exec -n postgres -it ${DB_POD} \
    -- psql -U ${DB_USER} -d ${DB_NAME} -c \
    "SELECT * FROM quotes WHERE quotes.quoteid=${quote_id};" \
    | grep '0 rows'

  if [ $? -eq 0 ]; then
    echo -e "\n$TICK INFO: Successfully confirmed deletion of row with quote id '$quote_id'"
  else
    echo -e "\n$CROSS ERROR: Deletion of the row with quote id '$quote_id' failed"
  fi

else
  # Failure catch during POST
  echo "$CROSS ERROR: Post request failed - Error code: ${post_response_code}"
  exit 1
fi
echo -e "----------------------------------------------------------------------------------------------------------------------------------------------------------"
