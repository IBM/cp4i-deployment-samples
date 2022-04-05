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

ha_enabled="true"
NAMESPACE="cp4i"
RELEASE_NAME="ademo"
ORG_NAME="main-demo"
ORG_NAME_DDD="ddd-demo-test"
tick="\xE2\x9C\x85"
cross="\xE2\x9D\x8C"
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

if [[ $(oc get secret cp4i-demo-apic-smtp-secret -n "$NAMESPACE") ]]; then
  MAIL_SERVER_HOST=$(oc get secret cp4i-demo-apic-smtp-secret -n "$NAMESPACE" -o json | jq -r '.data.mailServerHost' | base64 --decode)
  MAIL_SERVER_PORT=$(oc get secret cp4i-demo-apic-smtp-secret -n "$NAMESPACE" -o json | jq -r '.data.mailServerPort' | base64 --decode)
  MAIL_SERVER_USERNAME=$(oc get secret cp4i-demo-apic-smtp-secret -n "$NAMESPACE" -o json | jq -r '.data.mailServerUsername' | base64 --decode)
  MAIL_SERVER_PASSWORD=$(oc get secret cp4i-demo-apic-smtp-secret -n "$NAMESPACE" -o json | jq -r '.data.mailServerPassword' | base64 --decode)
  PORG_ADMIN_EMAIL=$(oc get secret cp4i-demo-apic-smtp-secret -n "$NAMESPACE" -o json | jq -r '.data.emailAddress' | base64 --decode)
else
  echo -e "\nThe secret 'cp4i-demo-apic-smtp-secret' does not exist in the namespace '$NAMESPACE', continuing configuring APIC with default SMTP values..."
fi

MAIL_SERVER_HOST=${MAIL_SERVER_HOST:-"smtp.mailtrap.io"}
MAIL_SERVER_PORT=${MAIL_SERVER_PORT:-"2525"}
MAIL_SERVER_USERNAME=${MAIL_SERVER_USERNAME:-"<your-username>"}
MAIL_SERVER_PASSWORD=${MAIL_SERVER_PASSWORD:-"<your-password>"}

echo "Waiting for APIC installation to complete..."
for i in $(seq 1 120); do
  APIC_STATUS=$(oc get apiconnectcluster.apiconnect.ibm.com -n $NAMESPACE ${RELEASE_NAME} -o jsonpath='{.status.phase}')
  if [ "$APIC_STATUS" == "Ready" ]; then
    printf "$tick"
    echo "[OK] APIC is ready"
    break
  else
    echo "Waiting for APIC install to complete (Attempt $i of 120). Status: $APIC_STATUS"
    oc get apiconnectcluster,managementcluster,portalcluster,gatewaycluster -n $NAMESPACE
    oc get pvc,pod -n $NAMESPACE -l app.kubernetes.io/managed-by=ibm-apiconnect -l app.kubernetes.io/part-of=${RELEASE_NAME}
    echo "Checking again in one minute..."
    sleep 60
  fi
done

if [ "$APIC_STATUS" != "Ready" ]; then
  printf "$cross"
  echo "[ERROR] APIC failed to install"
  exit 1
fi

for i in $(seq 1 60); do
  PORTAL_WWW_POD=$(oc get pods -n $NAMESPACE | grep -m1 "${RELEASE_NAME}-ptl.*www" | awk '{print $1}')
  if [ -z "$PORTAL_WWW_POD" ]; then
    echo "Not got portal pod yet"
  else
    PORTAL_WWW_ADMIN_READY=$(oc get pod -n ${NAMESPACE} ${PORTAL_WWW_POD} -o json | jq '.status.containerStatuses[0].ready')
    if [[ "$PORTAL_WWW_ADMIN_READY" == "true" ]]; then
      printf "$tick"
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
oc get pod -n $NAMESPACE -l app.kubernetes.io/managed-by=ibm-apiconnect -l app.kubernetes.io/part-of=${RELEASE_NAME}

