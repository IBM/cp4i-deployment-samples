#!/bin/bash
#******************************************************************************
# Licensed Materials - Property of IBM
# (c) Copyright IBM Corporation 2020. All Rights Reserved.
#
# Note to U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.
#******************************************************************************

#******************************************************************************
# PLEASE NOTE: The configure-apic-v10.sh is for Demos only and not recommended for use anywhere else.
# The script uses unsupported internal features that are NOT suitable for production usecases.
#
# PREREQUISITES:
#   - Logged into cluster on the OC CLI (https://docs.openshift.com/container-platform/4.4/cli_reference/openshift_cli/getting-started-cli.html)
#
# PARAMETERS:
#   -n : <NAMESPACE> (string), Defaults to "cp4i"
#   -r : <RELEASE_NAME> (string), Defaults to "ademo"
#   -a : <ha_enabled>, default to "true"
#
# USAGE:
#   With default values
#     ./configure-apic-v10.sh
#
#   Overriding the NAMESPACE and release-name
#     ./configure-apic-v10 -n cp4i-prod -r prod

CURRENT_DIR=$(dirname $0)
source $CURRENT_DIR/../../products/bash/utils.sh

ha_enabled="false"
NAMESPACE="cp4i"
RELEASE_NAME="ademo"
ORG_NAME="main-demo"
ORG_NAME_DDD="ddd-demo-test"
DEBUG=true

function usage() {
  echo "Usage: $0 -n <NAMESPACE> -r <RELEASE_NAME>"
}

while getopts "a:n:r:" opt; do
  case ${opt} in
  a)
    ha_enabled="$OPTARG"
    ;;
  n)
    NAMESPACE="$OPTARG"
    ;;
  r)
    RELEASE_NAME="$OPTARG"
    ;;
  \?)
    usage
    exit
    ;;
  esac
done

set -e

NAMESPACE="${NAMESPACE}"
PORG_ADMIN_EMAIL=${PORG_ADMIN_EMAIL:-"cp4i-admin@apiconnect.net"} # update to recipient of portal site creation email
ACE_REGISTRATION_SECRET_NAME="ace-v11-service-creds"              # corresponds to registration obj currently hard-coded in configmap
PROVIDER_SECRET_NAME="cp4i-admin-creds"                           # corresponds to credentials obj currently hard-coded in configmap

if [[ $(oc get secret cp4i-demo-apic-smtp-secret -n "$NAMESPACE" 2>/dev/null) ]]; then
  MAIL_SERVER_HOST=$(oc get secret cp4i-demo-apic-smtp-secret -n "$NAMESPACE" -o json | jq -r '.data.mailServerHost' | base64 --decode)
  MAIL_SERVER_PORT=$(oc get secret cp4i-demo-apic-smtp-secret -n "$NAMESPACE" -o json | jq -r '.data.mailServerPort' | base64 --decode)
  MAIL_SERVER_USERNAME=$(oc get secret cp4i-demo-apic-smtp-secret -n "$NAMESPACE" -o json | jq -r '.data.mailServerUsername' | base64 --decode)
  MAIL_SERVER_PASSWORD=$(oc get secret cp4i-demo-apic-smtp-secret -n "$NAMESPACE" -o json | jq -r '.data.mailServerPassword' | base64 --decode)
  PORG_ADMIN_EMAIL=$(oc get secret cp4i-demo-apic-smtp-secret -n "$NAMESPACE" -o json | jq -r '.data.emailAddress' | base64 --decode)
else
  echo -e "\nThe secret 'cp4i-demo-apic-smtp-secret' does not exist in the namespace '$NAMESPACE', continuing configuring APIC with default SMTP values..."
  echo -e "\nGoing to use the values defined in 1-click which are also the default values"
  MAIL_SERVER_HOST=${demoAPICMailServerHost}
  MAIL_SERVER_PORT=${demoAPICMailServerPort}
  MAIL_SERVER_USERNAME=${demoAPICMailServerUsername}
  MAIL_SERVER_PASSWORD=${demoAPICMailServerPassword}
  PORG_ADMIN_EMAIL=${demoAPICEmailAddress}
fi


