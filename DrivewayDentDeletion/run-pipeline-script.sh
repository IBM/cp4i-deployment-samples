#!/bin/bash -e

#install tekton
# oc apply --filename https://storage.googleapis.com/tekton-releases/pipeline/previous/v0.12.1/release.yaml
# kubectl get pods --namespace tekton-pipelines --watch

#for linux - local install
# curl -LO https://github.com/tektoncd/cli/releases/download/v0.9.0/tkn_0.9.0_Linux_x86_64.tar.gz
# sudo tar xvzf tkn_0.9.0_Linux_arm64.tar.gz -C /usr/local/bin/ tkn

# # export ICP_CONSOLE="$(oc get routes --all-namespaces | grep icp-console | awk '{print $3}')"

# # cloudctl login -a $ICP_CONSOLE -u admin -p ibm-cloud-private-admin-password -n ace

# oc patch configs.imageregistry.operator.openshift.io/cluster --patch '{"spec":{"defaultRoute":true}}' --type=merge

# export NAMESPACE=ace

# kubectl -n $NAMESPACE create serviceaccount image-bot

# oc -n $NAMESPACE policy add-role-to-user registry-editor system:serviceaccount:$NAMESPACE:image-bot

# export DOCKER_REGISTRY="$(kubectl get route -n openshift-image-registry default-route -o jsonpath='{.spec.host}')"

# export INTERNAL_REGISTRY="image-registry.openshift-image-registry.svc:5000/$NAMESPACE"

# echo $DOCKER_REGISTRY  #include this registry in insecure registries in docker preferences

# export username=image-bot

# export password="$(oc -n $NAMESPACE serviceaccounts get-token image-bot)"

# docker login -u $username -p $password $DOCKER_REGISTRY

# oc adm policy add-scc-to-group privileged system:serviceaccounts:$NAMESPACE

# oc create secret docker-registry cicd-ace --docker-server=$DOCKER_REGISTRY --docker-username=$username --docker-password=$password


tkn resource delete --all -f
tkn tasks delete --all -f
tkn taskruns delete --all -f
tkn pipelines delete --all -f
tkn pipelineruns delete --all -f
tkn eventlisteners delete --all -f
tkn triggerbindings delete --all -f
tkn triggertemplate delete --all -f
oc delete rolebinding tekton-triggers-rolebinding
oc delete role tekton-triggers-role

oc apply -f cicd-webhook-triggers.yaml


# EXECCUTOR COMMAND Usage:
#   executor [flags]
#   executor [command]

# Available Commands:
#   help        Help about any command
#   version     Print the version number of kaniko

# Flags:
#       --build-arg multi-arg type                  This flag allows you to pass in ARG values at build time. Set it repeatedly for multiple values.
#       --cache                                     Use cache when building image
#       --cache-dir string                          Specify a local directory to use as a cache. (default "/cache")
#       --cache-repo string                         Specify a repository to use as a cache, otherwise one will be inferred from the destination provided
#       --cache-ttl duration                        Cache timeout in hours. Defaults to two weeks. (default 336h0m0s)
#       --cleanup                                   Clean the filesystem at the end
#   -c, --context string                            Path to the dockerfile build context. (default "/workspace/")
#       --context-sub-path string                   Sub path within the given context.
#   -d, --destination multi-arg type                Registry the final image should be pushed to. Set it repeatedly for multiple destinations.
#       --digest-file string                        Specify a file to save the digest of the built image to.
#   -f, --dockerfile string                         Path to the dockerfile to be built. (default "Dockerfile")
#       --force                                     Force building outside of a container
#   -h, --help                                      help for executor
#       --image-name-with-digest-file string        Specify a file to save the image name w/ digest of the built image to.
#       --insecure                                  Push to insecure registry using plain HTTP
#       --insecure-pull                             Pull from insecure registry using plain HTTP
#       --insecure-registry multi-arg type          Insecure registry using plain HTTP to push and pull. Set it repeatedly for multiple registries.
#       --label multi-arg type                      Set metadata for an image. Set it repeatedly for multiple labels.
#       --log-format string                         Log format (text, color, json) (default "color")
#       --log-timestamp                             Timestamp in log output
#       --no-push                                   Do not push the image to the registry
#       --oci-layout-path string                    Path to save the OCI image layout of the built image.
#       --registry-certificate key-value-arg type   Use the provided certificate for TLS communication with the given registry. Expected format is 'my.registry.url=/path/to/the/server/certificate'.
#       --registry-mirror string                    Registry mirror to use has pull-through cache instead of docker.io.
#       --reproducible                              Strip timestamps out of the image to make it reproducible
#       --single-snapshot                           Take a single snapshot at the end of the build.
#       --skip-tls-verify                           Push to insecure registry ignoring TLS verify
#       --skip-tls-verify-pull                      Pull from insecure registry ignoring TLS verify
#       --skip-tls-verify-registry multi-arg type   Insecure registry ignoring TLS verify to push and pull. Set it repeatedly for multiple registries.
#       --skip-unused-stages                        Build only used stages if defined to true. Otherwise it builds by default all stages, even the unnecessaries ones until it reaches the target stage / end of Dockerfile
#       --snapshotMode string                       Change the file attributes inspected during snapshotting (default "full")
#       --tarPath string                            Path to save the image in as a tarball instead of pushing
#       --target string                             Set the target build stage to build
#   -v, --verbosity string                          Log level (trace, debug, info, warn, error, fatal, panic) (default "info")
#       --whitelist-var-run                         Ignore /var/run directory when taking image snapshot. Set it to false to preserve /var/run/ in destination image. (Default true). (default true)

# Use "executor [command] --help" for more information about a command.