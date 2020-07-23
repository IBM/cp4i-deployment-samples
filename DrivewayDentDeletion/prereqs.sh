#!/bin/bash

cd "$(dirname $0)"

export NAMESPACE=driveway-dent-deletion
export ER_REGISTRY=$(oc get secret -n mq ibm-entitlement-key -o json | jq -r '.data.".dockerconfigjson"' | base64 --decode | jq -r '.auths' | jq 'keys[]' | tr -d '"')
export ER_USERNAME=$(oc get secret -n mq ibm-entitlement-key -o json | jq -r '.data.".dockerconfigjson"' | base64 --decode | jq -r '.auths."cp.icr.io".username')
export ER_PASSWORD=$(oc get secret -n mq ibm-entitlement-key -o json | jq -r '.data.".dockerconfigjson"' | base64 --decode | jq -r '.auths."cp.icr.io".password')

echo "Installing tekton"
oc apply --filename https://storage.googleapis.com/tekton-releases/pipeline/previous/v0.12.1/release.yaml
echo "Installing tekton triggers"
oc apply -f https://storage.googleapis.com/tekton-releases/triggers/previous/v0.5.0/release.yaml
echo "Waiting for tekton and triggers deployment to finish..."
oc wait -n tekton-pipelines --for=condition=available deployment --timeout=20m tekton-pipelines-controller tekton-pipelines-webhook tekton-triggers-controller tekton-triggers-webhook

echo "Creating ${NAMESPACE} namespace and patching service account"
oc create namespace ${NAMESPACE}
oc adm policy add-scc-to-group privileged system:serviceaccounts:$NAMESPACE

export DOCKER_REGISTRY="image-registry.openshift-image-registry.svc:5000"
export username=image-bot

declare -a image_projects=("ace" "mq")

echo "Creating secrets to push images to openshift local registry"
for image_project in "${image_projects[@]}"
do
  kubectl -n ${image_project} create serviceaccount image-bot
  oc -n ${image_project} policy add-role-to-user registry-editor system:serviceaccount:${image_project}:image-bot

  export password="$(oc -n ${image_project} serviceaccounts get-token image-bot)"

  oc create -n $NAMESPACE secret docker-registry cicd-${image_project} \
    --docker-server=$DOCKER_REGISTRY --docker-username=$username --docker-password=$password \
    --dry-run -o yaml | oc apply -f -
done

echo "Creating secret to pull base images from Entitled Registry"
cat << EOF | oc apply --namespace ${NAMESPACE} -f -
apiVersion: v1
kind: Secret
metadata:
  name: er-pull-secret
  annotations:
    tekton.dev/docker-0: ${ER_REGISTRY}
type: kubernetes.io/basic-auth
stringData:
  username: ${ER_USERNAME}
  password: ${ER_PASSWORD}
EOF

export CURRENT_USER="$(oc whoami)"
mkdir -p ${PWD}/tmp
echo "Fetching kubeconfig of cluster and creating secret"
# oc adm policy add-role-to-user admin $CURRENT_USER -n $NAMESPACE
oc config view --flatten=true --minify=true > ${PWD}/tmp/kubeconfig.yaml
oc create -n $NAMESPACE secret generic cluster-kubeconfig --from-file=kubeconfig=${PWD}/tmp/kubeconfig.yaml --dry-run -o yaml | oc apply -f -

export HELM_HOME=${PWD}/tmp/.helm
mkdir -p ${HELM_HOME}
echo "Fetching ca.crt and ca.key for your cluster"
kubectl -n kube-system get secret cluster-ca-cert -o jsonpath='{.data.tls\.crt}' | base64 --decode > $HELM_HOME/ca.crt
kubectl -n kube-system get secret cluster-ca-cert -o jsonpath='{.data.tls\.key}' | base64 --decode > $HELM_HOME/ca.key

echo "key.pem does not exist in $HELM_HOME, creating key.pem and cert.pem, ca.pem using the new key.pem"
openssl genrsa -out $HELM_HOME/key.pem 4096
openssl req -new -key $HELM_HOME/key.pem -out $HELM_HOME/csr.pem -subj "/C=US/ST=New York/L=Armonk/O=IBM Cloud Private/CN=admin"
openssl x509 -req -in $HELM_HOME/csr.pem -extensions v3_usr -CA $HELM_HOME/ca.crt -CAkey $HELM_HOME/ca.key -CAcreateserial -out $HELM_HOME/cert.pem
openssl x509 -in $HELM_HOME/ca.crt -out $HELM_HOME/ca.pem -outform PEM