# obtain endpoint info from APIC v10 routes
APIM_UI_EP=$(oc get route -n $NAMESPACE ${RELEASE_NAME}-mgmt-api-manager -o jsonpath='{.spec.host}')
CMC_UI_EP=$(oc get route -n $NAMESPACE ${RELEASE_NAME}-mgmt-admin -o jsonpath='{.spec.host}')
C_API_EP=$(oc get route -n $NAMESPACE ${RELEASE_NAME}-mgmt-consumer-api -o jsonpath='{.spec.host}')
API_EP=$(oc get route -n $NAMESPACE ${RELEASE_NAME}-mgmt-platform-api -o jsonpath='{.spec.host}')
PTL_WEB_EP=$(oc get route -n $NAMESPACE ${RELEASE_NAME}-ptl-portal-web -o jsonpath='{.spec.host}')

admin_idp=admin/default-idp-1
admin_password=$(oc get secret -n $NAMESPACE ${RELEASE_NAME}-mgmt-admin-pass -o json | jq -r .data.password | base64 --decode)

provider_user_registry=api-manager-lur
provider_idp=provider/default-idp-2
provider_username=cp4i-admin
provider_email=${PORG_ADMIN_EMAIL:-"cp4i-admin@apiconnect.net"} # update to recipient of portal site creation email
provider_password=engageibmAPI1
provider_firstname=CP4I
provider_lastname=Administrator

MAIN_PORG="main-ademo"
MAIN_PORG_TITLE="Org for Demo use (${MAIN_PORG})"
MAIN_CATALOG="${MAIN_PORG}-catalog"
MAIN_CATALOG_TITLE="Catalog for Demo use (${MAIN_CATALOG})"

TEST_PORG="ddd-demo-test"
TEST_PORG_TITLE="Org for Demo use (${TEST_PORG})"
TEST_CATALOG="${TEST_PORG}-catalog"
TEST_CATALOG_TITLE="Catalog for Demo use (${TEST_CATALOG})"

management=$(oc get route -n $NAMESPACE ${RELEASE_NAME}-mgmt-platform-api -o jsonpath="{.spec.host}")
echo "management=${management}"

echo Authenticate as the admin user
response=`curl -X POST https://${management}/api/token \
               -s -k -H "Content-Type: application/json" -H "Accept: application/json" \
               -d "{ \"realm\": \"${admin_idp}\",
                     \"username\": \"admin\",
                     \"password\": \"${admin_password}\",
                     \"client_id\": \"599b7aef-8841-4ee2-88a0-84d49c4d6ff2\",
                     \"client_secret\": \"0ea28423-e73b-47d4-b40e-ddb45c48bb0c\",
                     \"grant_type\": \"password\" }"`
$DEBUG && echo "[DEBUG]$(echo ${response} | jq .)"
export admin_token=`echo ${response} | jq -r '.access_token'`

echo Get the Admin Organization User Registries
response=`curl -X GET https://${management}/api/orgs/admin/user-registries \
               -s -k -H "Accept: application/json" \
               -H "Authorization: Bearer ${admin_token}"`
$DEBUG && echo "[DEBUG] $(echo ${response} | jq .)"
api_manager_lur_url=$(echo ${response} | jq -r '.results[]|select(.name=="api-manager-lur")|.url')
echo "api_manager_lur_url=${api_manager_lur_url}"

echo Get the Cloud Scope User Registries Setting
response=`curl -X GET https://${management}/api/cloud/settings/user-registries \
               -s -k -H "Accept: application/json" \
               -H "Authorization: Bearer ${admin_token}"`
$DEBUG && echo "[DEBUG] $(echo ${response} | jq .)"

echo Add the api-manager-lur to the list of providers
new_registry_settings=$(echo ${response} | jq -c ".provider_user_registry_urls += [\"${api_manager_lur_url}\"]")
response=`curl -X PUT https://${management}/api/cloud/settings/user-registries \
               -s -k -H "Content-Type: application/json" -H "Accept: application/json" \
               -H "Authorization: Bearer ${admin_token}" \
               -d ''${new_registry_settings}''`
