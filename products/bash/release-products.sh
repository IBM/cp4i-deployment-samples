#!/bin/bash
#
# INSTRUCTIONS
# ------------
#
# 1. Create a temporary directory and copy the script into it
#
# 2. Run the script, passing the Cloud Pak console address as argument:
#       ./release-products.sh icp-console.<your-cluster-domain>
#
# 3. It will use 'admin' to login to the console, and prompt for the password;
#    you can change the username or set the password in the environment:
#       export CP_USERNAME=<username>
#       export CP_PASSWORD=<password>
#
# 4. It will release all supported products by default;
#    to release specific products, add them to the command line, e.g:
#       ./release-products.sh <console> ace
#
# 5. Supported products are:
#    ace          App Connect Dashboard & App Connect Designer
#    apic         API Connect
#    assetrepo    Asset Repository
#    eventstreams Event Streams
#    mq           MQ
#
# 6. Products deploy in the background so may not be fully ready when the script
#    completes.
#

function usage {
    echo "Usage: $0 <console> [products...]"
}

cp_console="$1"
cp_products="${@:2}"

cp_username=${CP_USERNAME:-admin}
cp_password=${CP_PASSWORD}

if [[ -z "${cp_console}" ]]; then
    usage
    exit 2
fi
if [[ -z "${cp_products}" ]]; then
    cp_products="apic ace assetrepo eventstreams tracingmq"
fi
if [[ -z "${cp_password}" ]]; then
    read -p "Password (${cp_username}): " -s -r cp_password
    echo
fi
if [[ -z "${cp_password}" ]]; then
    echo "No password was provided for the '${cp_username}' user" 1>&2
    exit 1
fi

cp_client_platform=linux-amd64
if [[ $(uname) == Darwin ]]; then
    cp_client_platform=darwin-amd64
fi


# --- Init -------------------------------------------------------------

cd "$(dirname $0)"

mkdir -p auth bin helm

export HELM_HOME=${PWD}/helm
export KUBECONFIG=${PWD}/auth/kubeconfig
export PATH=${PWD}/bin:${PATH}

# Download client tools
echo "Downloading tools..."
curl -k -sS -o bin/kubectl https://${cp_console}/api/cli/kubectl-${cp_client_platform}
curl -k -sS -o bin/cloudctl https://${cp_console}/api/cli/cloudctl-${cp_client_platform}
curl -k -sS https://${cp_console}/api/cli/helm-${cp_client_platform}.tar.gz | \
    tar xzf - -C bin --strip-components=1 ${cp_client_platform}/helm

