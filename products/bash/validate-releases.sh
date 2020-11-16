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
#
# 3. To validate specific products, add them to the command line, e.g:
#       ./validate-releases.sh <console> mq-demo ace-demo

function usage() {
  echo "Usage: $0 <console> [products...]"
}

cp_console="$1"
cp_releases="${@:2}"

cp_username=${CP_USERNAME:-admin}
cp_password=${CP_PASSWORD}

if [[ -z "${cp_console}" ]]; then
  usage
  exit 2
fi
if [[ -z "${cp_releases}" ]]; then
  echo "No releases specified, validation complete."
  exit 1
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
curl -k -sS https://${cp_console}/api/cli/helm-${cp_client_platform}.tar.gz |
  tar xzf - -C bin --strip-components=1 ${cp_client_platform}/helm

chmod +x bin/*

# Initialise Helm
helm init --client-only

# Login to the cluster
if ! cloudctl login -a https://${cp_console} -u ${cp_username} -p "${cp_password}" -n default --skip-ssl-validation; then
  echo "Unable to login to the console as user '${cp_username}' with the given password" 1>&2
  exit 1
fi

function is_release_ready() {
  release_name=${1}
  release_status=$(helm status ${release_name} --tls -o json | jq -r '.info.status.code')

  if [ $release_status -eq 1 ]; then
    echo "${release_name} is released and ready!"
    return 1
  else
    return 0
  fi
}

# Retry for up to 20 minutes
startup_retries=60
retry_interval=20
retry_count=0
everything_ready=false

while [ ! $retry_count -eq $startup_retries ] && [ "$everything_ready" = false ]; do
  echo "Checking releases"
  everything_ready=true
  for release in $cp_releases; do
    if is_release_ready ${release}; then
      echo "${release} is not ready!"
      everything_ready=false
    fi
  done

  if [ "$everything_ready" = false ]; then
    sleep $retry_interval
    retry_count=$((retry_count + 1))
    echo "Releases not ready, retrying... ${retry_count} attempts out of ${startup_retries}."
  fi
done

if [ "$everything_ready" = false ]; then
  echo "Failed due to retries exceeded while waiting for releases..."
  exit 1
else
  echo "Everything successfully released!"
fi
