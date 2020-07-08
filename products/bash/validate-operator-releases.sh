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
# To validate specific products, add the flag for your product, followed by the release name to the command line, e.g:
#       ./validate-operator-releases.sh -m mq-demo -d ace-dashboard-demo -m mq-dev-demo
#
# Full parameter list:
#   -n : CP4I Platform Navigator
#   -m : MQ Queue Manager
#   -d : ACE Dashboard
#   -e : ACE Designer
#   -r : CP4I Asset Repository

function usage {
    echo "Usage: $0 [products...]"
}

cp_releases=()

while getopts "n:m:d:e:r:" opt; do
  case ${opt} in
    n ) cp_releases+=("$OPTARG^PlatformNavigator")
      ;;
    m ) cp_releases+=("$OPTARG^QueueManager")
      ;;
    d ) cp_releases+=("$OPTARG^Dashboard")
      ;;
    e ) cp_releases+=("$OPTARG^Designer")
      ;;
    r ) cp_releases+=("$OPTARG^AssetRepository")
      ;;
    \? ) usage
      ;;
  esac
done

if [[ -z "${cp_releases}" ]]; then
    echo "No releases specified, validation complete."
    exit 1
fi

function is_release_ready {
  release_name=${1}
  release_type=${2}
  release_status=$(oc get ${release_type} ${release_name} -o json | jq -r '.status.conditions')

  echo "Checking $release_name with type $release_type..."

  if [[ -z "$release_status" ]]; then
    echo "Nothing returned from ${release_name}"
    return 0
  fi

  statusFieldReleaseStatus=$(echo -e $release_status | jq '.[0].status' | awk '{print tolower($0)}' | tr -d '"')
  typeFieldReleaseStatus=$(echo -e $release_status | jq '.[0].type' | awk '{print tolower($0)}' | tr -d '"')

  if [[ "$statusFieldReleaseStatus" == "true" && "$typeFieldReleaseStatus" == "ready" ]]; then
    echo "SUCCESS: ${release_name} is released and ready!"
    return 1
  fi

  if [[ "$release_status" == "[]" ]]; then
    echo "SUCCESS: Empty status, ${release_name} is released and ready!"
    return 1
  fi
}

# Retry for up to 20 minutes
startup_retries=60
retry_interval=20
retry_count=0
everything_ready=false

while [ ! $retry_count -eq $startup_retries ] && [ "$everything_ready" = false ]; do
  echo "Checking releases..."
  everything_ready=true
  for release in "${cp_releases[@]}"; do
    # Parsing out name from typea
    IFS='^'
    read -a releasearr <<< "$release"
    release_name_parsed=$(echo ${releasearr[0]})
    release_type_parsed=$(echo ${releasearr[1]})

    if is_release_ready ${release_name_parsed} ${release_type_parsed}; then
      echo "${release} is not ready!"
      everything_ready=false
    fi
  done

  if [ "$everything_ready" = false ]; then
    sleep $retry_interval
    retry_count=$((retry_count+1))
    echo "Releases not ready, retrying... ${retry_count} attempts out of ${startup_retries}."
  fi
  echo -e "----------------------------------------\n"
done

if [ "$everything_ready" = false ]; then
  echo "Failed due to retries exceeded while waiting for releases..."
  exit 1
else
  echo "Everything succesfully released!"
fi