echo "Waiting for APIC installation to complete..."
for i in $(seq 1 120); do
  APIC_STATUS=$(oc get apiconnectcluster.apiconnect.ibm.com -n $NAMESPACE ${RELEASE_NAME} -o jsonpath='{.status.phase}')
  if [ "$APIC_STATUS" == "Ready" ]; then
    printf "$TICK"
    echo "[OK] APIC is ready"
    break
  else
    echo "Waiting for APIC install to complete (Attempt $i of 120). Status: $APIC_STATUS"
    if [ $i -gt 50 ]; then
      oc get apiconnectcluster,managementcluster,portalcluster,gatewaycluster,pvc,pod -n $NAMESPACE
    fi
    sleep 60
  fi
done

if [ "$APIC_STATUS" != "Ready" ]; then
  printf "$CROSS"
  echo "[ERROR] APIC failed to install"
  exit 1
fi

for i in $(seq 1 60); do
  PORTAL_WWW_POD=$(oc get pods -n $NAMESPACE | grep -m1 "${RELEASE_NAME:0:10}-.*-www" | awk '{print $1}')
  if [ -z "$PORTAL_WWW_POD" ]; then
    echo "Not got portal pod yet"
  else
    PORTAL_WWW_ADMIN_READY=$(oc get pod -n ${NAMESPACE} ${PORTAL_WWW_POD} -o json | jq '.status.containerStatuses[0].ready')
    if [[ "$PORTAL_WWW_ADMIN_READY" == "true" ]]; then
      printf "$TICK"
      echo "PORTAL_WWW_POD (${PORTAL_WWW_POD}) is ready"
      break
    else
      echo "${PORTAL_WWW_POD} not ready"
    fi
  fi

  echo "Waiting, checking again in one minute... (Attempt $i of 60)"
  sleep 60
done

echo "Pod listing for information"
oc get pod -n $NAMESPACE

# obtain different APIC v10 routes names
APIM_UI_RESOURCE_NAME=$(oc get routes -n $NAMESPACE | grep -m1 "${RELEASE_NAME:0:10}.*api-manager" | awk '{print $1}')
CMC_UI_RESOURCE_NAME=$(oc get routes -n $NAMESPACE | grep -m1 "${RELEASE_NAME:0:10}.*admin" | awk '{print $1}')
C_API_RESOURCE_NAME=$(oc get routes -n $NAMESPACE | grep -m1 "${RELEASE_NAME:0:10}.*consumer-api" | awk '{print $1}')
API_RESOURCE_NAME=$(oc get routes -n $NAMESPACE | grep -m1 "${RELEASE_NAME:0:10}.*platform-api" | awk '{print $1}')
PLT_WEB_RESOURCE_NAME=$(oc get routes -n $NAMESPACE | grep -m1 "${RELEASE_NAME:0:10}.*portal-web" | awk '{print $1}')

# obtain endpoint info from APIC v10 routes
APIM_UI_EP=$(oc get route -n $NAMESPACE ${APIM_UI_RESOURCE_NAME} -o jsonpath='{.spec.host}')
CMC_UI_EP=$(oc get route -n $NAMESPACE ${CMC_UI_RESOURCE_NAME} -o jsonpath='{.spec.host}')
C_API_EP=$(oc get route -n $NAMESPACE ${C_API_RESOURCE_NAME} -o jsonpath='{.spec.host}')
API_EP=$(oc get route -n $NAMESPACE ${API_RESOURCE_NAME} -o jsonpath='{.spec.host}')
PTL_WEB_EP=$(oc get route -n $NAMESPACE ${PLT_WEB_RESOURCE_NAME} -o jsonpath='{.spec.host}')

admin_idp=admin/default-idp-1
admin_password=$(oc get secret -n $NAMESPACE ${RELEASE_NAME}-mgmt-admin-pass -o json | jq -r .data.password | base64 --decode)

provider_user_registry=api-manager-lur
provider_idp=provider/default-idp-2
provider_username=cp4i-admin
provider_email=${PORG_ADMIN_EMAIL:-"cp4i-admin@apiconnect.net"} # update to recipient of portal site creation email
provider_password=engageibmAPI1
provider_firstname=CP4I
provider_lastname=Administrator

MAIN_PORG_TITLE="${ORG_NAME} : For Demo use"
MAIN_CATALOG="${ORG_NAME}-catalog"
MAIN_CATALOG_TITLE="${MAIN_CATALOG}: For Demo use"

