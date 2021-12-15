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

function usage() {
  echo "Usage: $0 -n <NAMESPACE> -r <RELEASE_NAME>"
}

OUTPUT=""
function handle_res() {
  local body=$1
  local status=$(echo ${body} | jq -r ".status")
  $DEBUG && echo "[DEBUG] res body: ${body}"
  $DEBUG && echo "[DEBUG] res status: ${status}"
  if [[ $status == "null" ]]; then
    OUTPUT="${body}"
  elif [[ $status == "409" ]]; then
    OUTPUT="${body}"
    echo "[INFO]  Resource already exists, continuing..."
  else
    echo -e "[ERROR] ${CROSS} Request failed: ${body}..."
    exit 1
  fi
}

while getopts "n:r:" opt; do
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
CATALOG_NAME="${ORG_NAME}-catalog"
CATALOG_NAME_DDD="${ORG_NAME_DDD}-catalog"
PORG_ADMIN_EMAIL=${PORG_ADMIN_EMAIL:-"cp4i-admin@apiconnect.net"} # update to recipient of portal site creation email
ACE_REGISTRATION_SECRET_NAME="ace-v11-service-creds"              # corresponds to registration obj currently hard-coded in configmap
PROVIDER_SECRET_NAME="cp4i-admin-creds"                           # corresponds to credentials obj currently hard-coded in configmap

STAGING_AUTHS=$(oc get secret --namespace ${NAMESPACE} ibm-entitlement-key -o json | jq -r '.data.".dockerconfigjson"' | base64 --decode | jq -r '.auths["cp.stg.icr.io"]')
if [[ "$STAGING_AUTHS" == "" || "$STAGING_AUTHS" == "null" ]]; then
  REPO="cp.icr.io"
else
  REPO="cp.stg.icr.io"
fi

if [[ $(oc get secret cp4i-demo-apic-smtp-secret -n "$NAMESPACE") ]]; then
  MAIL_SERVER_HOST=$(oc get secret cp4i-demo-apic-smtp-secret -n "$NAMESPACE" -o json | jq -r '.data.mailServerHost' | base64 --decode)
  MAIL_SERVER_PORT=$(oc get secret cp4i-demo-apic-smtp-secret -n "$NAMESPACE" -o json | jq -r '.data.mailServerPort' | base64 --decode)
  MAIL_SERVER_USERNAME=$(oc get secret cp4i-demo-apic-smtp-secret -n "$NAMESPACE" -o json | jq -r '.data.mailServerUsername' | base64 --decode)
  MAIL_SERVER_PASSWORD=$(oc get secret cp4i-demo-apic-smtp-secret -n "$NAMESPACE" -o json | jq -r '.data.mailServerPassword' | base64 --decode)
  PORG_ADMIN_EMAIL=$(oc get secret cp4i-demo-apic-smtp-secret -n "$NAMESPACE" -o json | jq -r '.data.emailAddress' | base64 --decode)
else
  echo -e "\nThe secret 'cp4i-demo-apic-smtp-secret' does not exist in the namespace '$NAMESPACE', continuing configuring APIC with default SMTP values..."
fi

CONFIGURATOR_IMAGE=${CONFIGURATOR_IMAGE:-"${REPO}/cp/apic/ibm-apiconnect-apiconnect-master@sha256:d6892c49d138b892dd932b8713b3e80450ec7bdee25a07c6bcbbaf94719e0075"}
MAIL_SERVER_HOST=${MAIL_SERVER_HOST:-"smtp.mailtrap.io"}
MAIL_SERVER_PORT=${MAIL_SERVER_PORT:-"2525"}
MAIL_SERVER_USERNAME=${MAIL_SERVER_USERNAME:-"<your-username>"}
MAIL_SERVER_PASSWORD=${MAIL_SERVER_PASSWORD:-"<your-password>"}

echo "Waiting for APIC installation to complete..."
for i in $(seq 1 120); do
  APIC_STATUS=$(kubectl get apiconnectcluster.apiconnect.ibm.com -n $NAMESPACE ${RELEASE_NAME} -o jsonpath='{.status.phase}')
  if [ "$APIC_STATUS" == "Ready" ]; then
    printf "$tick"
    echo "[OK] APIC is ready"
    break
  else
    echo "Waiting for APIC install to complete (Attempt $i of 120). Status: $APIC_STATUS"
    oc get apiconnectcluster,managementcluster,portalcluster,gatewaycluster,pods,pvc -n $NAMESPACE
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
kubectl get pod -n $NAMESPACE

