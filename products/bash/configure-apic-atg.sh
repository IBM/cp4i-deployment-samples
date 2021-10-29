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
#
# USAGE:
#   With default values
#     ./configure-apic-v10.sh
#
#   Overriding the NAMESPACE and release-name
#     ./configure-apic-v10 -n cp4i-prod -r prod

SCRIPT_DIR=$(dirname $0)

namespace="cp4i"
release_name="ademo"
tick="\xE2\x9C\x85"
cross="\xE2\x9D\x8C"

function usage() {
  echo "Usage: $0 -n <NAMESPACE> -r <RELEASE_NAME>"
}

while getopts "n:r:" opt; do
  case ${opt} in
  n)
    namespace="$OPTARG"
    ;;
  r)
    release_name="$OPTARG"
    ;;
  \?)
    usage
    exit
    ;;
  esac
done

set -e

echo "Waiting for APIC installation to complete..."
for i in $(seq 1 120); do
  APIC_STATUS=$(kubectl get apiconnectcluster.apiconnect.ibm.com -n $namespace ${release_name} -o jsonpath='{.status.phase}')
  if [ "$APIC_STATUS" == "Ready" ]; then
    printf "$tick"
    echo "[OK] APIC is ready"
    break
  else
    echo "Waiting for APIC install to complete (Attempt $i of 120). Status: $APIC_STATUS"
    kubectl get apic,pods,pvc -n $namespace
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
  PORTAL_WWW_POD=$(oc get pods -n $namespace | grep -m1 "${release_name}-ptl.*www" | awk '{print $1}')
  if [ -z "$PORTAL_WWW_POD" ]; then
    echo "Not got portal pod yet"
  else
    PORTAL_WWW_ADMIN_READY=$(oc get pod -n ${namespace} ${PORTAL_WWW_POD} -o json | jq '.status.containerStatuses[0].ready')
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
kubectl get pod -n $namespace

echo "APIC Setup"
echo "- Enable the api-manager-lur provider"
echo '- Create "atg-org" organization'
echo "- Add the CS admin user to the org as an administrator"
echo '- Create "atg-cat" catalog'
echo "- Publish the bookshop API"
echo "- Setup a user for APIC Analytics"

# namespace=dan
# namespace=cp4i
# release_name=ademo

admin_idp=admin/default-idp-1
admin_password=$(oc get secret -n $namespace ${release_name}-mgmt-admin-pass -o json | jq -r .data.password | base64 --decode)

provider_user_registry=api-manager-lur
provider_idp=provider/default-idp-2
provider_username=cp4i-admin
provider_email=${PORG_ADMIN_EMAIL:-"cp4i-admin@apiconnect.net"} # update to recipient of portal site creation email
provider_password=engageibmAPI1
provider_firstname=CP4I
provider_lastname=Administrator

atg_test_user_registry=api-manager-lur
atg_test_idp=provider/default-idp-2
atg_test_username=atg-test
atg_test_email=atg@test.com
atg_test_password=Password02
atg_test_firstname=atg
atg_test_lastname=test

porg=atg-org
porg_title="API Test Generation Provider Organization"

catalog=atg-cat
catalog_title="API Test Generation Catalog"

management=$(oc get route -n $namespace ${release_name}-mgmt-platform-api -o jsonpath="{.spec.host}")
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
echo ${response} | jq .
export admin_token=`echo ${response} | jq -r '.access_token'`


echo Get the Admin Organization User Registries
response=`curl -X GET https://${management}/api/orgs/admin/user-registries \
               -s -k -H "Accept: application/json" \
               -H "Authorization: Bearer ${admin_token}"`
echo ${response} | jq .
api_manager_lur_url=$(echo ${response} | jq -r '.results[]|select(.name=="api-manager-lur")|.url')
echo "api_manager_lur_url=${api_manager_lur_url}"


echo Get the Cloud Scope User Registries Setting
response=`curl -X GET https://${management}/api/cloud/settings/user-registries \
               -s -k -H "Accept: application/json" \
               -H "Authorization: Bearer ${admin_token}"`
