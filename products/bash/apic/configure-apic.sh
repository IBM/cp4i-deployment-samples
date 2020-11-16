#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

NAMESPACE="apic"                                                  # update to namespace where apic is installed
PORG_ADMIN_EMAIL=${PORG_ADMIN_EMAIL:-"cp4i-admin@apiconnect.net"} # update to recipient of portal site creation email
ACE_REGISTRATION_SECRET_NAME="ace-v11-service-creds"              # corresponds to registration obj currently hard-coded in configmap
PROVIDER_SECRET_NAME="cp4i-admin-creds"                           # corresponds to credentials obj currently hard-coded in configmap
CONFIGURATOR_IMAGE=${CONFIGURATOR_IMAGE:-"cp.icr.io/cp/apic/apic-configurator:dte-21"}
MAIL_SERVER_HOST=${MAIL_SERVER_HOST:-"smtp.mailtrap.io"}
MAIL_SERVER_PORT=${MAIL_SERVER_PORT:-"2525"}
MAIL_SERVER_USERNAME=${MAIL_SERVER_USERNAME:-"<your-username>"}
MAIL_SERVER_PASSWORD=${MAIL_SERVER_PASSWORD:-"<your-password>"}
# Directories
TEMPLATE_DIR=$DIR/template-apic-config-manifest
MANIFEST_DIR=$DIR/apic-config-manifest
mkdir -p $MANIFEST_DIR

echo "Waiting for OIDC registration job to complete..."
for i in $(seq 1 60); do
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

echo "Waiting for gateway pod to be ready..."
GATEWAY_POD=$(kubectl get pods | grep -m1 dynamic-gateway-service | awk '{print $1}')
kubectl wait --for=condition=ready pod --timeout=20m ${GATEWAY_POD}

echo "Pod listing for information"
kubectl get pod

# obtain endpoint info from APIC v2018 CR
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

# template config and manifests with namespace and endpoints
echo "Templating manifests"
sed "s#{{{ apim_namespace }}}#$NAMESPACE#g;
  s#{{{ porg_admin_email }}}#$PORG_ADMIN_EMAIL#g;
  s#{{{ api_endpoint }}}#$API_EP#g;
  s#{{{ portal_director_endpoint }}}#$PTL_DIR_EP#g;
  s#{{{ portal_web_endpoint }}}#$PTL_WEB_EP#g;
  s#{{{ analytics_client_endpoint }}}#$A7S_CLIENT_EP#g;
  s#{{{ api_gateway_endpoint }}}#$API_GW_EP#g;
  s#{{{ gateway_service_endpoint }}}#$GW_SVC_EP#g;
  s#{{{ mail_server_host }}}#$MAIL_SERVER_HOST#g;
  s#{{{ mail_server_port }}}#$MAIL_SERVER_PORT#g" $TEMPLATE_DIR/configmap.yaml >$MANIFEST_DIR/configmap.yaml
sed "s#{{{ mail_server_username }}}#$MAIL_SERVER_USERNAME#g;
  s#{{{ mail_server_password }}}#$MAIL_SERVER_PASSWORD#g" $TEMPLATE_DIR/default-mail-server-creds-secret.yaml >$MANIFEST_DIR/default-mail-server-creds-secret.yaml
sed "s#{{{ apim_namespace }}}#$NAMESPACE#g" $TEMPLATE_DIR/rbac.yaml >$MANIFEST_DIR/rbac.yaml
sed "s#{{{ configurator_image }}}#$CONFIGURATOR_IMAGE#g" $TEMPLATE_DIR/job.yaml >$MANIFEST_DIR/job.yaml
cp $TEMPLATE_DIR/serviceaccount.yaml $MANIFEST_DIR/serviceaccount.yaml

# create the k8s resources
echo "Applying manifests"
kubectl apply -f $MANIFEST_DIR/

# wait for the job to complete
echo "Waiting for configurator job to complete"
kubectl wait --for=condition=complete --timeout=300s job/apic-configurator

# pull together any necessary info from in-cluster resources
PROVIDER_CREDENTIALS=$(kubectl get secret $PROVIDER_SECRET_NAME -n $NAMESPACE -o json | jq .data)
ACE_CREDENTIALS=$(kubectl get secret $ACE_REGISTRATION_SECRET_NAME -n $NAMESPACE -o json | jq .data)

for i in $(seq 1 60); do
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