TEST_PORG_TITLE="${ORG_NAME_DDD} : For Demo use"
TEST_CATALOG="${ORG_NAME_DDD}-catalog"
TEST_CATALOG_TITLE="${TEST_CATALOG} : For Demo use"

RESULT=""
function authenticate() {
  realm=${1}
  username=${2}
  password=${3}

  echo "Authenticate as the ${username} user"
  response=`curl -X POST https://${API_EP}/api/token \
                 -s -k -H "Content-Type: application/json" -H "Accept: application/json" \
                 -d "{ \"realm\": \"${realm}\",
                       \"username\": \"${username}\",
                       \"password\": \"${password}\",
                       \"client_id\": \"599b7aef-8841-4ee2-88a0-84d49c4d6ff2\",
                       \"client_secret\": \"0ea28423-e73b-47d4-b40e-ddb45c48bb0c\",
                       \"grant_type\": \"password\" }"`
  $DEBUG && echo "[DEBUG] $(echo ${response} | jq .)"
  if [[ "$(echo ${response} | jq -r '.status')" == "401" ]]; then
    printf "$CROSS"
    echo "[ERROR] Failed to authenticate"
    exit 1
  fi
  RESULT=`echo ${response} | jq -r '.access_token'`
  return 0
}

function create_org() {
  token=${1}
  org_name=${2}
  org_title=${3}
  owner_url=${4}

  echo "Checking if the provider org named ${org_name} already exists"
  response=`curl GET https://${API_EP}/api/orgs/${org_name} \
                 -s -k -H "Content-Type: application/json" -H "Accept: application/json" \
                 -H "Authorization: Bearer ${token}"`
  $DEBUG && echo "[DEBUG] $(echo ${response} | jq .)"
  main_porg_url=`echo ${response} | jq -r '.url'`

  if [[ "${main_porg_url}" == "null" ]]; then
    echo "Create the ${org_name} Provider Organization"
    response=`curl https://${API_EP}/api/cloud/orgs \
                   -s -k -H "Content-Type: application/json" -H "Accept: application/json" \
                   -H "Authorization: Bearer ${token}" \
                   -d "{ \"name\": \"${org_name}\",
                         \"title\": \"${org_title}\",
                         \"org_type\": \"provider\",
                         \"owner_url\": \"${owner_url}\" }"`
    $DEBUG && echo "[DEBUG] $(echo ${response} | jq .)"
    main_porg_url=`echo ${response} | jq -r '.url'`
  fi
  RESULT="$main_porg_url"
  return 0
}

function add_cs_admin_user() {
  token=${1}
  org_name=${2}
  porg_url=${3}

  echo "Get the Provider Organization Roles for ${org_name}"
  response=`curl -X GET ${porg_url}/roles \
                 -s -k -H "Accept: application/json" \
                 -H "Authorization: Bearer ${token}"`
  $DEBUG && echo "[DEBUG] $(echo ${response} | jq .)"
  administrator_role_url=$(echo ${response} | jq -r '.results[]|select(.name=="administrator")|.url')
  $DEBUG && echo "administrator_role_url=${administrator_role_url}"

  echo "Add the CS admin user to the list of members for ${org_name}"
  member_json='{
    "name": "cs-admin",
    "user": {
      "identity_provider": "integration-keycloak",
      "url": "https://'${API_EP}'/api/user-registries/admin/integration-keycloak/users/integration-admin"
    },
    "role_urls": [
      "'${administrator_role_url}'"
    ]
  }'
  response=`curl -X POST ${porg_url}/members \
                 -s -k -H "Content-Type: application/json" -H "Accept: application/json" \
                 -H "Authorization: Bearer ${token}" \
                 -d ''$(echo $member_json | jq -c .)''`
  $DEBUG && echo "[DEBUG] $(echo ${response} | jq .)"
  return 0
}