$DEBUG && echo "[DEBUG] $(echo ${response} | jq .)"

echo "Checking if the user named ${provider_username} already exists"
response=`curl GET https://${management}/api/user-registries/admin/${provider_user_registry}/users/${provider_username} \
               -s -k -H "Content-Type: application/json" -H "Accept: application/json" \
               -H "Authorization: Bearer ${admin_token}"`
$DEBUG && echo "[DEBUG] $(echo ${response} | jq .)"
owner_url=`echo ${response} | jq -r '.url' | sed "s/\/integration\/apis\/$NAMESPACE\/$RELEASE_NAME//"`
if [[ "${owner_url}" == "null" ]]; then
  echo Create the Provider Organization Owner
  response=`curl https://${management}/api/user-registries/admin/${provider_user_registry}/users \
                 -s -k -H "Content-Type: application/json" -H "Accept: application/json" \
                 -H "Authorization: Bearer ${admin_token}" \
                 -d "{ \"username\": \"${provider_username}\",
                       \"password\": \"${provider_password}\",
                       \"email\": \"${provider_email}\",
                       \"first_name\": \"${provider_firstname}\",
                       \"last_name\": \"${provider_lastname}\" }"`
  $DEBUG && echo "[DEBUG] $(echo ${response} | jq .)"
  owner_url=`echo ${response} | jq -r '.url' | sed "s/\/integration\/apis\/$NAMESPACE\/$RELEASE_NAME//"`
fi
echo "owner_url=${owner_url}"

echo Authenticate as the Provider Organization Owner
response=`curl -X POST https://${management}/api/token \
               -s -k -H "Content-Type: application/json" -H "Accept: application/json" \
               -d "{ \"realm\": \"${provider_idp}\",
                     \"username\": \"${provider_username}\",
                     \"password\": \"${provider_password}\",
                     \"client_id\": \"599b7aef-8841-4ee2-88a0-84d49c4d6ff2\",
                     \"client_secret\": \"0ea28423-e73b-47d4-b40e-ddb45c48bb0c\",
                     \"grant_type\": \"password\" }"`
$DEBUG && echo "[DEBUG] $(echo ${response} | jq .)"
export provider_token=`echo ${response} | jq -r '.access_token'`
$DEBUG && echo "[DEBUG] $(echo "provider_token=${provider_token}")"

echo "Checking if the provider org named ${MAIN_PORG} already exists"
response=`curl GET https://${management}/api/orgs/${MAIN_PORG} \
               -s -k -H "Content-Type: application/json" -H "Accept: application/json" \
               -H "Authorization: Bearer ${admin_token}"`
$DEBUG && echo "[DEBUG] $(echo ${response} | jq .)"
main_porg_url=`echo ${response} | jq -r '.url' | sed "s/\/integration\/apis\/$NAMESPACE\/$RELEASE_NAME//"`
if [[ "${main_porg_url}" == "null" ]]; then
  echo Create the ${MAIN_PORG} Provider Organization
  response=`curl https://${management}/api/cloud/orgs \
                 -s -k -H "Content-Type: application/json" -H "Accept: application/json" \
                 -H "Authorization: Bearer ${admin_token}" \
                 -d "{ \"name\": \"${MAIN_PORG}\",
                       \"title\": \"${MAIN_PORG_TITLE}\",
                       \"org_type\": \"provider\",
                       \"owner_url\": \"${owner_url}\" }"`
  $DEBUG && echo "[DEBUG] $(echo ${response} | jq .)"
  main_porg_url=`echo ${response} | jq -r '.url' | sed "s/\/integration\/apis\/$NAMESPACE\/$RELEASE_NAME//"`
fi
echo "main_porg_url=${main_porg_url}"

echo Get the Provider Organization Roles for ${MAIN_PORG}
response=`curl -X GET ${main_porg_url}/roles \
               -s -k -H "Accept: application/json" \
               -H "Authorization: Bearer ${provider_token}"`
$DEBUG && echo "[DEBUG] $(echo ${response} | jq .)"
main_administrator_role_url=$(echo ${response} | jq -r '.results[]|select(.name=="administrator")|.url')
echo "main_administrator_role_url=${main_administrator_role_url}"

