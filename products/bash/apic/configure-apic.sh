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
#   -n : <namespace> (string), Defaults to "apic"
#   -o : (boolean) indicates operators, defaults to false for helm
#   -r : <release-name> (string), Defaults to "demo", only used when operators=true
#
# USAGE:
#   With defaults values
#     ./release-apic.sh
#
#   Overriding the namespace and release-name
#     ./release-apic -n cp4i-prod -r prod

function usage {
    echo "Usage: $0 -n <namespace> -r <release-name> -o"
}

NAMESPACE="apic"
RELEASE_NAME="demo"
OPERATORS=false

while getopts "n:r:o" opt; do
  case ${opt} in
    n ) NAMESPACE="$OPTARG"
      ;;
    r ) RELEASE_NAME="$OPTARG"
      ;;
		o ) OPERATORS=true
      ;;
    \? ) usage; exit
      ;;
  esac
done

set -e

ACE_REGISTRATION_SECRET_NAME="apic-ace-creds-${RELEASE_NAME}"
PROVIDER_SECRET_NAME="apic-admin-creds-${RELEASE_NAME}"
CONFIGURATOR_IMAGE=${CONFIGURATOR_IMAGE:-"cp.icr.io/cp/apic/apic-configurator:dte-21"}
PORG_ADMIN_EMAIL=${PORG_ADMIN_EMAIL:-"cp4i-admin@apiconnect.net"} # update to recipient of portal site creation email
MAIL_SERVER_HOST=${MAIL_SERVER_HOST:-"smtp.mailtrap.io"}
MAIL_SERVER_PORT=${MAIL_SERVER_PORT:-"2525"}
MAIL_SERVER_USERNAME=${MAIL_SERVER_USERNAME:-"<your-username>"}
MAIL_SERVER_PASSWORD=${MAIL_SERVER_PASSWORD:-"<your-password>"}

if [ "$OPERATORS" == "false" ]; then
	# TODO Maybe just wait for the CR to be ready for operators? I.e.:
	# $ oc get APIConnectCluster
	# NAME   READY   STATUS   VERSION    RECONCILED VERSION   AGE
	# demo   6/6     Ready    10.0.0.0   10.0.0.0-ifix1-771   6d20h
	echo "Waiting for OIDC registration job to complete..."
	for i in `seq 1 60`; do
		OIDC_JOB_STATUS=$(kubectl get pods | grep -m1 register-oidc | awk '{print $3}')
		if [ "$OIDC_JOB_STATUS" == "Completed" ]; then
			echo "[OK] OIDC registration job is complete."
			break
		else
			echo "Waiting for OIDC registration job to complete (Attempt $i of 60). Job status: $OIDC_JOB_STATUS"
			kubectl get pods,jobs
			echo "Checking again in one minute..."
			sleep 60
		fi
	done

	# Looks like this has changed, maybe CR wait enough for operators?
	echo "Waiting for gateway pod to be ready..."
	GATEWAY_POD=$(kubectl get pods | grep -m1 dynamic-gateway-service | awk '{print $1}')
	kubectl wait --for=condition=ready pod --timeout=20m ${GATEWAY_POD}
fi

echo "Pod listing for information"
kubectl get pod

# obtain endpoint info from APIC v2018 CR
if [ "$OPERATORS" == "false" ]; then
	ENDPOINTS=$(kubectl get apiconnectclusters -n $NAMESPACE -o json | jq -r '.items[0].spec.subsystems[].spec.endpoints' | jq -s 'add')
	APIM_UI_EP=$(echo $ENDPOINTS | jq -r '.["api-manager-ui"]')
	CMC_UI_EP=$(echo $ENDPOINTS | jq -r '.["cloud-admin-ui"]')
	C_API_EP=$(echo $ENDPOINTS | jq -r '.["consumer-api"]')
	API_EP=$(echo $ENDPOINTS | jq -r '.["platform-api"]')
	PTL_DIR_EP=$(echo $ENDPOINTS | jq -r '.["portal-admin"]')
	PTL_WEB_EP=$(echo $ENDPOINTS | jq -r '.["portal-www"]')
	A7S_CLIENT_EP=$(echo $ENDPOINTS | jq -r '.["analytics-client"]')
	API_GW_EP=$(echo $ENDPOINTS | jq -r '.["api-gateway"]')
	GW_SVC_EP=$(echo $ENDPOINTS | jq -r '.["apic-gw-service"]')
