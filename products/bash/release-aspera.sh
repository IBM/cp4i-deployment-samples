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
#   -c : storage class to be used
#   -k : absolute path to license key file
#
# USAGE:
#   With defaults values
#     ./release-aspera.sh
#
#   Overriding the namespace and release-name
#     ./release-aspera -n cp4i-prod -r prod -k keyfile_path

function usage() {
  echo "Usage: $0 -n <namespace> -r <release-name> [-t]"
}

namespace="cp4i"
release_name="aspera"
production="false"
license_key_filepath=""
storage_class=""

while getopts "n:r:pk:c:" opt; do
  case ${opt} in
  n)
    namespace="$OPTARG"
    ;;
  r)
    release_name="$OPTARG"
    ;;
  p)
    production="true"
    ;;
  k)
    license_key_filepath="$OPTARG"
    ;;
  c)
    storage_class="$OPTARG"
    ;;
  \?)
    usage
    exit
    ;;
  esac
done

license="$(cat ${license_key_filepath} | awk '{printf "      %s\n",$0}')"

if [[ "$production" == "true" ]]; then
  echo "Production Mode Enabled"
  cat <<EOF | oc apply -f -
apiVersion: hsts.aspera.ibm.com/v1
kind: IbmAsperaHsts
metadata:
  labels:
    app.kubernetes.io/instance: ibm-aspera-hsts
    app.kubernetes.io/managed-by: ibm-aspera-hsts-prod
    app.kubernetes.io/name: ibm-aspera-hsts-prod
  name: ${release_name}
  namespace: ${namespace}
spec:
  containers:
    ascp:
      resources:
        limits:
          cpu: 4000m
          memory: 4096Mi
        requests:
          cpu: 1000m
          memory: 2048Mi
    asperanoded:
      resources:
        limits:
          cpu: 2000m
          memory: 2048Mi
        requests:
          cpu: 500m
          memory: 1024Mi
    default:
      resources:
        limits:
          cpu: 1000m
          memory: 500Mi
        requests:
          cpu: 100m
          memory: 250Mi
  deployments:
    default:
      replicas: 3
  license:
    accept: true
    key: >- 
${license}
    use: CloudPakForIntegrationProduction
  redis:
    persistence:
      enabled: true
      storageClass: ${storage_class}
    resources:
      requests:
        cpu: 1000m
        memory: 8Gi
  services:
    httpProxy:
      type: ClusterIP
    tcpProxy:
      type: LoadBalancer
  storages:
    - claimName: hsts-transfer-pvc
      class: ${storage_class}
      deleteClaim: false
      mountPath: /data/
      size: 2000Gi
  version: 4.0.0
EOF
else

  cat <<EOF | oc apply -f -
apiVersion: hsts.aspera.ibm.com/v1
kind: IbmAsperaHsts
metadata:
  labels:
    app.kubernetes.io/instance: ibm-aspera-hsts
    app.kubernetes.io/managed-by: ibm-aspera-hsts
    app.kubernetes.io/name: ibm-aspera-hsts
  name: ${release_name}
  namespace: ${namespace}
spec:
  deployments:
    default:
      replicas: 1
  license:
    accept: true
    key: >- 
${license}
    use: CloudPakForIntegrationNonProduction
  redis:
    persistence:
      enabled: false
  services:
    httpProxy:
      type: ClusterIP
    tcpProxy:
      type: LoadBalancer
  storages:
    - claimName: hsts-transfer-pvc
      class: ${storage_class}
      deleteClaim: true
      mountPath: /data/
      size: 20Gi
  version: 4.0.0

EOF
fi
