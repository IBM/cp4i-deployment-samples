#!/bin/bash
#******************************************************************************
# Licensed Materials - Property of IBM
# (c) Copyright IBM Corporation 2020. All Rights Reserved.
#
# Note to U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.
#******************************************************************************

DEBUG=true
NAMESPACE="cp4i"
RELEASE="ademo"
PROVIDER_ORG="main-demo"
CATALOG="main-demo-catalog"
CONSUMER_ORG=""
PRODUCT=""
APP=""
ENDPOINT_SECRET_NAME=""
BASE_PATH=""

function usage() {
  echo "Usage: $0 -n <namespace> -r <APIC CR name> -o <provider org> -c <catalog> -u <consumer org> -p <product> -a <app> -e <endpoint secret name> -b <base path>"
}

while getopts "a:b:c:e:n:o:p:r:u:" opt; do
  case ${opt} in
  a)
    APP="$OPTARG"
    ;;
  b)
    BASE_PATH="$OPTARG"
    ;;
  c)
    CATALOG="$OPTARG"
    ;;
  e)
    ENDPOINT_SECRET_NAME="$OPTARG"
    ;;
  n)
    NAMESPACE="$OPTARG"
    ;;
  o)
    PROVIDER_ORG="$OPTARG"
    ;;
  p)
    PRODUCT="$OPTARG"
    ;;
  r)
    RELEASE="$OPTARG"
    ;;
  u)
    CONSUMER_ORG="$OPTARG"
    ;;
  \?)
    usage
    exit
    ;;
  esac
done

if [ -z "${PRODUCT}" ]; then echo "PRODUCT must be specified using -p" ; exit 1 ; fi

# If CONSUMER_ORG not set then default based on PROVIDER_ORG
if [ -z "${CONSUMER_ORG}" ]; then CONSUMER_ORG=${PROVIDER_ORG}-corp; fi

# If APP not set then default based on PRODUCT
if [ -z "${APP}" ]; then APP=${PRODUCT}-app; fi

TICK="\xE2\x9C\x85"
CROSS="\xE2\x9D\x8C"

client_id="599b7aef-8841-4ee2-88a0-84d49c4d6ff2"
client_secret="0ea28423-e73b-47d4-b40e-ddb45c48bb0c"
realm=provider/default-idp-2
username=cp4i-admin
password=engageibmAPI1
APP_TITLE=${APP}
CORG_OWNER_USERNAME="${PROVIDER_ORG}-corg-admin"
CORG_OWNER_PASSWORD=engageibmAPI1

PLATFORM_API_EP=$(oc get route -n $NAMESPACE ${RELEASE}-mgmt-platform-api -o jsonpath="{.spec.host}")
[[ -z $PLATFORM_API_EP ]] && echo -e "[ERROR] ${CROSS} APIC platform api route doesn't exit" && exit 1
$DEBUG && echo "[DEBUG] PLATFORM_API_EP=${PLATFORM_API_EP}"

JQ=jq

