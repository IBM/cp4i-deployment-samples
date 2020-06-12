#!/bin/bash
#******************************************************************************
# Licensed Materials - Property of IBM
# (c) Copyright IBM Corporation 2020. All Rights Reserved.
#
# Note to U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.
#******************************************************************************
#
# INSTRUCTIONS
# ------------
#
# 1. Run the script, passing the Cloud Pak console address as argument:
#       ./validate-releases.sh icp-console.<your-cluster-domain>
#
# 2. It will use 'admin' to login to the console, and prompt for the password;
#    you can change the username or set the password in the environment:
#       export CP_USERNAME=<username>
#       export CP_PASSWORD=<password>
#
# 3. You can specify release names for each product using the environment variables:
#       export ACE_DASHBOARD_RELEASE_NAME=<ace-dashboard-release-name>
#       export ACE_DESIGNER_RELEASE_NAME=<ace-designer-release-name>
#       export APIC_RELEASE_NAME=<apic-release-name>
#       export ASSET_REPO_RELEASE_NAME=<asset-repo-release-name>
#       export EVENT_STREAMS_RELEASE_NAME=<event-streams-release-name>
#       export MQ_RELEASE_NAME=<mq-release-name>
#       export TRACING_RELEASE_NAME=<tracing-release-name>
#
# 4. It will release all supported products by default;
#    to release specific products, add them to the command line, e.g:
#       ./validate-releases.sh <console> ace
#
# 5. Supported products are:
#    ace          App Connect Dashboard & App Connect Designer
#    apic         API Connect
#    assetrepo    Asset Repository
#    eventstreams Event Streams
#    mq           MQ

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
    cp_products="apic ace assetrepo eventstreams tracing mq"
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

function is_release_ready {
  release_name=${1}
  release_status=$(helm status ${release_name} --tls -o json | jq -r '.info.status.code')

  if [ $release_status -eq 1 ]; then
    echo "${release_name} is released and ready!"
    return 1
  else
    return 0
  fi
}

startup_retries=30  
retry_interval=20
retry_count=0
everything_ready=false

while [ ! $retry_count -eq $startup_retries ] && [ "$everything_ready" = false ]; do
  echo "Checking releases"
  everything_ready=true
  for product in $cp_products; do
    case $product in
        ace)
            if is_release_ready ${ace_designer_release_name}; then
              echo "${ace_designer_release_name} is not ready!"
              everything_ready=false
            fi
            if is_release_ready ${ace_dashboard_release_name}; then
              echo "${ace_dashboard_release_name} is not ready!"
              everything_ready=false
            fi
            ;;
        apic)
            if is_release_ready ${apic_release_name}; then
              echo "${apic_release_name} is not ready!"
              everything_ready=false
            fi
            ;;
        assetrepo)
            if is_release_ready ${asset_repo_release_name}; then
              echo "${asset_repo_release_name} is not ready!"
              everything_ready=false
            fi
            ;;
        eventstreams)
            if is_release_ready ${event_streams_release_name}; then
              echo "${event_streams_release_name} is not ready!"
              everything_ready=false
            fi
            ;;
        mq)
            if is_release_ready ${mq_release_name}; then
              echo "${mq_release_name} is not ready!"
              everything_ready=false
            fi
            ;;
        tracing)
            if is_release_ready ${tracing_release_name}; then
              echo "${tracing_release_name} is not ready!"
              everything_ready=false
            fi
            ;; 
        *)
            echo "Unknown product: ${product}"
            ;;
    esac
  done

  if [ "$everything_ready" = false ]; then
    sleep $retry_interval
    retry_count=$((retry_count+1))
    echo "Releases not ready, retrying... ${retry_count} attempts out of ${startup_retries}."
  fi
done

if [ "$everything_ready" = false ]; then
  echo "Failed due to retries exceeded while waiting for releases..."
  exit 1
else
  echo "Capabilities succesfully released!"
fi