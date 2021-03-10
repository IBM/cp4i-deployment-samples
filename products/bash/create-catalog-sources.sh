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
#   -p : Use pre-release catalog sources
#
# USAGE:
#   With defaults values
#     ./create-catalog-sources.sh
#
#   Using pre-release catalog sources
#     ./create-catalog-sources.sh -p
#

function usage() {
  echo "Usage: $0 -p"
  exit 1
}

USE_PRERELEASE_CATALOGS=false
INFO="\xE2\x84\xB9"

while getopts "p" opt; do
  case ${opt} in
  p)
    USE_PRERELEASE_CATALOGS=true
    ;;
  \?)
    usage
    ;;
  esac
done

echo -e "$INFO [INFO] Applying catalogsources\n"
if [[ "${USE_PRERELEASE_CATALOGS}" == "true" ]]; then
  echo -e "$INFO [INFO] Using the pre-release catalog sources as specified at https://ibm.ent.box.com/notes/765437595126"
  cat <<EOF | oc apply -f -
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: opencloud-operators
  namespace: openshift-marketplace
spec:
  displayName: IBMCS Operators
  image: hyc-cloud-private-daily-docker-local.artifactory.swg-devops.com/ibmcom/ibm-common-service-catalog:20210305-2330
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: automation-base-pak-operators
  namespace: openshift-marketplace
spec:
  displayName: IBMABP Operators
#  image: cp.stg.icr.io/cp/ibm-automation-foundation-core-catalog:latest
  image: cp.stg.icr.io/cp/ibm-automation-foundation-core-catalog:1.0.0-GM
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: pn-operators
  namespace: openshift-marketplace
spec:
  displayName: PN Operators
  image: cp.stg.icr.io/cp/ibm-integration-platform-navigator-catalog:latest
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ace-operators
  namespace: openshift-marketplace
spec:
  displayName: ACE Operators
#  image: cp.stg.icr.io/cp/appconnect-operator-catalog:latest
  image: docker.io/ibmcom/appconnect-operator-catalog:1.3.0-20210304-190040@sha256:f89ec87d2215ab2736bc261c46c439b574ae7ba28d4a5747ad9824643bbbd709
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
---
#apiVersion: operators.coreos.com/v1alpha1
#kind: CatalogSource
#metadata:
#  name: mq-operators
#  namespace: openshift-marketplace
#spec:
#  displayName: MQ Operators
  # TODO Need latest
#  image: cp.stg.icr.io/cp/ibm-mq-operator-catalog:latest
#  publisher: IBM
#  sourceType: grpc
#  updateStrategy:
#    registryPoll:
#      interval: 45m
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: es-operators
  namespace: openshift-marketplace
spec:
  displayName: ES Operators
  image: cp.stg.icr.io/cp/ibm-eventstreams-catalog:latest
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: apic-operators
  namespace: openshift-marketplace
spec:
  displayName: APIC Operators
#  image: cp.stg.icr.io/cp/ibm-apiconnect-catalog:latest-nightly
  image: ibmcom/ibm-apiconnect-catalog@sha256:c9ceccdc326f4f98073418fdde483acf86d9cf6fd2189afe8b073019592f5f52
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: dp-operators
  namespace: openshift-marketplace
spec:
  displayName: DP Operators
#  image: cp.stg.icr.io/cp/datapower-operator-catalog:latest
  image: cp.stg.icr.io/cp/datapower-operator-catalog@sha256:c55e31809e0d8ca5e0398bfb956bde845a5c8debc55e529f6b76fab025d69dbb
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: aspera-redis-operators
  namespace: openshift-marketplace
spec:
  displayName: Redis for Aspera Operators
  image: cp.stg.icr.io/cp/ibm-cloud-databases-redis-catalog:latest
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: aspera-operators
  namespace: openshift-marketplace
spec:
  displayName: Aspera Operators
  image: cp.stg.icr.io/cp/icp4i/aspera/aspera-hsts-catalog:latest
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ar-operators
  namespace: openshift-marketplace
spec:
  displayName: AR Operators
  image: cp.stg.icr.io/cp/ibm-integration-asset-repository-catalog:1.2.0-2021-03-08-1057-eebae733-amd64@sha256:a662838d17813fa6c48be160cbe789a1708adca9842a4b5d3bbdbfad8b78a9c7
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: od-operators
  namespace: openshift-marketplace
spec:
  displayName: OD Operators
  # TODO Need latest
  #image: cp.stg.icr.io/cp/ibm-integration-operations-dashboard-catalog:latest
  image: cp.stg.icr.io/cp/ibm-integration-operations-dashboard-catalog:2.2.0-2021-03-08-2154-e90a9004-od-release-2021.1.1-0-rc2@sha256:b18873e258529f79bb0e419d16813a55b01d317e1d1b8689b72e41a22ea8d33f
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
---
EOF


else
  echo -e "$INFO [INFO] Using the release catalog sources"
  cat <<EOF | oc apply -f -
`  ---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: opencloud-operators
  namespace: openshift-marketplace
spec:
  displayName: IBMCS Operators
  publisher: IBM
  sourceType: grpc
  image: docker.io/ibmcom/ibm-common-service-catalog:latest
  updateStrategy:
    registryPoll:
      interval: 45m

---

apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-operator-catalog
  namespace: openshift-marketplace
spec:
  displayName: ibm-operator-catalog
  publisher: IBM Content
  sourceType: grpc
  image: docker.io/ibmcom/ibm-operator-catalog
  updateStrategy:
    registryPoll:
      interval: 45m
EOF
fi