echo Add the CS admin user to the list of members for ${MAIN_PORG}
member_json='{
  "name": "cs-admin",
  "user": {
    "identity_provider": "common-services",
    "url": "https://'${management}'/api/user-registries/admin/common-services/users/admin"
  },
  "role_urls": [
    "'${main_administrator_role_url}'"
  ]
}'
member_json=$(echo $member_json | jq -c .)
response=`curl -X POST ${main_porg_url}/members \
               -s -k -H "Content-Type: application/json" -H "Accept: application/json" \
               -H "Authorization: Bearer ${provider_token}" \
               -d ''$member_json''`
$DEBUG && echo "[DEBUG] $(echo ${response} | jq .)"

echo "Checking if the provider org named ${TEST_PORG} already exists"
response=`curl GET https://${management}/api/orgs/${TEST_PORG} \
               -s -k -H "Content-Type: application/json" -H "Accept: application/json" \
               -H "Authorization: Bearer ${admin_token}"`
$DEBUG && echo "[DEBUG] $(echo ${response} | jq .)"
test_porg_url=`echo ${response} | jq -r '.url' | sed "s/\/integration\/apis\/$NAMESPACE\/$RELEASE_NAME//"`
if [[ "${test_porg_url}" == "null" ]]; then
  echo Create the ${TEST_PORG} Provider Organization
  response=`curl https://${management}/api/cloud/orgs \
                 -s -k -H "Content-Type: application/json" -H "Accept: application/json" \
                 -H "Authorization: Bearer ${admin_token}" \
                 -d "{ \"name\": \"${TEST_PORG}\",
                       \"title\": \"${TEST_PORG_TITLE}\",
                       \"org_type\": \"provider\",
                       \"owner_url\": \"${owner_url}\" }"`
  $DEBUG && echo "[DEBUG] $(echo ${response} | jq .)"
  test_porg_url=`echo ${response} | jq -r '.url' | sed "s/\/integration\/apis\/$NAMESPACE\/$RELEASE_NAME//"`
fi
echo "test_porg_url=${test_porg_url}"

echo Get the Provider Organization Roles for ${TEST_PORG}
response=`curl -X GET ${test_porg_url}/roles \
               -s -k -H "Accept: application/json" \
               -H "Authorization: Bearer ${provider_token}"`
$DEBUG && echo "[DEBUG] $(echo ${response} | jq .)"
test_administrator_role_url=$(echo ${response} | jq -r '.results[]|select(.name=="administrator")|.url')
echo "test_administrator_role_url=${test_administrator_role_url}"

echo Add the CS admin user to the list of members for ${TEST_PORG}
member_json='{
  "name": "cs-admin",
  "user": {
    "identity_provider": "common-services",
    "url": "https://'${management}'/api/user-registries/admin/common-services/users/admin"
  },
  "role_urls": [
    "'${test_administrator_role_url}'"
  ]
}'
member_json=$(echo $member_json | jq -c .)
curl -v -X POST ${test_porg_url}/members \
               -s -k -H "Content-Type: application/json" -H "Accept: application/json" \
               -H "Authorization: Bearer ${provider_token}" \
               -d ''$member_json''
# TODO Error check

echo "Checking if the Admin org mail server has already been created"
response=`curl GET https://${management}/api/orgs/admin/mail-servers/default-mail-server \
               -s -k -H "Content-Type: application/json" -H "Accept: application/json" \
               -H "Authorization: Bearer ${admin_token}"`
$DEBUG && echo "[DEBUG] $(echo ${response} | jq .)"
if [[ "$(echo ${response} | jq -r '.status')" == "404" ]]; then
  echo "Create the default mail server for the Admin org"
  response=`curl https://${management}/api/orgs/admin/mail-servers \
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
  # TODO Error checking!
fi

echo Updating mail settings
response=`curl -X PUT https://${management}/api/cloud/settings \
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
response=`curl GET https://${management}/api/cloud/registrations/ace-v11 \
               -s -k -H "Content-Type: application/json" -H "Accept: application/json" \
               -H "Authorization: Bearer ${admin_token}"`
