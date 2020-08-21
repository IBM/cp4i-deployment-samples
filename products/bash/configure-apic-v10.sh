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
# PREREQUISITES:
#   - Logged into cluster on the OC CLI (https://docs.openshift.com/container-platform/4.4/cli_reference/openshift_cli/getting-started-cli.html)
#
# PARAMETERS:
#   -n : <namespace> (string), Defaults to "cp4i"
#   -r : <release-name> (string), Defaults to "ademo"
#
# USAGE:
#   With defaults values
#     ./configure-apic-v10.sh
#
#   Overriding the namespace and release-name
#     ./configure-apic-v10 -n cp4i-prod -r prod

function usage {
    echo "Usage: $0 -n <namespace> -r <release-name>"
}

CURRENT_DIR=$(dirname $0)

namespace="cp4i"
release_name="ademo"

while getopts "n:r:" opt; do
  case ${opt} in
    n ) namespace="$OPTARG"
      ;;
    r ) release_name="$OPTARG"
      ;;
    \? ) usage; exit
      ;;
  esac
done

set -e

NAMESPACE="${namespace}"
PORG_ADMIN_EMAIL=${PORG_ADMIN_EMAIL:-"cp4i-admin@apiconnect.net"} # update to recipient of portal site creation email
ACE_REGISTRATION_SECRET_NAME="ace-v11-service-creds" # corresponds to registration obj currently hard-coded in configmap
PROVIDER_SECRET_NAME="cp4i-admin-creds" # corresponds to credentials obj currently hard-coded in configmap
CONFIGURATOR_IMAGE=${CONFIGURATOR_IMAGE:-"cp.icr.io/cp/apic/ibm-apiconnect-apiconnect-configurator:10.0.0.0-ifix1.0"}
MAIL_SERVER_HOST=${MAIL_SERVER_HOST:-"smtp.mailtrap.io"}
MAIL_SERVER_PORT=${MAIL_SERVER_PORT:-"2525"}
MAIL_SERVER_USERNAME=${MAIL_SERVER_USERNAME:-"<your-username>"}
MAIL_SERVER_PASSWORD=${MAIL_SERVER_PASSWORD:-"<your-password>"}

echo "Waiting for APIC installation to complete..."
for i in `seq 1 60`; do
  APIC_STATUS=$(kubectl get apiconnectcluster.apiconnect.ibm.com -n $NAMESPACE ${release_name} -o jsonpath='{.status.phase}')
  if [ "$APIC_STATUS" == "Ready" ]; then
    echo "[OK] APIC is ready"
    break
  else
    echo "Waiting for APIC install to complete (Attempt $i of 60). Status: $APIC_STATUS"

    ${CURRENT_DIR}/fix-cs-dependencies.sh

    kubectl get apic,pods -n $NAMESPACE
    echo "Checking again in one minute..."
    sleep 60
  fi
done

if [ "$APIC_STATUS" != "Ready" ]; then
  echo "[ERROR] APIC failed to install"
  exit 1
fi

for i in `seq 1 60`; do
  PORTAL_WWW_POD=$(oc get pods -n $NAMESPACE | grep -m1 "${release_name}-ptl.*www" | awk '{print $1}')
  if [ -z "$PORTAL_WWW_POD" ]; then
    echo "Not got portal pod yet"
  else
    PORTAL_WWW_ADMIN_READY=$(oc get pod -n ${NAMESPACE} ${PORTAL_WWW_POD} -o json | jq '.status.containerStatuses[0].ready')
    if [[ "$PORTAL_WWW_ADMIN_READY" == "true" ]]; then
      echo "PORTAL_WWW_POD (${PORTAL_WWW_POD}) ready, patching..."
      oc exec -n ${NAMESPACE} ${PORTAL_WWW_POD} -c admin -- bash -ic "sed -i '/^add_uuid_and_alias/a drush \"@\$SITE_ALIAS\" pm-list --type=Module --status=enabled' /opt/ibm/bin/restore_site"
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
CLOUD_MANAGER_PASS="$(oc get secret -n $NAMESPACE "${release_name}-mgmt-admin-pass" -o jsonpath='{.data.password}' | base64 --decode)"

# obtain endpoint info from APIC v10 routes
APIM_UI_EP=$(oc get route -n $NAMESPACE ${release_name}-mgmt-api-manager -o jsonpath='{.spec.host}')
CMC_UI_EP=$(oc get route -n $NAMESPACE ${release_name}-mgmt-admin -o jsonpath='{.spec.host}')
C_API_EP=$(oc get route -n $NAMESPACE ${release_name}-mgmt-consumer-api -o jsonpath='{.spec.host}')
API_EP=$(oc get route -n $NAMESPACE ${release_name}-mgmt-platform-api -o jsonpath='{.spec.host}')
PTL_WEB_EP=$(oc get route -n $NAMESPACE ${release_name}-ptl-portal-web -o jsonpath='{.spec.host}')

