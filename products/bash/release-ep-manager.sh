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
#   -r : <release-name> (string), Defaults to "es-demo"
#
# USAGE:
#   With defaults values
#     ./release-ep-manager.sh
#
#   Overriding the namespace and release-name
#     ./release-ep-manager.sh -n cp4i-prod -r prod

function usage() {
  echo "Usage: $0 -n <namespace> -r <release-name>"
}

namespace="cp4i"
release_name="epm-demo"
production="false"
storageClass="ibmc-file-gold-gid"
apic_releasename="ademo"

while getopts "n:r:a:pc:" opt; do
  case ${opt} in
  n)
    namespace="$OPTARG"
    ;;
  r)
    release_name="$OPTARG"
    ;;
  a)
    apic_releasename="$OPTARG"
    ;;
  p)
    production="true"
    ;;
  c)
    storageClass="$OPTARG"
    ;;
  \?)
    usage
    exit
    ;;
  esac
done
# EventEndpointManagement needs APIC up and running
# So we check APIC status before proceeding to install
for i in $(seq 1 120); do
  APIC_STATUS=$(kubectl get apiconnectcluster.apiconnect.ibm.com -n ${namespace} ${apic_releasename} -o jsonpath='{.status.phase}')
  if [ "$APIC_STATUS" == "Ready" ]; then
    printf "$tick"
    echo "[OK] APIC is ready"
    break
  else
    echo "Waiting for APIC install to complete (Attempt $i of 120). Status: $APIC_STATUS"
    kubectl get apic,pods,pvc -n ${namespace}
    echo "Checking again in one minute..."
    sleep 60
  fi
done

if [ "$APIC_STATUS" != "Ready" ]; then
  printf "$cross"
  echo "[ERROR] APIC failed to install"
  exit 1
fi

if [ "$production" == "true" ]; then
  echo "Production Mode Enabled"
  cat <<EOF | oc apply -f -
apiVersion: eventendpointmanager.apiconnect.ibm.com/v1beta1
kind: EventEndpointManager
metadata:
  labels:
    app.kubernetes.io/instance: eventendpointmanager-production
    app.kubernetes.io/managed-by: ibm-apiconnect
    app.kubernetes.io/name: eventendpointmanager-production
  name: ${release_name}
  namespace: ${namespace}
spec:
  endpointTypes:
    - Events
  license:
    accept: true
    license: L-RJON-BZEP9N
    metric: VIRTUAL_PROCESSOR_CORE
    use: production
  profile: n3xc14.m48
  version: 10.0.3.0
  storageClassName: ${storageClass}

EOF
else
  cat <<EOF | oc apply -f -
apiVersion: eventendpointmanager.apiconnect.ibm.com/v1beta1
kind: EventEndpointManager
metadata:
  labels:
    app.kubernetes.io/instance: eventendpointmanager-minimum
    app.kubernetes.io/managed-by: ibm-apiconnect
    app.kubernetes.io/name: eventendpointmanager-minimum
  name: ${release_name}
  namespace: ${namespace}
spec:
  endpointTypes:
    - Events
  license:
    accept: true
    license: L-RJON-BZEP9N
    metric: VIRTUAL_PROCESSOR_CORE
    use: nonproduction
  profile: n1xc10.m48
  version: 10.0.3.0
  storageClassName: ${storageClass}
EOF

fi