chmod +x bin/*

# Initialise Helm
helm init --client-only

# Login to the cluster
if ! cloudctl login -a https://${cp_console} -u ${cp_username} -p "${cp_password}" -n default --skip-ssl-validation; then
    echo "Unable to login to the console as user '${cp_username}' with the given password" 1>&2
    exit 1
fi

# Add the chart repo
chart_repo=ibm-entitled-charts
helm repo add ${chart_repo} https://raw.githubusercontent.com/IBM/charts/master/repo/entitled/


# --- ACE Dashboard ----------------------------------------------------

ace_dashboard_release_name=ace-dashboard-demo
ace_dashboard_namespace=ace
ace_dashboard_chart=ibm-ace-dashboard-icp4i-prod
ace_dashboard_helm_secret=ace-helm-secret
ace_dashboard_pull_secret=ibm-entitlement-key
ace_dashboard_storage_class=ibmc-file-gold
ace_dashboard_tracing=false

ace_dashboard_values="\
helmTlsSecret: ${ace_dashboard_helm_secret}
replicaCount: 1
image:
  pullSecret: ${ace_dashboard_pull_secret}
license: accept
odTracingConfig:
  enabled: ${ace_dashboard_tracing}
persistence:
  storageClassName: ${ace_dashboard_storage_class}
"

function release_ace_dashboard {
    echo "Releasing ACE Dashboard..."
    # Validate the environment
    if ! kubectl get ns ${ace_dashboard_namespace} > /dev/null 2>&1; then
        echo "There is no namespace '${ace_dashboard_namespace}'" 1>&2
        exit 1
    fi
    if ! kubectl get secret ${ace_dashboard_pull_secret} -n ${ace_dashboard_namespace} > /dev/null 2>&1; then
        echo "There is no '${ace_dashboard_pull_secret}' secret in namespace '${ace_dashboard_namespace}'" 1>&2
        exit 1
    fi
    # Create the Helm TLS key
    kubectl create secret generic ${ace_dashboard_helm_secret} -n ${ace_dashboard_namespace} --from-file=cert.pem=${HELM_HOME}/cert.pem --from-file=ca.pem=${HELM_HOME}/ca.pem --from-file=key.pem=${HELM_HOME}/key.pem
    # Create the Helm values file
    echo "${ace_dashboard_values}" > ace-dashboard-values.yaml
    # Create the release
    helm install ${chart_repo}/${ace_dashboard_chart} --name ${ace_dashboard_release_name} --namespace ${ace_dashboard_namespace} --values ace-dashboard-values.yaml --tls
}


# --- ACE Designer -----------------------------------------------------

ace_designer_release_name=ace-designer-demo
ace_designer_namespace=ace
ace_designer_chart=ibm-app-connect-designer-icp4i
ace_designer_pull_secret=ibm-entitlement-key
ace_designer_storage_class=ibmc-block-gold

ace_designer_values="\
couchdb:
  image:
    pullSecret: ${ace_designer_pull_secret}
  persistentVolume:
    storageClass: ${ace_designer_storage_class}
ibm-ace-server-dev:
  image:
    pullSecret: ${ace_designer_pull_secret}
image:
  pullSecret: ${ace_designer_pull_secret}
license: accept
"

function release_ace_designer {
    echo "Releasing ACE Designer..."
    # Validate the environment
    if ! kubectl get ns ${ace_designer_namespace} > /dev/null 2>&1; then
        echo "There is no namespace '${ace_designer_namespace}'" 1>&2
        exit 1
    fi
    if ! kubectl get secret ${ace_designer_pull_secret} -n ${ace_designer_namespace} > /dev/null 2>&1; then
        echo "There is no '${ace_designer_pull_secret}' secret in namespace '${ace_designer_namespace}'" 1>&2
        exit 1
    fi
    # Create the Helm values file
    echo "${ace_designer_values}" > ace-designer-values.yaml
    # Create the release
    helm install ${chart_repo}/${ace_designer_chart} --name ${ace_designer_release_name} --namespace ${ace_designer_namespace} --values ace-designer-values.yaml --tls
}


# --- APIC -------------------------------------------------------------

apic_release_name=apic-demo
apic_namespace=apic
apic_chart=ibm-apiconnect-icp4i-prod
apic_helm_secret=apic-helm-tls
apic_pull_secret=ibm-entitlement-key
apic_storage_class=ibmc-block-gold
apic_tracing=false

apic_endpoint_root=$(kubectl get configmap ibmcloud-cluster-info -n kube-public -o jsonpath='{.data.proxy_address}')

apic_values="\
analytics:
  analyticsClientEndpoint: ac.${apic_endpoint_root}
  analyticsIngestionEndpoint: ai.${apic_endpoint_root}
  enableMessageQueue: false
cassandra:
  cassandraClusterSize: 1
gateway:
  apiGatewayEndpoint: ag.${apic_endpoint_root}
  enableTms: true
  gatewayServiceEndpoint: gs.${apic_endpoint_root}
  highPerformancePeering: false
  odTracing:
    enabled: ${apic_tracing}
  replicaCount: 1
  v5CompatibilityMode: false
global:
  mode: dev
  registrySecret: ${apic_pull_secret}
  storageClass: ${apic_storage_class}
hubClusterRepo: true
license: accept
management:
  apiManagerUiEndpoint: mgmt.${apic_endpoint_root}
  cloudAdminUiEndpoint: mgmt.${apic_endpoint_root}
  consumerApiEndpoint: mgmt.${apic_endpoint_root}
  platformApiEndpoint: mgmt.${apic_endpoint_root}
operator:
  helmTlsSecret: ${apic_helm_secret}
  tiller:
    useNodePort: false
portal:
  portalDirectorEndpoint: pd.${apic_endpoint_root}
  portalWebEndpoint: pw.${apic_endpoint_root}
"

function release_apic {
    echo "Releasing API Connect..."
    # Validate the environment
    if ! kubectl get ns ${apic_namespace} > /dev/null 2>&1; then
        echo "There is no namespace '${apic_namespace}'" 1>&2
        exit 1
    fi
    if ! kubectl get secret ${apic_pull_secret} -n ${apic_namespace} > /dev/null 2>&1; then
        echo "There is no '${apic_pull_secret}' secret in namespace '${apic_namespace}'" 1>&2
        exit 1
    fi
    # Create the Helm TLS key
    kubectl create secret generic ${apic_helm_secret} -n ${apic_namespace} --from-file=cert.pem=${HELM_HOME}/cert.pem --from-file=ca.pem=${HELM_HOME}/ca.pem --from-file=key.pem=${HELM_HOME}/key.pem
    # Create the Helm values file
    echo "${apic_values}" > apic-values.yaml
    # Create the release
    helm install ${chart_repo}/${apic_chart} --name ${apic_release_name} --namespace ${apic_namespace} --values apic-values.yaml --tls
}


# --- Asset Repo -------------------------------------------------------

asset_repo_release_name=asset-repo-demo
asset_repo_namespace=assetrepo
asset_repo_chart=ibm-icp4i-asset-repo-prod
asset_repo_pull_secret=ibm-entitlement-key
asset_repo_block_storage_class=ibmc-block-gold
asset_repo_file_storage_class=ibmc-file-gold

asset_repo_values="\
assetSync:
  storageClassName: ${asset_repo_file_storage_class}
couchdb:
  persistentVolume:
    storageClass: ${asset_repo_block_storage_class}
global:
  images:
    pullSecret: ${asset_repo_pull_secret}
    pullPolicy: Always
license: accept
selectedCluster:
- ip: ${cp_console}
  label: local-cluster
  namespace: local-cluster
  value: local-cluster
"

function release_asset_repo {
    echo "Releasing Asset Repo..."
    # Validate the environment
    if ! kubectl get ns ${asset_repo_namespace} > /dev/null 2>&1; then
      echo "There is no namespace '${asset_repo_namespace}'" 1>&2
      exit 1
    fi
    if ! kubectl get secret ${asset_repo_pull_secret} -n ${asset_repo_namespace} > /dev/null 2>&1; then
      echo "There is no '${asset_repo_pull_secret}' secret in namespace '${asset_repo_namespace}'" 1>&2
      exit 1
    fi
    # Create the Helm values file
    echo "${asset_repo_values}" > asset-repo-values.yaml
    # Create the release
    helm install ${chart_repo}/${asset_repo_chart} --name ${asset_repo_release_name} --namespace ${asset_repo_namespace} --values asset-repo-values.yaml --tls
}

# --- Event Streams ----------------------------------------------------

event_streams_release_name=event-streams-demo
event_streams_namespace=eventstreams
event_streams_chart=ibm-eventstreams-icp4i-prod
event_streams_pull_secret=ibm-entitlement-key
navigator_namespace=integration

event_streams_values="\
license: accept
global:
  production: true
  supportingProgram: false
  image:
    pullSecret: ${event_streams_pull_secret}
    pullPolicy: Always
  generateClusterRoles: false
kafka:
  openJMX: false
selectedCluster:
  - label: local-cluster
    value: local-cluster
    ip: ${cp_console}
    namespace: local-cluster
telemetry:
  enabled: false
persistence:
  enabled: false
  useDynamicProvisioning: false
replicator:
  replicas: 0
proxy:
  upgradeToRoutes: false
  externalEndpoint: ${cp_console}
zookeeper:
  persistence:
    enabled: false
    useDynamicProvisioning: false
schema-registry:
  replicas: 0
  persistence:
    enabled: false
    useDynamicProvisioning: false
icp4i:
  icp4iPlatformNamespace: ${navigator_namespace}
"

function release_event_streams {
    echo "Releasing Event Streams..."
    # Validate the environment
    if ! kubectl get ns ${event_streams_namespace} > /dev/null 2>&1; then
      echo "There is no namespace '${event_streams_namespace}'" 1>&2
      exit 1
    fi
    if ! kubectl get secret ${event_streams_pull_secret} -n ${event_streams_namespace} > /dev/null 2>&1; then
      echo "There is no '${event_streams_pull_secret}' secret in namespace '${event_streams_namespace}'" 1>&2
      exit 1
    fi
    # Create the Helm values file
    echo "${event_streams_values}" > event-streams-values.yaml
    # Create the release
    helm install ${chart_repo}/${event_streams_chart} --name ${event_streams_release_name} --namespace ${event_streams_namespace} --values event-streams-values.yaml --tls
}

# --- MQ ---------------------------------------------------------------

mq_release_name=mq-demo
mq_namespace=mq
mq_chart=ibm-mqadvanced-server-integration-prod
mq_pull_secret=ibm-entitlement-key

mq_values="\
license: accept
image:
  pullSecret: ${mq_pull_secret}
log:
  debug: false
qmPVC:
  enabled: false
logPVC:
  enabled: false
tls:
  hostname: ${cp_console}
trace:
  strmqm: false
selectedCluster:
  - label: local-cluster
    value: local-cluster
    ip: ${cp_console}
    namespace: local-cluster
queueManager:
  multiInstance: false
odTracingConfig:
  enabled: false
"

function release_mq {
    echo "Releasing MQ..."
    # Validate the environment
    if ! kubectl get ns ${mq_namespace} > /dev/null 2>&1; then
      echo "There is no namespace '${mq_namespace}'" 1>&2
      exit 1
    fi
    if ! kubectl get secret ${mq_pull_secret} -n ${mq_namespace} > /dev/null 2>&1; then
      echo "There is no '${mq_pull_secret}' secret in namespace '${mq_namespace}'" 1>&2
      exit 1
    fi
    # Create the Helm values file
    echo "${mq_values}" > mq-values.yaml
    # Create the release
    helm install ${chart_repo}/${mq_chart} --name ${mq_release_name} --namespace ${mq_namespace} --values mq-values.yaml --tls
}

# --- Tracing ----------------------------------------------------------

tracing_release_name=tracing-demo
tracing_namespace=tracing
tracing_chart=ibm-icp4i-tracing-prod
tracing_pull_secret=ibm-entitlement-key
tracing_storage=ibmc-block-gold
navigator_namespace=integration
proxyHost=${cp_console/icp-console/icp-proxy}
navigatorHost=${cp_console/icp-console/navigator-integration}

tracing_values="\
configdb:
  storageClassName: ${tracing_storage}
elasticsearch:
  volumeClaimTemplate:
    storageClassName: ${tracing_storage}
global:
  images:
    pullSecret: ${tracing_pull_secret}
    pullPolicy: Always
ingress:
  odUiHost: ${proxyHost}
license: accept
platformNavigatorHost: ${navigatorHost}
selectedCluster:
- ip: ${cp_console}
  label: local-cluster
  namespace: local-cluster
  value: local-cluster
"

function release_tracing {
    echo "Releasing Operations Dashboard..."
    # Validate the environment
    if ! kubectl get ns ${tracing_namespace} > /dev/null 2>&1; then
      echo "There is no namespace '${tracing_namespace}'" 1>&2
      exit 1
    fi
    if ! kubectl get secret ${tracing_pull_secret} -n ${tracing_namespace} > /dev/null 2>&1; then
      echo "There is no '${tracing_pull_secret}' secret in namespace '${tracing_namespace}'" 1>&2
      exit 1
    fi
    # Create the Helm values file
    echo "${tracing_values}" > tracing-values.yaml
    # Create the release
    helm install ${chart_repo}/${tracing_chart} --name ${tracing_release_name} --namespace ${tracing_namespace} --values tracing-values.yaml --tls
}

# ----------------------------------------------------------------------

for product in $cp_products; do
    case $product in
        ace)
            release_ace_dashboard
            release_ace_designer
            ;;
        apic)
            release_apic
            ;;
        assetrepo)
            release_asset_repo
            ;;
        eventstreams)
            release_event_streams
            ;;
        mq)
            release_mq
        tracing)
            release_tracing
            ;;
        *)
            echo "Unknown product: ${product}"
            ;;
    esac
done

cloudctl logout