else
	ENDPOINTS=$(kubectl get apiconnectclusters -n $NAMESPACE $RELEASE_NAME -o json | jq -r '.status.endpoints')

	# Old
	# {
	#   "api-manager-ui": "mgmt.icp-proxy.dan-ddd-ec111ed5d7db435e1c5eeeb4400d693f-0000.eu-gb.containers.appdomain.cloud",
	#   "cloud-admin-ui": "mgmt.icp-proxy.dan-ddd-ec111ed5d7db435e1c5eeeb4400d693f-0000.eu-gb.containers.appdomain.cloud",
	#   "consumer-api": "mgmt.icp-proxy.dan-ddd-ec111ed5d7db435e1c5eeeb4400d693f-0000.eu-gb.containers.appdomain.cloud",
	#   "platform-api": "mgmt.icp-proxy.dan-ddd-ec111ed5d7db435e1c5eeeb4400d693f-0000.eu-gb.containers.appdomain.cloud",
	#   "portal-admin": "pd.icp-proxy.dan-ddd-ec111ed5d7db435e1c5eeeb4400d693f-0000.eu-gb.containers.appdomain.cloud",
	#   "portal-www": "pw.icp-proxy.dan-ddd-ec111ed5d7db435e1c5eeeb4400d693f-0000.eu-gb.containers.appdomain.cloud",
	#   "analytics-client": "ac.icp-proxy.dan-ddd-ec111ed5d7db435e1c5eeeb4400d693f-0000.eu-gb.containers.appdomain.cloud",
	#   "analytics-ingestion": "ai.icp-proxy.dan-ddd-ec111ed5d7db435e1c5eeeb4400d693f-0000.eu-gb.containers.appdomain.cloud",
	#   "api-gateway": "ag.icp-proxy.dan-ddd-ec111ed5d7db435e1c5eeeb4400d693f-0000.eu-gb.containers.appdomain.cloud",
	#   "apic-gw-service": "gs.icp-proxy.dan-ddd-ec111ed5d7db435e1c5eeeb4400d693f-0000.eu-gb.containers.appdomain.cloud"
	# }

	# New
	# "endpoints": [
	# 		{
	# 				"name": "admin",
	# 				"type": "UI",
	# 				"uri": "https://demo-mgmt-admin-cp4i.dan-operators-3-42614f8458e453e35d683b2db59b7b05-0000.eu-gb.stg.containers.appdomain.cloud/admin"
	# 		},
	# 		{
	# 				"name": "ui",
	# 				"type": "UI",
	# 				"uri": "https://demo-mgmt-api-manager-cp4i.dan-operators-3-42614f8458e453e35d683b2db59b7b05-0000.eu-gb.stg.containers.appdomain.cloud/manager"
	# 		},
	# 		{
	# 				"name": "platformApi",
	# 				"type": "API",
	# 				"uri": "https://demo-mgmt-platform-api-cp4i.dan-operators-3-42614f8458e453e35d683b2db59b7b05-0000.eu-gb.stg.containers.appdomain.cloud/"
	# 		},
	# 		{
	# 				"name": "consumerApi",
	# 				"type": "API",
	# 				"uri": "https://demo-mgmt-consumer-api-cp4i.dan-operators-3-42614f8458e453e35d683b2db59b7b05-0000.eu-gb.stg.containers.appdomain.cloud/"
	# 		}
	# ],

	APIM_UI_EP=$(echo $ENDPOINTS | jq -r '.["api-manager-ui"]')
	CMC_UI_EP=$(echo $ENDPOINTS | jq -r '.["cloud-admin-ui"]')
	C_API_EP=$(echo $ENDPOINTS | jq -r '.["consumer-api"]')
	# API_EP=$(echo $ENDPOINTS | jq -r '.["platform-api"]')
	API_EP=$(echo $ENDPOINTS | jq '.[] | select(.name == "platformApi") .url')
	PTL_DIR_EP=$(echo $ENDPOINTS | jq -r '.["portal-admin"]')
	PTL_WEB_EP=$(echo $ENDPOINTS | jq -r '.["portal-www"]')
	A7S_CLIENT_EP=$(echo $ENDPOINTS | jq -r '.["analytics-client"]')
	API_GW_EP=$(echo $ENDPOINTS | jq -r '.["api-gateway"]')
	GW_SVC_EP=$(echo $ENDPOINTS | jq -r '.["apic-gw-service"]')


fi

echo "Applying manifests"
# TODO Make this work with multiple releases in a namespace?
cat << EOF | oc apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
	namespace: ${NAMESPACE}
  name: apic-configurator-sa