# create the k8s resources
echo "Applying manifests"
cat << EOF | oc apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  namespace: ${NAMESPACE}
  name: ${release_name}-apic-configurator-post-install-sa
imagePullSecrets:
- name: ibm-entitlement-key
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: ${NAMESPACE}
  name: ${release_name}-apic-configurator-post-install-role
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
  name: ${release_name}-apic-configurator-post-install-rolebinding
subjects:
- kind: ServiceAccount
  name: ${release_name}-apic-configurator-post-install-sa
  namespace: ${NAMESPACE}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: ${release_name}-apic-configurator-post-install-role
---
apiVersion: v1
kind: Secret
metadata:
  namespace: ${NAMESPACE}
  name: ${release_name}-default-mail-server-creds
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
  name: ${release_name}-configurator-base
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
          name: demoorg
          title: Org for Demo use
          org_type: provider
          owner_url: https://${API_EP}/api/user-registries/admin/api-manager-lur/users/cp4i-admin
        members:
          - name: cs-admin
            user:
              identity_provider: common-services
              url: https://${API_EP}/api/user-registries/admin/common-services/users/admin
            role_urls:
              - https://${API_EP}/api/orgs/demoorg/roles/administrator
        catalogs:
          - catalog:
              name: democatalog
              title: Catalog for Demo use
            settings:
              portal:
                type: drupal
                endpoint: https://${PTL_WEB_EP}/demoorg/democatalog
                portal_service_url: https://${API_EP}/api/orgs/demoorg/portal-services/portal-service
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
  name: ${release_name}-apic-configurator-post-install
spec:
  backoffLimit: 1
  template:
    metadata:
      labels:
        app: apic-configurator-post-install
    spec:
      serviceAccountName: ${release_name}-apic-configurator-post-install-sa
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
                name: ${release_name}-configurator-base
                items:
                  - key: configurator-base.yaml
                    path: overrides/configurator-base.yaml
            - secret:
                name: ${release_name}-default-mail-server-creds
                items:
                  - key: default-mail-server-creds.yaml
                    path: overrides/default-mail-server-creds.yaml
EOF

# wait for the job to complete
echo "Waiting for configurator job to complete"
kubectl wait --for=condition=complete --timeout=300s -n $NAMESPACE job/${release_name}-apic-configurator-post-install

# pull together any necessary info from in-cluster resources
PROVIDER_CREDENTIALS=$(kubectl get secret $PROVIDER_SECRET_NAME -n $NAMESPACE -o json | jq .data)
ACE_CREDENTIALS=$(kubectl get secret $ACE_REGISTRATION_SECRET_NAME -n $NAMESPACE -o json | jq .data)

for i in `seq 1 60`; do
  PORTAL_WWW_POD=$(kubectl get pods -n $NAMESPACE | grep -m1 "${release_name}-ptl.*www" | awk '{print $1}')
  PORTAL_SITE_UUID=$(kubectl exec -n $NAMESPACE -it $PORTAL_WWW_POD -c admin /opt/ibm/bin/list_sites | awk '{print $1}')
  PORTAL_SITE_RESET_URL=$(kubectl exec -n $NAMESPACE -it $PORTAL_WWW_POD -c admin /opt/ibm/bin/site_login_link $PORTAL_SITE_UUID | tail -1)
  if [[ "$PORTAL_SITE_RESET_URL" =~ "https://$PTL_WEB_EP" ]]; then
    echo "[OK] Got the portal_site_password_reset_link"
    break
  else
    echo "Waiting for the portal_site_password_reset_link to be available (Attempt $i of 60)."
    echo "Checking again in one minute..."
    sleep 60
  fi
done

echo "
********** Configuration **********
api_manager_ui: https://$APIM_UI_EP/manager
cloud_manager_ui: https://$CMC_UI_EP/admin
platform_api: https://$API_EP/api
consumer_api: https://$C_API_EP/consumer-api

provider_credentials (api manager):
  username: $(echo $PROVIDER_CREDENTIALS | jq -r .username | base64 --decode)
  password: $(echo $PROVIDER_CREDENTIALS | jq -r .password | base64 --decode)

portal_site_password_reset_link: $PORTAL_SITE_RESET_URL

ace_registration:
  client_id: $(echo $ACE_CREDENTIALS | jq -r .client_id | base64 --decode)
  client_secret: $(echo $ACE_CREDENTIALS | jq -r .client_secret | base64 --decode)
"