# obtain cloud manager credentials secret name
CLOUD_MANAGER_PASS="$(oc get secret -n $NAMESPACE "${RELEASE_NAME}-mgmt-admin-pass" -o jsonpath='{.data.password}' | base64 --decode)"

# obtain endpoint info from APIC v10 routes
APIM_UI_EP=$(oc get route -n $NAMESPACE ${RELEASE_NAME}-mgmt-api-manager -o jsonpath='{.spec.host}')
CMC_UI_EP=$(oc get route -n $NAMESPACE ${RELEASE_NAME}-mgmt-admin -o jsonpath='{.spec.host}')
C_API_EP=$(oc get route -n $NAMESPACE ${RELEASE_NAME}-mgmt-consumer-api -o jsonpath='{.spec.host}')
API_EP=$(oc get route -n $NAMESPACE ${RELEASE_NAME}-mgmt-platform-api -o jsonpath='{.spec.host}')
PTL_WEB_EP=$(oc get route -n $NAMESPACE ${RELEASE_NAME}-ptl-portal-web -o jsonpath='{.spec.host}')

# create the k8s resources
echo "Applying manifests"
cat <<EOF | oc apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  namespace: ${NAMESPACE}
  name: ${RELEASE_NAME}-apic-configurator-post-install-sa
imagePullSecrets:
- name: ibm-entitlement-key
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: ${NAMESPACE}
  name: ${RELEASE_NAME}-apic-configurator-post-install-role
rules:
- apiGroups:
  - ""
  resources:
  - secrets
  verbs:
  - get
  - list
  - create
---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  namespace: ${NAMESPACE}
  name: ${RELEASE_NAME}-apic-configurator-post-install-rolebinding
subjects:
- kind: ServiceAccount
  name: ${RELEASE_NAME}-apic-configurator-post-install-sa
  namespace: ${NAMESPACE}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: ${RELEASE_NAME}-apic-configurator-post-install-role
---
apiVersion: v1
kind: Secret
metadata:
  namespace: ${NAMESPACE}
  name: ${RELEASE_NAME}-default-mail-server-creds
type: Opaque
stringData:
  default-mail-server-creds.yaml: |-
    mail_servers:
      - name: default-mail-server
        credentials:
          username: "${MAIL_SERVER_USERNAME}"
          password: "${MAIL_SERVER_PASSWORD}"
---
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: ${NAMESPACE}
  name: ${RELEASE_NAME}-configurator-base