imagePullSecrets:
- name: configurator-pull-secret
- name: cp.stg.icr.io
- name: ibm-entitlement-key
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
	namespace: ${NAMESPACE}
  name: apic-configurator-role
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
  name: apic-configurator-rolebinding
subjects:
- kind: ServiceAccount
  name: apic-configurator-sa
  namespace: ${NAMESPACE}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: apic-configurator-role
---
apiVersion: v1
kind: ConfigMap
metadata:
	namespace: ${NAMESPACE}
  name: configurator-base-${RELEASE_NAME}
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
      api_manager:
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
          - name: admin
            user:
              identity_provider: ibm-common-services
              url: https://${API_EP}/api/user-registries/admin/ibm-common-services/users/admin
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
                portal_service_url: https://${API_EP}/api/orgs/demoorg/portal-services/portal-service1
    services:
      portal:
        - name: portal-service1
          title: portal-service1
          endpoint: https://${PTL_DIR_EP}
          web_endpoint_base: https://${PTL_WEB_EP}
      analytics:
        - name: analytics-service1
          title: analytics-service1
          endpoint: https://${A7S_CLIENT_EP}
      gateway:
        - name: api-gateway-service1
          title: api-gateway-service1
          gateway_service_type: datapower-api-gateway
          integration_url: https://${API_EP}/api/cloud/integrations/gateway-service/datapower-api-gateway
          visibility:
            type: public
          tls_client_profile_url: https://${API_EP}/api/orgs/admin/tls-client-profiles/tls-client-profile-default
          endpoint: https://${GW_SVC_EP}
          api_endpoint_base: https://${API_GW_EP}
          sni:
            - host: '*'
              tls_server_profile_url: https://${API_EP}/api/orgs/admin/tls-server-profiles/tls-server-profile-default
          analytics_service_url: https://${API_EP}/api/orgs/admin/availability-zones/availability-zone-default/analytics-services/analytics-service1
    mail_settings:
      mail_server_url: https://${API_EP}/api/orgs/admin/mail-servers/default-mail-server
      email_sender:
        name: "APIC Administrator"
        address: admin@apiconnect.net
    cloud_settings:
      gateway_service_default_urls:
        - https://${API_EP}/api/orgs/admin/availability-zones/availability-zone-default/gateway-services/api-gateway-service1
---
apiVersion: v1
kind: Secret
metadata:
	namespace: ${NAMESPACE}
  name: default-mail-server-creds-${RELEASE_NAME}
type: Opaque
stringData:
  default-mail-server-creds.yaml: |-
    mail_servers:
      - name: default-mail-server
        credentials:
          username: "{{{ mail_server_username }}}"
          password: "${MAIL_SERVER_PASSWORD}"
---
apiVersion: batch/v1
kind: Job
metadata:
  labels:
    app: apic-configurator
	namespace: ${NAMESPACE}
  name: apic-configurator-${RELEASE_NAME}
spec:
  backoffLimit: 1
  template:
    metadata:
      labels:
        app: apic-configurator
    spec:
      serviceAccountName: apic-configurator-sa
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
                name: configurator-base-${RELEASE_NAME}
                items:
                  - key: configurator-base.yaml
                    path: overrides/configurator-base.yaml
            - secret:
                name: default-mail-server-creds-${RELEASE_NAME}
                items:
                  - key: default-mail-server-creds.yaml
                    path: overrides/default-mail-server-creds.yaml
EOF




# wait for the job to complete
echo "Waiting for configurator job to complete"
kubectl wait --for=condition=complete --timeout=300s job/apic-configurator-${RELEASE_NAME}

# pull together any necessary info from in-cluster resources
PROVIDER_CREDENTIALS=$(kubectl get secret $PROVIDER_SECRET_NAME -n $NAMESPACE -o json | jq .data)
ACE_CREDENTIALS=$(kubectl get secret $ACE_REGISTRATION_SECRET_NAME -n $NAMESPACE -o json | jq .data)

for i in `seq 1 60`; do
	PORTAL_WWW_POD=$(kubectl get pods | grep -m1 portal-www | awk '{print $1}')
	PORTAL_SITE_UUID=$(kubectl exec -it $PORTAL_WWW_POD -c admin /opt/ibm/bin/list_sites | awk '{print $1}')
  PORTAL_SITE_RESET_URL=$(kubectl exec -it $PORTAL_WWW_POD -c admin /opt/ibm/bin/site_login_link $PORTAL_SITE_UUID | tail -1)
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