echo ${response} | jq .


echo Add the api-manager-lur to the list of providers
new_registry_settings=$(echo ${response} | jq -c ".provider_user_registry_urls += [\"${api_manager_lur_url}\"]")
response=`curl -X PUT https://${management}/api/cloud/settings/user-registries \
               -s -k -H "Content-Type: application/json" -H "Accept: application/json" \
               -H "Authorization: Bearer ${admin_token}" \
               -d ''${new_registry_settings}''`
echo ${response} | jq .


echo "Checking if the user named ${provider_username} already exists"
response=`curl GET https://${management}/api/user-registries/admin/${provider_user_registry}/users/${provider_username} \
               -s -k -H "Content-Type: application/json" -H "Accept: application/json" \
               -H "Authorization: Bearer ${admin_token}"`
echo ${response} | jq .
owner_url=`echo ${response} | jq -r '.url' | sed "s/\/integration\/apis\/$namespace\/$release_name//"`
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
  echo ${response} | jq .
  owner_url=`echo ${response} | jq -r '.url' | sed "s/\/integration\/apis\/$namespace\/$release_name//"`
fi
echo "owner_url=${owner_url}"


echo "Checking if the provider org named ${porg} already exists"
response=`curl GET https://${management}/api/orgs/${porg} \
               -s -k -H "Content-Type: application/json" -H "Accept: application/json" \
               -H "Authorization: Bearer ${admin_token}"`
echo ${response} | jq .
porg_url=`echo ${response} | jq -r '.url' | sed "s/\/integration\/apis\/$namespace\/$release_name//"`
if [[ "${porg_url}" == "null" ]]; then
  echo Create the Provider Organization
  response=`curl https://${management}/api/cloud/orgs \
                 -s -k -H "Content-Type: application/json" -H "Accept: application/json" \
                 -H "Authorization: Bearer ${admin_token}" \
                 -d "{ \"name\": \"${porg}\",
                       \"title\": \"${porg_title}\",
                       \"org_type\": \"provider\",
                       \"owner_url\": \"${owner_url}\" }"`
  echo ${response} | jq .
  porg_url=`echo ${response} | jq -r '.url' | sed "s/\/integration\/apis\/$namespace\/$release_name//"`
fi
echo "porg_url=${porg_url}"


# echo Get the Provider Organization Owner
# response=`curl -X GET ${owner_url} \
#                -s -k -H "Accept: application/json" \
#                -H "Authorization: Bearer ${admin_token}"`
# echo ${response} | jq .
#
#
# echo Get the Provider Organization
# response=`curl -X GET ${porg_url} \
#                -s -k -H "Accept: application/json" \
#                -H "Authorization: Bearer ${admin_token}"`
# echo ${response} | jq .


echo Authenticate as the Provider Organization Owner
response=`curl -X POST https://${management}/api/token \
               -s -k -H "Content-Type: application/json" -H "Accept: application/json" \
               -d "{ \"realm\": \"${provider_idp}\",
                     \"username\": \"${provider_username}\",
                     \"password\": \"${provider_password}\",
                     \"client_id\": \"599b7aef-8841-4ee2-88a0-84d49c4d6ff2\",
                     \"client_secret\": \"0ea28423-e73b-47d4-b40e-ddb45c48bb0c\",
                     \"grant_type\": \"password\" }"`
echo ${response} | jq .
export provider_token=`echo ${response} | jq -r '.access_token'`
echo "provider_token=${provider_token}"


# echo Get the Provider Organization Members
# response=`curl -X GET ${porg_url}/members \
#                -s -k -H "Accept: application/json" \
#                -H "Authorization: Bearer ${provider_token}"`
# echo ${response} | jq .


echo Get the Provider Organization Roles
response=`curl -X GET ${porg_url}/roles \
               -s -k -H "Accept: application/json" \
               -H "Authorization: Bearer ${provider_token}"`
echo ${response} | jq .
administrator_role_url=$(echo ${response} | jq -r '.results[]|select(.name=="administrator")|.url')
echo "administrator_role_url=${administrator_role_url}"
developer_role_url=$(echo ${response} | jq -r '.results[]|select(.name=="developer")|.url')
echo "developer_role_url=${developer_role_url}"