function add_catalog() {
  token=${1}
  org_name=${2}
  porg_url=${3}
  catalog_name=${4}
  catalog_title=${5}

  echo "Checking if the catalog named ${catalog_name} already exists"
  response=`curl -X GET https://${API_EP}/api/catalogs/${org_name}/${catalog_name} \
                 -s -k -H "Content-Type: application/json" -H "Accept: application/json" \
                 -H "Authorization: Bearer ${token}"`
  $DEBUG && echo "[DEBUG] $(echo ${response} | jq .)"
  catalog_url=`echo ${response} | jq -r '.url'`
  if [[ "${catalog_url}" == "null" ]]; then
    echo "Create the Catalog"
    response=`curl -X POST ${porg_url}/catalogs \
                   -s -k -H "Content-Type: application/json" -H "Accept: application/json" \
                   -H "Authorization: Bearer ${token}" \
                   -d "{ \"name\": \"${catalog_name}\",
                         \"title\": \"${catalog_title}\" }"`
    $DEBUG && echo "[DEBUG] $(echo ${response} | jq .)"
    catalog_url=`echo ${response} | jq -r '.url'`
  fi

  echo "Add a portal to the catalog named ${catalog_name}"
  response=`curl -X PUT ${catalog_url}/settings \
                 -s -k -H "Content-Type: application/json" -H "Accept: application/json" \
                 -H "Authorization: Bearer ${token}" \
                 -d "{
                       \"portal\": {
                         \"type\": \"drupal\",
                         \"endpoint\": \"https://${PTL_WEB_EP}/${org_name}/${catalog_name}\",
                         \"portal_service_url\": \"https://${API_EP}/api/orgs/${org_name}/portal-services/portal-service\"
                       }
                     }"`
  $DEBUG && echo "[DEBUG] $(echo ${response} | jq .)"
  return 0
}

authenticate "${admin_idp}" "admin" "${admin_password}"
admin_token="${RESULT}"

echo "Get the Admin Organization User Registries"
response=`curl -X GET https://${API_EP}/api/orgs/admin/user-registries \
               -s -k -H "Accept: application/json" \
               -H "Authorization: Bearer ${admin_token}"`
$DEBUG && echo "[DEBUG] $(echo ${response} | jq .)"
api_manager_lur_url=$(echo ${response} | jq -r '.results[]|select(.name=="api-manager-lur")|.url')
$DEBUG && echo "api_manager_lur_url=${api_manager_lur_url}"

echo "Get the Cloud Scope User Registries Setting"
response=`curl -X GET https://${API_EP}/api/cloud/settings/user-registries \
               -s -k -H "Accept: application/json" \
               -H "Authorization: Bearer ${admin_token}"`
$DEBUG && echo "[DEBUG] $(echo ${response} | jq .)"

echo "Add the api-manager-lur to the list of providers"
new_registry_settings=$(echo ${response} | jq -c ".provider_user_registry_urls += [\"${api_manager_lur_url}\"]")
response=`curl -X PUT https://${API_EP}/api/cloud/settings/user-registries \
               -s -k -H "Content-Type: application/json" -H "Accept: application/json" \
               -H "Authorization: Bearer ${admin_token}" \
               -d ''${new_registry_settings}''`
$DEBUG && echo "[DEBUG] $(echo ${response} | jq .)"

echo "Checking if the user named ${provider_username} already exists"
response=`curl GET https://${API_EP}/api/user-registries/admin/${provider_user_registry}/users/${provider_username} \
               -s -k -H "Content-Type: application/json" -H "Accept: application/json" \
               -H "Authorization: Bearer ${admin_token}"`
$DEBUG && echo "[DEBUG] $(echo ${response} | jq .)"
owner_url=`echo ${response} | jq -r '.url'`
if [[ "${owner_url}" == "null" ]]; then
  echo "Create the user named ${provider_username}"
  response=`curl https://${API_EP}/api/user-registries/admin/${provider_user_registry}/users \
                 -s -k -H "Content-Type: application/json" -H "Accept: application/json" \
                 -H "Authorization: Bearer ${admin_token}" \
                 -d "{ \"username\": \"${provider_username}\",
                       \"password\": \"${provider_password}\",
                       \"email\": \"${provider_email}\",
                       \"first_name\": \"${provider_firstname}\",
                       \"last_name\": \"${provider_lastname}\" }"`
  $DEBUG && echo "[DEBUG] $(echo ${response} | jq .)"
  owner_url=`echo ${response} | jq -r '.url'`
fi
$DEBUG && echo "owner_url=${owner_url}"

