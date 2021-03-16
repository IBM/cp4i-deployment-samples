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
  # image: hyc-cloud-private-daily-docker-local.artifactory.swg-devops.com/ibmcom/ibm-common-service-catalog:20210305-2330
 # image: hyc-cloud-private-daily-docker-local.artifactory.swg-devops.com/ibmcom/ibm-common-service-catalog:20210309-1556
  image: docker.io/ibmcom/ibm-common-service-catalog:latest
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
 # image: cp.stg.icr.io/cp/ibm-automation-foundation-core-catalog:1.0.0-GM
  image: docker.io/ibmcom/ibm-automation-foundation-core-catalog@sha256:e34c8b699d0481848974904ac2014fb029bd2c08b38fe902ba615dbe4354a3e1
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
#  image: docker.io/ibmcom/appconnect-operator-catalog:1.3.0-20210304-190040@sha256:f89ec87d2215ab2736bc261c46c439b574ae7ba28d4a5747ad9824643bbbd709
  image: docker.io/ibmcom/appconnect-operator-catalog:1.3.0-20210311-191932@sha256:d38b1459b578a3b2fa7ca5d5277d7f5b63a1a4e116905381d19733fa7fed5f40
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
 name: mq-operators
 namespace: openshift-marketplace
spec:
 displayName: MQ Operators
 # TODO Need latest
# image: docker.io/ibmcom/ibm-mq-operator-catalog@sha256:8fc3184888049bc16aa02b0b8731f091e2287e8332c8ef673c4df644095ecf41
 image: docker.io/ibmcom/ibm-mq-operator-catalog@sha256:8fc3184888049bc16aa02b0b8731f091e2287e8332c8ef673c4df644095ecf41
 publisher: IBM
 sourceType: grpc
 updateStrategy:
   registryPoll:
     interval: 45m
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: es-operators
  namespace: openshift-marketplace
spec:
  displayName: ES Operators
  image: cp.stg.icr.io/cp/ibm-eventstreams-catalog:2021-03-11-13.51.26-1842a62
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
#  image: ibmcom/ibm-apiconnect-catalog@sha256:5343ace881d7ca17cac4a9f734f5000c1c7a26a5b0df23cbf5b2e98d00d24fc5
#  image: ibmcom/ibm-apiconnect-catalog@sha256:ad97f9db387509da77ce4516e20f524c4530d04982c1a81fa42a7f460111a4a2
  image: ibmcom/ibm-apiconnect-catalog@sha256:9bf090ec510d8db2c6e382c23e1903625fa20f7a835f4252759b03aababa5e8a
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
  #image: cp.stg.icr.io/cp/ibm-cloud-databases-redis-catalog:latest
  image: cp.stg.icr.io/cp/ibm-cloud-databases-redis-catalog@sha256:1462cee2d79729c72b4d9b39399ddfd13c48c7f923a1e55ccdbb5df2091ada18
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
#  image: cp.stg.icr.io/cp/icp4i/aspera/aspera-hsts-catalog:latest
  image: docker.io/ibmcom/aspera-hsts-catalog@sha256:3ada193cc000c49cb15c5f31d6ce775cd1dfa1b5e5094794b119fe2721856da5
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
#  image: cp.stg.icr.io/cp/ibm-integration-asset-repository-catalog:1.2.0-2021-03-08-1057-eebae733-amd64@sha256:a662838d17813fa6c48be160cbe789a1708adca9842a4b5d3bbdbfad8b78a9c7
  image: docker.io/ibmcom/ibm-integration-asset-repository-catalog@sha256:2be42bf3651b4c6d2e3bb967437b6ce34144fa403155e4a614ca3e3c635173f2
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
  #image: cp.stg.icr.io/cp/ibm-integration-operations-dashboard-catalog:latest
#  image: cp.stg.icr.io/cp/ibm-integration-operations-dashboard-catalog:2.2.0-2021-03-10-1256-a7d67283-od-release-2021.1.1-0-rc3@sha256:5f761cc6c32f40449e0282ba0be9dc10dac084e3fdfc778831c5b07b3d70e273
  image: cp.stg.icr.io/cp/ibm-integration-operations-dashboard-catalog:2.2.0-2021-03-12-1752-1b9b5f3a-od-release-2021.1.1-0-rc5@sha256:69115d79fd81cdea9163dbd902b260f86cc1e146dc95b3965fb0ec04c022b01c
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: cp4i-demo-operator-catalog-source
  namespace: openshift-marketplace
spec:
  displayName: Demo Operators
  sourceType: grpc
#  image: cp.stg.icr.io/cp/ibm-integration-demos-catalog:1.0.0-2021-02-24-0956-3b8d3254@sha256:81995aa0e8581be80ffdaa9aaae4678d4971bcb9bf1385bcf6b539ac952f80f6
  image: cp.stg.icr.io/cp/ibm-integration-demos-catalog:1.0.0-2021-03-16-0959-06817169-license-fix@sha256:226eedd2d982c7f3c70a3eb583beedbea8f0e755db08be0b69634ef9f2504578
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