# TODO What if the CS admin user is already a member? Especially with the wrong role?
echo Add the CS admin user to the list of members
member_json='{
  "name": "cs-admin",
  "user": {
    "identity_provider": "common-services",
    "url": "https://'${management}'/api/user-registries/admin/common-services/users/admin"
  },
  "role_urls": [
    "'${administrator_role_url}'"
  ]
}'
member_json=$(echo $member_json | jq -c .)
response=`curl -X POST ${porg_url}/members \
               -s -k -H "Content-Type: application/json" -H "Accept: application/json" \
               -H "Authorization: Bearer ${provider_token}" \
               -d ''$member_json''`
echo ${response} | jq .


# echo Get the Provider Organization Members
# response=`curl -X GET ${porg_url}/members \
#                -s -k -H "Accept: application/json" \
#                -H "Authorization: Bearer ${provider_token}"`
# echo ${response} | jq .


echo "Checking if the catalog named ${catalog} already exists"
response=`curl -X GET https://${management}/api/catalogs/${porg}/${catalog} \
               -s -k -H "Content-Type: application/json" -H "Accept: application/json" \
               -H "Authorization: Bearer ${provider_token}"`
echo ${response} | jq .
catalog_url=`echo ${response} | jq -r '.url' | sed "s/\/integration\/apis\/$namespace\/$release_name//"`
if [[ "${catalog_url}" == "null" ]]; then
  echo Create the Catalog
  response=`curl -X POST ${porg_url}/catalogs \
                 -s -k -H "Content-Type: application/json" -H "Accept: application/json" \
                 -H "Authorization: Bearer ${provider_token}" \
                 -d "{ \"name\": \"${catalog}\",
                       \"title\": \"${catalog_title}\" }"`
  echo ${response} | jq .
  catalog_url=`echo ${response} | jq -r '.url' | sed "s/\/integration\/apis\/$namespace\/$release_name//"`
fi
echo "catalog_url=${catalog_url}"


echo "Publish bookshop to the catalog"
response=`curl -X POST ${catalog_url}/publish \
               -s -k -H "Accept: application/json" \
               -H "Authorization: Bearer ${provider_token}" \
               -H "content-type: multipart/form-data" \
               -F "openapi=@$SCRIPT_DIR/../../TestgenBookshopAPI/bookshop-v1.0.yaml;type=application/yaml" \
               -F "product=@$SCRIPT_DIR/../../TestgenBookshopAPI/bookshop-product.yaml;type=application/yaml"`
echo ${response} | jq .
configured_gateway_url=`echo ${response} | jq -r '.gateway_service_urls[0]' | sed "s/\/integration\/apis\/$namespace\/$release_name//"`

response=`curl -X GET ${configured_gateway_url} \
               -s -k -H "Accept: application/json" \
               -H "Authorization: Bearer ${provider_token}"`
echo "${response}" | jq .
api_endpoint=`echo ${response} | jq -r '.catalog_base'`
echo "api_endpoint=${api_endpoint}"


echo "Check if the ${atg_test_username} user already exists"
response=`curl https://${management}/api/user-registries/admin/${provider_user_registry}/users/${atg_test_username} \
               -s -k -H "Content-Type: application/json" -H "Accept: application/json" \
               -H "Authorization: Bearer ${admin_token}"`