echo "Create ${PROVIDER_SECRET_NAME} secret with credentials for the user named ${provider_username}"
YAML=$(oc create secret generic -n ${NAMESPACE} ${PROVIDER_SECRET_NAME} \
  --from-literal=username=${provider_username} \
  --from-literal=password=${provider_password} \
  --dry-run=client -o yaml)
OCApplyYAML "$NAMESPACE" "$YAML"

authenticate "${provider_idp}" "${provider_username}" "${provider_password}"
provider_token="${RESULT}"

# Main org/catalog
create_org "$admin_token" "${ORG_NAME}" "${MAIN_PORG_TITLE}" "${owner_url}"
main_porg_url="${RESULT}"
add_cs_admin_user "${provider_token}" "${ORG_NAME}" "${main_porg_url}"
add_catalog "${provider_token}" "${ORG_NAME}" "${main_porg_url}" "${MAIN_CATALOG}" "${MAIN_CATALOG_TITLE}"

# Test org/catalog
create_org "$admin_token" "${ORG_NAME_DDD}" "${TEST_PORG_TITLE}" "${owner_url}"
test_porg_url="${RESULT}"
add_cs_admin_user "${provider_token}" "${ORG_NAME_DDD}" "${test_porg_url}"
add_catalog "${provider_token}" "${ORG_NAME_DDD}" "${test_porg_url}" "${TEST_CATALOG}" "${TEST_CATALOG_TITLE}"


echo "Checking if the Admin org mail server has already been created"
response=`curl GET https://${API_EP}/api/orgs/admin/mail-servers/default-mail-server \
               -s -k -H "Content-Type: application/json" -H "Accept: application/json" \
               -H "Authorization: Bearer ${admin_token}"`
$DEBUG && echo "[DEBUG] $(echo ${response} | jq .)"
if [[ "$(echo ${response} | jq -r '.status')" == "404" ]]; then
  echo "Create the default mail server for the Admin org"
  response=`curl https://${API_EP}/api/orgs/admin/mail-servers \
                 -s -k -H "Content-Type: application/json" -H "Accept: application/json" \
                 -H "Authorization: Bearer ${admin_token}" \
                 -d "{ \"title\": \"Default Mail Server\",
                       \"name\": \"default-mail-server\",
                       \"host\": \"${MAIL_SERVER_HOST}\",
                       \"port\": ${MAIL_SERVER_PORT},
                       \"credentials\": {
                         \"username\": \"${MAIL_SERVER_USERNAME}\",
                         \"password\": \"${MAIL_SERVER_PASSWORD}\"
                        }
                      }"`
  $DEBUG && echo "[DEBUG] $(echo ${response} | jq .)"
fi

echo "Updating mail settings"
response=`curl -X PUT https://${API_EP}/api/cloud/settings \
              -s -k -H "Content-Type: application/json" -H "Accept: application/json" \
              -H "Authorization: Bearer ${admin_token}" \
              -d "{
                \"mail_server_url\": \"https://${API_EP}/api/orgs/admin/mail-servers/default-mail-server\",
                \"email_sender\": {
                  \"name\": \"APIC Administrator\",
                  \"address\": \"${provider_email}\"
                }
              }"`
$DEBUG && echo "[DEBUG] $(echo ${response} | jq .)"

echo "Checking if the ace toolkit registration has been created"
response=`curl GET https://${API_EP}/api/cloud/registrations/ace-v11 \
               -s -k -H "Content-Type: application/json" -H "Accept: application/json" \
               -H "Authorization: Bearer ${admin_token}"`
$DEBUG && echo "[DEBUG] $(echo ${response} | jq .)"
if [[ "$(echo ${response} | jq -r '.status')" == "404" ]]; then
  echo "Registering ace"
  response=`curl POST https://${API_EP}/api/cloud/registrations \
                 -s -k -H "Content-Type: application/json" -H "Accept: application/json" \
                 -H "Authorization: Bearer ${admin_token}" \
                 -d "{ \"title\": \"${ACE_REGISTRATION_SECRET_NAME}\",
                       \"name\": \"ace-v11\",
                       \"client_type\": \"toolkit\",
                       \"client_id\": \"ace-v11\",
                       \"client_secret\": \"myclientid123\"
                     }"`
  $DEBUG && echo "[DEBUG] $(echo ${response} | jq .)"
fi