OUTPUT=""
function handle_res() {
  local body=$1
  local status=$(echo ${body} | $JQ -r ".status")
  $DEBUG && echo "[DEBUG] res body: ${body}"
  $DEBUG && echo "[DEBUG] res status: ${status}"
  if [[ $status == "null" ]]; then
    OUTPUT="${body}"
  elif [[ $status == "400" ]]; then
    if [[ $body == *"already exists"* || $body == *"already subscribed"* ]]; then
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

response=`curl -X POST https://$PLATFORM_API_EP/api/token \
               -s -k -H "Content-Type: application/json" -H "Accept: application/json" \
               -d "{ \"realm\": \"${realm}\",
                     \"username\": \"${username}\",
                     \"password\": \"${password}\",
                     \"client_id\": \"${client_id}\",
                     \"client_secret\": \"${client_secret}\",
                     \"grant_type\": \"password\" }"`
if [[ "$(echo ${response} | jq -r '.status')" == "401" ]]; then
    echo "[ERROR] Failed to authenticate"
    exit 1
else
    TOKEN=`echo ${response} | jq -r '.access_token'`
fi

# Get user registry url
echo "[INFO] Getting configured catalog user registry url for ${PROVIDER_ORG}-catalog..."
RES=$(curl -kLsS https://$PLATFORM_API_EP/api/catalogs/${PROVIDER_ORG}/$CATALOG/configured-catalog-user-registries \
  -H "accept: application/json" \
  -H "authorization: Bearer ${TOKEN}")
handle_res "${RES}"

USER_REGISTRY_URL=$(echo "${OUTPUT}" | $JQ -r ".results[0].user_registry_url")
$DEBUG && echo "[DEBUG] User registry url: ${USER_REGISTRY_URL}"
echo -e "[INFO] ${TICK} Got configured catalog user registry url for ${PROVIDER_ORG}-catalog"

$DEBUG && echo "[DEBUG] username: $CORG_OWNER_USERNAME"
$DEBUG && echo "[DEBUG] password: ${CORG_OWNER_PASSWORD}"
# Create consumer org owner
echo "[INFO] Creating consumer org owner..."
RES=$(curl -kLsS -X POST $USER_REGISTRY_URL/users \
  -H "accept: application/json" \
  -H "authorization: Bearer ${TOKEN}" \
  -H "content-type: application/json" \
  -d "{
    \"username\": \"${CORG_OWNER_USERNAME}\",
    \"email\": \"nigel@acme.org\",
    \"first_name\": \"Nigel\",
    \"last_name\": \"McNigelface\",
    \"password\": \"${CORG_OWNER_PASSWORD}\"
}")
handle_res "${RES}"
OWNER_URL=$(echo "${OUTPUT}" | $JQ -r ".url")
$DEBUG && echo "[DEBUG] Owner url: ${OWNER_URL}"
if [[ $OWNER_URL == "null" ]]; then
  # Get existing owner
  echo "[INFO] Getting existing consumer org owner..."
  # user registry naming convention: {catalog-name}-catalog
  RES=$(curl -kLsS https://$PLATFORM_API_EP/api/user-registries/${PROVIDER_ORG}/${CATALOG}-catalog/users \
    -H "accept: application/json" \
    -H "authorization: Bearer ${TOKEN}")
  handle_res "${RES}"
  OWNER_URL=$(echo "${OUTPUT}" | $JQ -r '.results[] | select(.username == "'${CORG_OWNER_USERNAME}'").url')
  $DEBUG && echo "[DEBUG] Owner url: ${OWNER_URL}"
  echo -e "[INFO] ${TICK} Got owner url"
else
  echo -e "[INFO] ${TICK} Consumer org owner created"
fi

# Create consumer org
echo "[INFO] Creating consumer org..."
RES=$(curl -kLsS -X POST https://$PLATFORM_API_EP/api/catalogs/${PROVIDER_ORG}/$CATALOG/consumer-orgs \
  -H "accept: application/json" \
  -H "authorization: Bearer ${TOKEN}" \
  -H "content-type: application/json" \
  -d "{
    \"title\": \"${CONSUMER_ORG}\",
    \"name\": \"${CONSUMER_ORG}\",
    \"owner_url\": \"${OWNER_URL}\"
}")
handle_res "${RES}"
echo -e "[INFO] ${TICK} Consumer org created"

# Create an app
echo "[INFO] Creating application..."
RES=$(curl -kLsS -X POST https://$PLATFORM_API_EP/api/consumer-orgs/${PROVIDER_ORG}/$CATALOG/$CONSUMER_ORG/apps \
  -H "accept: application/json" \
  -H "authorization: Bearer ${TOKEN}" \
  -H "content-type: application/json" \
  -d "{
    \"title\": \"${APP_TITLE}\",
    \"name\": \"${APP}\"
}")
handle_res "${RES}"
echo -e "[INFO] ${TICK} Application created"

if [[ $ENDPOINT_SECRET_NAME != "" ]]; then
    CLIENT_ID=$(echo "${OUTPUT}" | $JQ -r ".client_id")
    CLIENT_SECRET=$(echo "${OUTPUT}" | $JQ -r ".client_secret")
    if [[ $CLIENT_SECRET != "null" ]]; then
      echo "[INFO]  Creating secret ${ENDPOINT_SECRET_NAME}"
      $DEBUG && echo "[DEBUG] BASE_PATH: ${BASE_PATH}"
      HOST="https://$(oc get route -n $NAMESPACE ${RELEASE}-gw-gateway -o jsonpath='{.spec.host}')/$PROVIDER_ORG/$CATALOG$BASE_PATH"
      $DEBUG && echo "[DEBUG] HOST: ${HOST}"

      # Store api endpoint & client id/secret in secret
      cat <<EOF | oc apply -n ${NAMESPACE} -f -
apiVersion: v1
kind: Secret
metadata:
  name: ${ENDPOINT_SECRET_NAME}
type: Opaque
stringData:
  api: ${HOST}
  cid: ${CLIENT_ID}
  csecret: ${CLIENT_SECRET}
EOF
      echo -e "[INFO]  ${TICK} Secret created"
  fi
fi

exit 1


# Get product url
echo "[INFO] Getting url for product $PRODUCT..."
RES=$(curl -kLsS https://$PLATFORM_API_EP/api/catalogs/${PROVIDER_ORG}/$CATALOG/products/$PRODUCT \
  -H "accept: application/json" \
  -H "authorization: Bearer ${TOKEN}")
handle_res "${RES}"
PRODUCT_URL=$(echo "${OUTPUT}" | $JQ -r ".results[0].url")
$DEBUG && echo "[DEBUG] Product url: ${PRODUCT_URL}"
echo -e "[INFO] ${TICK} Got product url"

# Create a subscription
echo "[INFO] Creating subscription..."
RES=$(curl -kLsS -X POST https://$PLATFORM_API_EP/api/apps/${PROVIDER_ORG}/$CATALOG/$CONSUMER_ORG/$APP/subscriptions \
  -H "accept: application/json" \
  -H "authorization: Bearer ${TOKEN}" \
  -H "content-type: application/json" \
  -d "{
    \"product_url\": \"${PRODUCT_URL}\",
    \"plan\": \"default-plan\"
}")
handle_res "${RES}"
echo -e "[INFO] ${TICK} Subscription created"
