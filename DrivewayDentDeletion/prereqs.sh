#!/bin/bash
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

echo "Fetching kubeconfig of cluster and creating secret"
oc config view --flatten=true --minify=true > ~/kubeconfig.yaml
oc create secret generic cluster-kubeconfig --from-file=kubeconfig=/root/kubeconfig.yaml

if [ -z "$HELM_HOME" ]; then
   echo "HELM_HOME doesn't exist, creating one now"
   export HELM_HOME=~/.helm
   mkdir -p ${HELM_HOME}
fi
if [ ! -f $HELM_HOME/key.pem ] || [ ! -f $HELM_HOME/cert.pem ] || [ ! -f $HELM_HOME/ca.pem ]; then
   echo "Fetching ca.crt and ca.key for your cluster"
   kubectl -n kube-system get secret cluster-ca-cert -o jsonpath='{.data.tls\.crt}' | base64 --decode > $HELM_HOME/ca.crt
   kubectl -n kube-system get secret cluster-ca-cert -o jsonpath='{.data.tls\.key}' | base64 --decode > $HELM_HOME/ca.key
   echo "key.pem does not exist in $HELM_HOME, creating key.pem and cert.pem, ca.pem using the new key.pem"
   openssl genrsa -out $HELM_HOME/key.pem 4096
   openssl req -new -key $HELM_HOME/key.pem -out $HELM_HOME/csr.pem -subj "/C=US/ST=New York/L=Armonk/O=IBM Cloud Private/CN=admin"
   openssl x509 -req -in $HELM_HOME/csr.pem -extensions v3_usr -CA $HELM_HOME/ca.crt -CAkey $HELM_HOME/ca.key -CAcreateserial -out $HELM_HOME/cert.pem
   openssl x509 -in $HELM_HOME/ca.crt -out $HELM_HOME/ca.pem -outform PEM
fi

echo "Creating helm tls secret for helm install"
oc create secret generic task-helm-tls --from-file=key=$HELM_HOME/key.pem --from-file=cert=$HELM_HOME/cert.pem --from-file=ca=ca.pem --dry-run -o yaml | oc apply -f -