echo "Creating helm tls secret for helm install"
oc create -n $NAMESPACE secret generic task-helm-tls \
  --from-file=key.pem=$HELM_HOME/key.pem \
  --from-file=cert.pem=$HELM_HOME/cert.pem \
  --from-file=ca.pem=$HELM_HOME/ca.pem \
  --dry-run -o yaml | oc apply -f -

oc create -n $NAMESPACE secret generic task-helm-repositories \
  --from-file=repositories.yaml=repositories.yaml \
  --dry-run -o yaml | oc apply -f -

cat << EOF | oc apply -f -
kind: Secret
apiVersion: v1
metadata:
  name: mqcert
  namespace: mq
data:
  tls.crt: >-
    LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURDVENDQWZHZ0F3SUJBZ0lVR0tiaE5ZWXJMZVdqUFBVTlp5RldJTjJQWExRd0RRWUpLb1pJaHZjTkFRRUwKQlFBd0ZERVNNQkFHQTFVRUF3d0piRzlqWVd4b2IzTjBNQjRYRFRJd01ERXdOakV3TURjeU4xb1hEVE13TURFdwpNekV3TURjeU4xb3dGREVTTUJBR0ExVUVBd3dKYkc5allXeG9iM04wTUlJQklqQU5CZ2txaGtpRzl3MEJBUUVGCkFBT0NBUThBTUlJQkNnS0NBUUVBem5EbkpGaHhFMGRMTFdhOUZZQlBvakZNdWVSL1pESXJZTEE0OGFWYVNNYU8KRjhNT0o0RGpHQWJ1L0UwbjlIR3JxSXI5bnRSc29SZkhjMFdhcExDcFdwdXdnWlBFSXVXR25MS2xjdVJtYnRVVApUUlkvQkhITEtrVUFncnlCUXVqZFh2RFRobnltYXZCUGpLM1QxZlZFMGNFT1lHQTlHanJYU0IzT2hQR1pHQmxOCmM5NXppZEZSOVZyWHQwRFJDVkFrNjRmYlRoa3V2SDh1TkV1VGFodlVFOVJIZmRzajJzZU81S0k3bmdYMG1IUUIKcUlMdVAzcGEreU1WNUc4TlBaalN4U0IwQjNlS3YraUNjV2hSdTZSRmIyZmNmZXpnbm1TcFJYVTUwS1lxV1piZApvc0czaFFxU1JRUTJZUmR5NzZaMGJKb3FGM3N0aGJJaTZ5TmYvTVQ5ZndJREFRQUJvMU13VVRBZEJnTlZIUTRFCkZnUVVIQlBGY0FyTy9ZUmxiZ0tobmkxSVdnS0Z5VEF3SHdZRFZSMGpCQmd3Rm9BVUhCUEZjQXJPL1lSbGJnS2gKbmkxSVdnS0Z5VEF3RHdZRFZSMFRBUUgvQkFVd0F3RUIvekFOQmdrcWhraUc5dzBCQVFzRkFBT0NBUUVBWkZ6SQpaLzZOay9TQmY0WXJHdVdNSzVjTTRLdldjWUdXQWlndTZ1TzZvV2VUVmdYamtGbE9GZ2RHRVhpSjFZNi9mRFBCCitaMVE0SERMYm1hbGE1aXRqeVhXbWFsRTFFOHR2bThGMDA5ZEFPL0oxUmNyS1VZcUFKbGJQNTZtbmt1QmtqZE0KYzAyMkhXOTd0RUpkYXViTlF2ZWJraDhZK1loUGVkV242ZmFtMVM1S2cwYUlVUWRKd0FuZDlCb2hLVkk3SHFFZgpoUktDYmJFZzNySXlSS0FLdk5DRXlvMjY4b3VIcll3Mi9WMEhMU0VnWEU3UTFxWTVKaXF6Y3Iyb0EvU2xZdGZwCnZYZFhKajA3OGJ1N3hrS2FxZkxpN3FTSzdjSVRjWjNWcldGOWZCbEh5MVV1K2V1NVNhN29udFR2MktON2Joc1QKNGczVTlMdWR2L01xTE5EWDVnPT0KLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQo=
  tls.key: >-
    LS0tLS1CRUdJTiBQUklWQVRFIEtFWS0tLS0tCk1JSUV2UUlCQURBTkJna3Foa2lHOXcwQkFRRUZBQVNDQktjd2dnU2pBZ0VBQW9JQkFRRE9jT2NrV0hFVFIwc3QKWnIwVmdFK2lNVXk1NUg5a01pdGdzRGp4cFZwSXhvNFh3dzRuZ09NWUJ1NzhUU2YwY2F1b2l2MmUxR3loRjhkegpSWnFrc0tsYW03Q0JrOFFpNVlhY3NxVnk1R1p1MVJOTkZqOEVjY3NxUlFDQ3ZJRkM2TjFlOE5PR2ZLWnE4RStNCnJkUFY5VVRSd1E1Z1lEMGFPdGRJSGM2RThaa1lHVTF6M25PSjBWSDFXdGUzUU5FSlVDVHJoOXRPR1M2OGZ5NDAKUzVOcUc5UVQxRWQ5MnlQYXg0N2tvanVlQmZTWWRBR29ndTQvZWxyN0l4WGtidzA5bU5MRklIUUhkNHEvNklKeAphRkc3cEVWdlo5eDk3T0NlWktsRmRUblFwaXBabHQyaXdiZUZDcEpGQkRaaEYzTHZwblJzbWlvWGV5MkZzaUxyCkkxLzh4UDEvQWdNQkFBRUNnZ0VBQ0czcndqd3FRZE5EYXBNclhWbGo1d2VFVG9MYUFNbGJwQk1PQUMvMFE4eDMKdU5pcUYwclgrdjh0ZXZmYmpjdW1hcmRpSzc0WXdXc3JKYlhOM3JPbjlwOHMwZDJxd0pJR3NSZEtVaXFwVkJVMwpPSXFVQUNaMVdVQ0FDTmFSb0ozSmpEcmhLRGltd3U4VkVIVjRsTi95ODIyaW5LVFJXZVRWTFlpcUNodWpXS3g5CkNvUU9qeFpkZFFxV0xNbEtndFRQOGUxSTI2MmNUbVhzVzhhSWQ4dDVpWUZmcFc2OHpLTzZqSmRVWktpdnE2MkcKc3hqYnF5Kzk1SitqbzBLeWUybzN0M2NFempJUEk4L1hhRmllTlFFTUZtRWVlVzVSNE1iZ3VNblpocTBVV1BzSwpWdHE0Ukp2OW02aC9RWGlqMGVCY281Rnp2MFB5RHZtUFkrZWUwT1plQVFLQmdRRHBQUm9wanpMYjhFRnUzcnU2Cktyc1BNYzUvbUc4S1pmY0NGejdjSHRQdTJEQzZxTytpRXhkVk5xZ2h6ZGtLK05kalFGUGNmdlRQZXhCOWhsWUEKN0NtOE1QRkxSNUhNditFL3BSQm5UNzVLZHdhT2NjT21ibFNGSE1LSjhJVXZld3daaERhQWFFWlNmQld0TU9GdwpKa0FrTDdMTWxkL0Ixbk9LaDM5YmR1ZEpRUUtCZ1FEaWxsT3ZGVkVjaUxyM28yR1JzUnhIK1lMQkJjbUZpSEo2CngzQ1JNQjRPMldZMjJPYXpsZVJZUXdqdU1PS2xGNmNiR0VBR1JKaVRIbGo2MFE0cXVwbERrbVJTdWVJcnBRMTEKU3A1MnMranY3WXpZdFpxUG00UzFtaG9xcU1iRDg2V2VEZnp6RUIweWJPUk8xZW04NXRqZStoN3FvN0Y5QWUrSwplU29TUDduV3Z3S0JnQUpTQlV5Y2pCajhEdXFYZEs2cGRpcjBoK1ZsRXRXN3BmVnpYY0M2M2NqbWhiV1ZzS3lnCkcvOVJCK011TlJhUzJ6RzFsaC8vYzFnTkZXRHFVVGk1SU1FcWkzd0FQa2NYTVpwOGZlbEpOYzl2MTdUYkZPTTIKL2NoRlBQbzZWbGplbElROGVINVdpenlPMTNoZG9DQ0pnT0hiUjZBWmJaeDBFYm96RnVWR0RZOEJBb0dBUCs1QQpRRWNZY3ArVmVTZU04T2x5M0UvbTk0VWxmZHFveWtHWlhpMmdYWG96WDhoRkYyaDBXLzdWOXphdHkvem5kanFhClhlcGV6aXVpMlduQXdJZVRsTUFxTkRra09rSkFrTlp6N1hRSGhpS1ZPZFBMZnpkVzgxSStqY2kvQkN5cmp2UE4KYWRzakVjWXRpSnpNYlRNSS82aThybUZ2UTZFWE1BL05zZ1p1N2NzQ2dZRUFpN2RWYzhkNmNUUVFKR05HL0l4Vwo2d1dJN1U3V094OTNVTlFEZGVyQUhNeFRBMXRKbHdTRmtNUzYrWXAvZzU0K0tTQWZLTWw4eDVUTnRxM1lpUEdiCkozOGtVU2lxV2VudFYzeExMVmJMRTRUYXgxbkptK0ZFNDV4VWxwYjJyTU5kYjFuOFpOdkVrTTJsRElUMHBKOWUKU3EvWkZXMG1jSGdjVWRpdm93WHJLNVE9Ci0tLS0tRU5EIFBSSVZBVEUgS0VZLS0tLS0K