echo "Creating/updating ${ACE_REGISTRATION_SECRET_NAME} secret"
YAML=$(oc create secret generic -n ${NAMESPACE} ${ACE_REGISTRATION_SECRET_NAME} \
  --from-literal=client_id=ace-v11 \
  --from-literal=client_secret=myclientid123 \
  --dry-run=client -o yaml)
OCApplyYAML "$NAMESPACE" "$YAML"

# pull together any necessary info from in-cluster resources
PROVIDER_CREDENTIALS=$(oc get secret $PROVIDER_SECRET_NAME -n $NAMESPACE -o json | jq .data)
ACE_CREDENTIALS=$(oc get secret $ACE_REGISTRATION_SECRET_NAME -n $NAMESPACE -o json | jq .data)

for i in $(seq 1 60); do
  PORTAL_WWW_POD=$(oc get pods -n $NAMESPACE | grep -m1 "${RELEASE_NAME:0:10}-.*-www" | awk '{print $1}')
  $DEBUG && echo "[DEBUG] PORTAL_WWW_POD=${PORTAL_WWW_POD}"
  PORTAL_SITE_UUID=$(oc exec -n $NAMESPACE -it $PORTAL_WWW_POD -c admin -- /opt/ibm/bin/list_sites | awk '{print $1}')
  $DEBUG && echo "[DEBUG] PORTAL_SITE_UUID=${PORTAL_SITE_UUID}"
  PORTAL_SITE_RESET_URL=$(oc exec -n $NAMESPACE -it $PORTAL_WWW_POD -c admin -- /opt/ibm/bin/site_login_link $PORTAL_SITE_UUID | tail -1)
  $DEBUG && echo "[DEBUG] PORTAL_SITE_RESET_URL=${PORTAL_SITE_RESET_URL}"
  if [[ "$PORTAL_SITE_RESET_URL" =~ "https://$PTL_WEB_EP" ]]; then
    printf "$TICK"
    echo "[OK] Got the portal_site_password_reset_link"
    break
  else
    echo "Waiting for the portal_site_password_reset_link to be available (Attempt $i of 60)."
    echo "Checking again in one minute..."
    sleep 60
  fi
done

API_MANAGER_USER=$(echo $PROVIDER_CREDENTIALS | jq -r .username | base64 --decode)
API_MANAGER_PASS=$(echo $PROVIDER_CREDENTIALS | jq -r .password | base64 --decode)
ACE_CLIENT_ID=$(echo $ACE_CREDENTIALS | jq -r .client_id | base64 --decode)
ACE_CLIENT_SECRET=$(echo $ACE_CREDENTIALS | jq -r .client_secret | base64 --decode)

# Wait for the GatewayCluster to get created
for i in $(seq 1 720); do
  oc get -n $NAMESPACE GatewayCluster/${RELEASE_NAME}-gw
  if [[ $? == 0 ]]; then
    printf "$TICK"
    echo "[OK] GatewayCluster/${RELEASE_NAME}-gw"
    break
  else
    echo "Waiting for GatewayCluster/${RELEASE_NAME}-gw to be created (Attempt $i of 720)."
    echo "Checking again in 10 seconds..."
    sleep 10
  fi
done

if [[ "$ha_enabled" == "true" ]]; then
  oc patch -n ${NAMESPACE} GatewayCluster/${RELEASE_NAME}-gw --patch '{"spec":{"profile":"n3xc4.m8","replicaCount":3}}' --type=merge
else
  oc patch -n ${NAMESPACE} GatewayCluster/${RELEASE_NAME}-gw --patch '{"spec":{"profile":"n1xc1.m8","replicaCount":1}}' --type=merge
fi

printf "$TICK"
echo "
********** Configuration **********
api_manager_ui: https://$APIM_UI_EP/manager
cloud_manager_ui: https://$CMC_UI_EP/admin
platform_api: https://$API_EP/api
consumer_api: https://$C_API_EP/consumer-api
provider_credentials (api manager):
  username: ${API_MANAGER_USER}
  password: ${API_MANAGER_PASS}
portal_site_password_reset_link: $PORTAL_SITE_RESET_URL
ace_registration:
  client_id: ${ACE_CLIENT_ID}
  client_secret: ${ACE_CLIENT_SECRET}
"
