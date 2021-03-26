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
# USAGE:
#   source ./license-helper.sh; getAllLicenses \$NAMESPACE
#******************************************************************************

LICENSES_CM=demo-licenses

function usage() {
  echo "Usage: source $0; getAllLicenses \$NAMESPACE"
}

while getopts "" opt; do
  case ${opt} in
    \?)
      usage
      exit
      ;;
  esac
done

function getAllLicenses() {
  oc -n $1 get configmap $LICENSES_CM -ojsonpath='{.data}'
}

function getDemoLicense() {
  oc -n $1 get configmap $LICENSES_CM -ojsonpath='{.data.demo}'
}

function getACELicense() {
  oc -n $1 get configmap $LICENSES_CM -ojsonpath='{.data.ace}'
}

function getAPICLicense() {
  oc -n $1 get configmap $LICENSES_CM -ojsonpath='{.data.apic}'
}

function getARLicense() {
  oc -n $1 get configmap $LICENSES_CM -ojsonpath='{.data.ar}'
}

function getMQLicense() {
  oc -n $1 get configmap $LICENSES_CM -ojsonpath='{.data.mq}'
}

function getTracingLicense() {
  oc -n $1 get configmap $LICENSES_CM -ojsonpath='{.data.tracing}'
}