echo ${response} | jq .
user_url=`echo ${response} | jq -r '.url' | sed "s/\/integration\/apis\/$namespace\/$release_name//"`
echo "user_url=${user_url}"
# TODO This assumes if the user exists it must be a member of the org. Could check if it's a member and if not then delete the user and re-invite.
if [[ "${user_url}" == "null" ]]; then
  member_invitation_json='{
    "type": "member_invitation",
    "api_version": "2.0.0",
    "name": "'${atg_test_username}'-invitation",
    "title": "'${atg_test_username}'-invitation",
    "scope": "org",
    "email": "'${atg_test_email}'",
    "org_type": "provider",
    "role_urls": [
      "'${developer_role_url}'"
    ]
  }'
  member_invitation_json=$(echo $member_invitation_json | jq -c .)
  response=`curl -X POST ${porg_url}/member-invitations \
                 -s -k -H "Content-Type: application/json" -H "Accept: application/json" \
                 -H "Authorization: Bearer ${provider_token}" \
                 -d ''$member_invitation_json''`
  echo ${response} | jq .

  cmOrgMgrUrl=$(echo $response | jq -r '.url' | sed "s/\/integration\/apis\/$namespace\/$release_name//")
  cmOrgMgrLink=$(echo $response | jq -r '.activation_link')
  echo "cmOrgMgr activation_link:  $cmOrgMgrLink"
  cmOrgMgrToken=$(echo $cmOrgMgrLink | awk -F awk -F "activation=" '{print $2}')
  cmOrgMgtAccess=$(echo $cmOrgMgrToken | base64 --decode)

  member_invitation_accept_json='{
    "realm": "'${provider_idp}'",
    "username": "'${atg_test_username}'",
    "email": "'${atg_test_email}'",
    "first_name":"'$atg_test_firstname'",
    "last_name":"'$atg_test_lastname'",
    "password":"'$atg_test_password'"
  }'
  member_invitation_accept_json=$(echo $member_invitation_accept_json | jq -c .)
  response=`curl -X POST $cmOrgMgrUrl/register \
                 -s -k -H "Content-Type: application/json" -H "Accept: application/json" \
                 -H "Authorization: Bearer ${cmOrgMgtAccess}" \
                 -H "X-IBM-Client-Id:599b7aef-8841-4ee2-88a0-84d49c4d6ff2" \
                 -H "X-IBM-Client-Secret:0ea28423-e73b-47d4-b40e-ddb45c48bb0c" \
                 -d ''$member_invitation_accept_json''`
  echo ${response} | jq .
fi

echo "Creating a CronJob that calls the bookshop every minute"
cat <<EOF | oc apply -f -
apiVersion: batch/v1
kind: CronJob
metadata:
  name: bookshop-client
  namespace: ${namespace}
spec:
  # The following is every 1 minute.
  # See https://crontab.guru/examples.html
  schedule: "* * * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: bookshop-client
            image: icr.io/integration/bookshop-api/client
            imagePullPolicy: IfNotPresent
            args:
              - "--url"
              - "$api_endpoint"
              - "--no-verify"
              - "--count"
              - "25"
              - "-v"
          restartPolicy: OnFailure
EOF

echo "porg_url=${porg_url}"
echo "owner_url=${owner_url}"

echo "TODO Some sort of status check, that:"
echo "- Jaeger is running"
echo "- Nav is running"
echo "- APIC is running"
echo "- Bookshop is running, and works via APIC"
echo "- There are traces in Jaeger"

echo ""
echo "Settings to use in ATM project"
echo ""
echo "Jaeger"
echo "======"
echo "Service in test: apiconnect"
echo "Service in production: apiconnect"
echo "Time range: - -"
echo "Results limit: 1500"
echo ""
echo "Data Service"
echo "============"
echo "Endpoint: https://${release_name}-mgmt-api-testgen-data.${namespace}.svc:3000"
echo "API key: dummy"
echo "TLS certificate: oc get secret -n ${namespace} ${release_name}-mgmt-server -o json | jq -r '.data[\"ca.crt\"]' | base64 --decode > ca.crt"
echo ""
echo "API Management"
echo "=============="
echo "Provider organization: ${porg}"
echo "Catalog: ${catalog}"
echo "Analytics service: analytics-service"
echo "Username: ${atg_test_username}"
echo "Password: ${atg_test_password}"
echo "Realm: ${atg_test_idp}"
echo "OpenAPI document: bookshop swagger"
echo ""
echo "Navigator: https://$(oc get route -n ${namespace} ${namespace}-navigator-pn -o json | jq -r .spec.host)"
echo "Jaeger: https://$(oc get route -n ${namespace} jaeger-bookshop -o json | jq -r .spec.host)"
