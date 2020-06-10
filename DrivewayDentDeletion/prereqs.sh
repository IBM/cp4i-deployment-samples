#!/bin/bash
export NAMESPACE=driveway-dent-deletion

oc apply --filename https://storage.googleapis.com/tekton-releases/pipeline/previous/v0.12.1/release.yaml
oc wait -n tekton-pipelines --for=condition=available deployment --timeout=20m tekton-pipelines-controller tekton-pipelines-webhook

oc apply -f https://storage.googleapis.com/tekton-releases/triggers/previous/v0.5.0/release.yaml

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