type: Opaque
EOF

cat << EOF > /tmp/policy.xml
<?xml version="1.0" encoding="UTF-8"?>
<policies>
  <policy policyType="MQEndpoint" policyName="MQEndpointPolicy" policyTemplate="MQEndpoint">
    <connection>CLIENT</connection>
    <destinationQueueManagerName>mqddddev</destinationQueueManagerName>
    <queueManagerHostname>mq-ddd-dev-ibm-mq.mq.svc.cluster.local</queueManagerHostname>
    <listenerPortNumber>1414</listenerPortNumber>
    <channelName>ACE_SVRCONN</channelName>
    <securityIdentity></securityIdentity>
    <useSSL>false</useSSL>
    <SSLPeerName></SSLPeerName>
    <SSLCipherSpec></SSLCipherSpec>
  </policy>
</policies>
EOF

cat << EOF > /tmp/policyDescriptor.xml
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<ns2:policyProjectDescriptor xmlns="http://com.ibm.etools.mft.descriptor.base" xmlns:ns2="http://com.ibm.etools.mft.descriptor.policyProject">
  <references/>
</ns2:policyProjectDescriptor>
EOF

oc create secret generic -n ace ace-ddd-dev-creds \
  --from-literal=mqsc= \
  --from-literal=adminPassword= \
  --from-literal=appPassword= \
  --from-literal=keystorePassword= \
  --from-literal=keystoreKey-mykey= \
  --from-literal=keystoreCert-mykey= \
  --from-literal=keystorePass-mykey= \
  --from-literal=truststorePassword= \
  --from-literal=truststoreCert-mykey= \
  --from-literal=odbcini= \
  --from-literal=serverconf= \
  --from-literal=setdbparms= \
  --from-file=policy=/tmp/policy.xml \
  --from-file=policyDescriptor=/tmp/policyDescriptor.xml \
  --dry-run -o yaml | oc apply -f -

echo "Waiting for postgres to be ready"
oc wait -n postgres --for=condition=available deploymentconfig --timeout=20m postgresql

echo "Creating quotes table in postgres samepledb"
oc exec -n postgres -it $(oc get pod -n postgres -l name=postgresql -o jsonpath='{.items[].metadata.name}') \
  -- psql -U admin -d sampledb -c \
'CREATE TABLE QUOTES (
  QuoteID SERIAL PRIMARY KEY NOT NULL,
  Name VARCHAR(100),
  EMail VARCHAR(100),
  Address VARCHAR(100),
  USState VARCHAR(100),
  LicensePlate VARCHAR(100),
  ACMECost INTEGER,
  ACMEDate DATE,
  BernieCost INTEGER,
  BernieDate DATE,
  ChrisCost INTEGER,
  ChrisDate DATE);'
