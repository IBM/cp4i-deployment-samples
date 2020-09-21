#!/bin/bash
#******************************************************************************
# Licensed Materials - Property of IBM
# (c) Copyright IBM Corporation 2019. All Rights Reserved.
#
# Note to U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.
#******************************************************************************

# PREREQUISITES:
#   - Logged into cluster on the OC CLI (https://docs.openshift.com/container-platform/4.4/cli_reference/openshift_cli/getting-started-cli.html)
#
# PARAMETERS:
#   -n : <namespace> (string), Defaults to 'cp4i'
#
#   With defaults values
#     ./deploy.sh
#
#   With overridden values
#     ./deploy.sh -n <namespace>

function usage() {
  echo "Usage: $0 -n <namespace>"
  exit 1
}

namespace="cp4i"
tick="\xE2\x9C\x85"
cross="\xE2\x9D\x8C"
all_done="\xF0\x9F\x92\xAF"

while getopts "n:" opt; do
  case ${opt} in
  n)
    namespace="$OPTARG"
    ;;
  \?)
    usage
    ;;
  esac
done

CURRENT_DIR=$(dirname $0)
echo "INFO: Current directory: '$CURRENT_DIR'"
echo "INFO: Namespace: '$namespace'"

if [[ -z "${namespace// }" ]]; then
  echo -e "$cross ERROR: A namespace must be specified"
  usage
fi

echo -e "\n----------------------------------------------------------------------------------------------------------------------------------------------------------\n"

echo "INFO: Creating a deployment/service/route for the Projection Claims KTable application..."
cat << EOF | oc apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  namespace: $namespace
  name: projection-claims-eei
  labels:
    app: projection-claims-eei
    demo: eei
spec:
  selector:
    matchLabels:
      app: projection-claims-eei
  replicas: 0
  template:
    metadata:
      labels:
        app: projection-claims-eei
        demo: eei
    spec:
      containers:
        - name: projection-claims-eei
          image: image-registry.openshift-image-registry.svc:5000/$namespace/projection-claims-eei
          env:
          readinessProbe:	
            httpGet:	
              path: /getalldata
              port: 8080	
              scheme: HTTP	
              periodSeconds: 10
          livenessProbe:	
            httpGet:	
              path: /getalldata
              port: 8080	
              scheme: HTTP	
            initialDelaySeconds: 15	
            periodSeconds: 30
---
apiVersion: v1
kind: Service
metadata:
  namespace: $namespace
  name: projection-claims-eei
  labels:
    app: projection-claims-eei
    demo: eei
spec:
  ports:
    - port: 8080
      targetPort: 8080
      protocol: TCP
      name: projection-claims-eei
  selector:
    app: projection-claims-eei
---
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  namespace: $namespace
  name: projection-claims-eei
  labels:
    app: projection-claims-eei
    demo: eei
spec:
  to:
    kind: Service
    name: projection-claims-eei
  tls:
    termination: edge
    insecureEdgeTerminationPolicy: Redirect
EOF
