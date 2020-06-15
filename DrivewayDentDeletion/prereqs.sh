#!/bin/bash
export NAMESPACE=driveway-dent-deletion
export ER_REGISTRY=$(oc get secret -n mq ibm-entitlement-key -o json | jq -r '.data.".dockerconfigjson"' | base64 --decode | jq -r '.auths' | jq 'keys[]' | tr -d '"')
export ER_USERNAME=$(oc get secret -n mq ibm-entitlement-key -o json | jq -r '.data.".dockerconfigjson"' | base64 --decode | jq -r '.auths."cp.icr.io".username')
export ER_PASSWORD=$(oc get secret -n mq ibm-entitlement-key -o json | jq -r '.data.".dockerconfigjson"' | base64 --decode | jq -r '.auths."cp.icr.io".password')

oc apply --filename https://storage.googleapis.com/tekton-releases/pipeline/previous/v0.12.1/release.yaml
oc apply -f https://storage.googleapis.com/tekton-releases/triggers/previous/v0.5.0/release.yaml
oc wait -n tekton-pipelines --for=condition=available deployment --timeout=20m tekton-pipelines-controller tekton-pipelines-webhook tekton-triggers-controller tekton-triggers-webhook

oc create namespace ${NAMESPACE}
oc adm policy add-scc-to-group privileged system:serviceaccounts:$NAMESPACE

export DOCKER_REGISTRY="image-registry.openshift-image-registry.svc:5000"
export username=image-bot

declare -a image_projects=("ace" "mq")
for image_project in "${image_projects[@]}"
do
  kubectl -n ${image_project} create serviceaccount image-bot
  oc -n ${image_project} policy add-role-to-user registry-editor system:serviceaccount:${image_project}:image-bot

  export password="$(oc -n ${image_project} serviceaccounts get-token image-bot)"

  oc create -n $NAMESPACE secret docker-registry cicd-${image_project} \
    --docker-server=$DOCKER_REGISTRY --docker-username=$username --docker-password=$password \
    --dry-run -o yaml | oc apply -f -
done

# oc get secret -n mq ibm-entitlement-key --export -o yaml | oc apply -n=${NAMESPACE} -f -

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

# oc create secret generic cluster-kubeconfig --from-file=kubeconfig=/root/kubeconfig.yaml
# oc create secret generic task-helm-tls --from-file=key=$HELM_HOME/key.pem --from-file=cert=$HELM_HOME/cert.pem --from-file=ca=ca.pem --dry-run -o yaml | oc apply -f -