$DEBUG && echo "[DEBUG] $(echo ${response} | jq .)"
if [[ "$(echo ${response} | jq -r '.status')" == "404" ]]; then
  echo Registering ace
  response=`curl POST https://${management}/api/cloud/registrations \
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
oc create secret generic -n ${NAMESPACE} ${ACE_REGISTRATION_SECRET_NAME} \
  --from-literal=client_id=ace-v11 \
  --from-literal=client_secret=myclientid123 \
  --dry-run -o yaml | oc apply -f -

echo "Checking if the catalog named ${MAIN_CATALOG} already exists"
response=`curl -X GET https://${management}/api/catalogs/${MAIN_PORG}/${MAIN_CATALOG} \
               -s -k -H "Content-Type: application/json" -H "Accept: application/json" \
               -H "Authorization: Bearer ${provider_token}"`
$DEBUG && echo "[DEBUG] $(echo ${response} | jq .)"
main_catalog_url=`echo ${response} | jq -r '.url' | sed "s/\/integration\/apis\/$NAMESPACE\/$RELEASE_NAME//"`
if [[ "${main_catalog_url}" == "null" ]]; then
  echo Create the Catalog
  echo "main_porg_url = ${main_porg_url}"
  response=`curl -X POST ${main_porg_url}/catalogs \
                 -s -k -H "Content-Type: application/json" -H "Accept: application/json" \
                 -H "Authorization: Bearer ${provider_token}" \
                 -d "{ \"name\": \"${MAIN_CATALOG}\",
                       \"title\": \"${MAIN_CATALOG_TITLE}\" }"`
  $DEBUG && echo "[DEBUG] $(echo ${response} | jq .)"
  main_catalog_url=`echo ${response} | jq -r '.url' | sed "s/\/integration\/apis\/$NAMESPACE\/$RELEASE_NAME//"`
fi
echo "main_catalog_url=${main_catalog_url}"

# pull together any necessary info from in-cluster resources
PROVIDER_CREDENTIALS=$(oc get secret $PROVIDER_SECRET_NAME -n $NAMESPACE -o json | jq .data)
ACE_CREDENTIALS=$(oc get secret $ACE_REGISTRATION_SECRET_NAME -n $NAMESPACE -o json | jq .data)

for i in $(seq 1 60); do
  PORTAL_WWW_POD=$(oc get pods -n $NAMESPACE | grep -m1 "${RELEASE_NAME}-ptl.*www" | awk '{print $1}')
  PORTAL_SITE_UUID=$(oc exec -n $NAMESPACE -it $PORTAL_WWW_POD -c admin -- /opt/ibm/bin/list_sites | awk '{print $1}')
  PORTAL_SITE_RESET_URL=$(oc exec -n $NAMESPACE -it $PORTAL_WWW_POD -c admin -- /opt/ibm/bin/site_login_link $PORTAL_SITE_UUID | tail -1)
  if [[ "$PORTAL_SITE_RESET_URL" =~ "https://$PTL_WEB_EP" ]]; then
    printf "$tick"
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

if [[ "$ha_enabled" == "true" ]]; then
  # Wait for the GatewayCluster to get created
  for i in $(seq 1 720); do
    oc get -n $NAMESPACE GatewayCluster/${RELEASE_NAME}-gw
    if [[ $? == 0 ]]; then
      printf "$tick"
      echo "[OK] GatewayCluster/${RELEASE_NAME}-gw"
      break
    else
      echo "Waiting for GatewayCluster/${RELEASE_NAME}-gw to be created (Attempt $i of 720)."
      echo "Checking again in 10 seconds..."
      sleep 10
    fi
  done
  oc patch -n ${NAMESPACE} GatewayCluster/${RELEASE_NAME}-gw --patch '{"spec":{"profile":"n3xc4.m8","replicaCount":3}}' --type=merge
fi

printf "$tick"
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
