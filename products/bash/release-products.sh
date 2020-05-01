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
#    ace    App Connect Dashboard & App Connect Designer
#    apic   API Connect
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
    cp_products="ace apic"
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
        echo "There is no '${ace_dashboard_pull_secret}' in namespace '${ace_dashboard_namespace}'" 1>&2
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
        echo "There is no '${ace_designer_pull_secret}' in namespace '${ace_designer_namespace}'" 1>&2
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
        echo "There is no '${apic_pull_secret}' in namespace '${apic_namespace}'" 1>&2
        exit 1
    fi
    # Create the Helm TLS key
    kubectl create secret generic ${apic_helm_secret} -n ${apic_namespace} --from-file=cert.pem=${HELM_HOME}/cert.pem --from-file=ca.pem=${HELM_HOME}/ca.pem --from-file=key.pem=${HELM_HOME}/key.pem
    # Create the Helm values file
    echo "${apic_values}" > apic-values.yaml
    # Create the release
    helm install ${chart_repo}/${apic_chart} --name ${apic_release_name} --namespace ${apic_namespace} --values apic-values.yaml --tls
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
        *)
            echo "Unknown product: ${product}"
            ;;
    esac
done

cloudctl logout