data:
  configurator-base.yaml: |-
    logger:
      level: trace
    namespace: ${NAMESPACE}
    api_endpoint: https://${API_EP}
    credentials:
      admin:
        secret_name: cloud-manager-service-creds
        registration:
          name: 'cloud-manager'
          title: 'Cloud Manager'
          client_type: 'ibm_cloud'
          client_id: 'cloud-manager'
          state: 'enabled'
          scopes:
            - 'cloud:view'
            - 'cloud:manage'
            - 'provider-org:view'
            - 'provider-org:manage'
            - 'org:view'
            - 'org:manage'
            - 'my:view'
        username: admin
        password: "${CLOUD_MANAGER_PASS}"
      provider:
        secret_name: ${PROVIDER_SECRET_NAME}
    registry_settings:
      admin_user_registry_urls:
      - https://${API_EP}/api/user-registries/admin/cloud-manager-lur
      - https://${API_EP}/api/user-registries/admin/common-services
      provider_user_registry_urls:
      - https://${API_EP}/api/user-registries/admin/api-manager-lur
      - https://${API_EP}/api/user-registries/admin/common-services
    registrations:
      - registration:
          name: 'ace-v11'
          client_type: 'toolkit'
          client_id: 'ace-v11'
          client_secret: 'myclientid123'
        secret_name: ${ACE_REGISTRATION_SECRET_NAME}
    mail_servers:
      - title: "Default Mail Server"
        name: default-mail-server
        host: "${MAIL_SERVER_HOST}"
        port: ${MAIL_SERVER_PORT}
        # tls_client_profile_url: https://${API_EP}/api/orgs/admin/tls-client-profiles/tls-client-profile-default
    users:
      # cloud_manager:
      api-manager-lur:
        - user:
            username: cp4i-admin
            # configurator will generate a password if it is omitted
            password: "engageibmAPI1"
            first_name: CP4I
            last_name: Administrator
            email: ${PORG_ADMIN_EMAIL}
            # email: cp4i-admin@apiconnect.net
          secret_name: ${PROVIDER_SECRET_NAME}
    orgs:
      - org:
          name: ${ORG_NAME}
          title: Org for Demo use (${ORG_NAME})
          org_type: provider
          owner_url: https://${API_EP}/api/user-registries/admin/api-manager-lur/users/cp4i-admin
        members:
          - name: cs-admin
            user:
              identity_provider: common-services
              url: https://${API_EP}/api/user-registries/admin/common-services/users/admin
            role_urls:
              - https://${API_EP}/api/orgs/${ORG_NAME}/roles/administrator
        catalogs:
          - catalog:
              name: ${CATALOG_NAME}
              title: Catalog for Demo use (${CATALOG_NAME})
            settings:
              portal:
                type: drupal
                endpoint: https://${PTL_WEB_EP}/${ORG_NAME}/${CATALOG_NAME}
                portal_service_url: https://${API_EP}/api/orgs/${ORG_NAME}/portal-services/portal-service
      - org:
          name: ${ORG_NAME_DDD}
          title: Org for Demo use (${ORG_NAME_DDD})
          org_type: provider
          owner_url: https://${API_EP}/api/user-registries/admin/api-manager-lur/users/cp4i-admin
        members:
          - name: cs-admin
            user:
              identity_provider: common-services
              url: https://${API_EP}/api/user-registries/admin/common-services/users/admin
            role_urls:
              - https://${API_EP}/api/orgs/${ORG_NAME_DDD}/roles/administrator
        catalogs:
          - catalog:
              name: ${CATALOG_NAME_DDD}
              title: Catalog for Demo use (${CATALOG_NAME_DDD})
            settings:
              portal:
                type: drupal
                endpoint: https://${PTL_WEB_EP}/${ORG_NAME_DDD}/${CATALOG_NAME_DDD}
                portal_service_url: https://${API_EP}/api/orgs/${ORG_NAME_DDD}/portal-services/portal-service
    services: []
    mail_settings:
      mail_server_url: https://${API_EP}/api/orgs/admin/mail-servers/default-mail-server
      email_sender:
        name: "APIC Administrator"
        address: admin@apiconnect.net
    cloud_settings: {}
---
apiVersion: batch/v1
kind: Job
metadata:
  labels:
    app: apic-configurator-post-install
  namespace: ${NAMESPACE}
  name: ${RELEASE_NAME}-apic-configurator-post-install
spec:
  backoffLimit: 1
  template:
    metadata:
      labels:
        app: apic-configurator-post-install
    spec:
      serviceAccountName: ${RELEASE_NAME}-apic-configurator-post-install-sa
      restartPolicy: Never
      containers:
        - name: configurator
          image: ${CONFIGURATOR_IMAGE}
          volumeMounts:
            - name: configs
              mountPath: /app/configs
      volumes:
        - name: configs
          projected:
            sources:
            - configMap:
                name: ${RELEASE_NAME}-configurator-base
                items:
                  - key: configurator-base.yaml
                    path: overrides/configurator-base.yaml
            - secret:
                name: ${RELEASE_NAME}-default-mail-server-creds
                items:
                  - key: default-mail-server-creds.yaml
                    path: overrides/default-mail-server-creds.yaml
EOF

# wait for the job to complete
echo "Waiting for configurator job to complete"
kubectl wait --for=condition=complete --timeout=12000s -n $NAMESPACE job/${RELEASE_NAME}-apic-configurator-post-install

# pull together any necessary info from in-cluster resources
PROVIDER_CREDENTIALS=$(kubectl get secret $PROVIDER_SECRET_NAME -n $NAMESPACE -o json | jq .data)
ACE_CREDENTIALS=$(kubectl get secret $ACE_REGISTRATION_SECRET_NAME -n $NAMESPACE -o json | jq .data)

for i in $(seq 1 60); do
  PORTAL_WWW_POD=$(kubectl get pods -n $NAMESPACE | grep -m1 "${RELEASE_NAME}-ptl.*www" | awk '{print $1}')
  PORTAL_SITE_UUID=$(kubectl exec -n $NAMESPACE -it $PORTAL_WWW_POD -c admin -- /opt/ibm/bin/list_sites | awk '{print $1}')
  PORTAL_SITE_RESET_URL=$(kubectl exec -n $NAMESPACE -it $PORTAL_WWW_POD -c admin -- /opt/ibm/bin/site_login_link $PORTAL_SITE_UUID | tail -1)
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
