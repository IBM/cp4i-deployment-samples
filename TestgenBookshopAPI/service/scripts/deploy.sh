#!/bin/bash

# deploy.sh [options] [repository]
# Deploy the Bookshop from the specified repository.
# You must already be logged in to the repository.
# The default repository is the IBM icr.io/integration repository.
# If a custom repository is mentioned, it should be the complete path leaving out the image name

cd $(dirname $0)/../deploy

script="$(basename $0)"

USAGE="Usage:
  ${script} [options] [repository]

Common options:
  -h, --help
  -t, --tag TAG
  -n, --namespace NAMESPACE
  --jaeger-endpoint URL
  --language LANG
"

function usage {
  local msg="$1"
  echo "${msg}" >&2
  echo "${USAGE}" >&2
  exit 2
}

tag="latest"

while [[ $# > 0 ]]; do
  case "$1" in
  -t | --tag)
    tag=$2
    shift 2 || usage "Missing tag"
    ;;
  -n | --namespace)
    namespace=$2
    shift 2 || usage "Missing namespace"
    ;;
  --jaeger-endpoint)
    jaeger_endpoint=$2
    shift 2 || usage "Missing Jaeger endpoint URL"
    ;;
  --language)
    language=$2
    shift 2 || usage "Missing language"
    ;;
  -h | --help)
    echo "${USAGE}"
    exit 0
    ;;
  -*)
    usage "Unrecognised option: $1"
    ;;
  *)
    repository=$1
    shift
    ;;
  esac
done

echo "Using image tag ${tag}"

echo "Checking if 'oc' CLI is installed and you are connected to a cluster"
if ! oc projects >/dev/null 2>&1; then
  echo "oc is either not installed or you are not logged in to the cluster, exiting now"
  exit 1
fi

namespace=${namespace:-$(oc project -q)}
echo "Using namespace ${namespace}"

language=${language:-fr}
echo "Using language ${language}"

repository=${repository:-icr.io/integration/bookshop-api}
echo "Using repository ${repository}"

jaeger_endpoint=${jaeger_endpoint:-http://jaeger-bookshop-collector:14268/api/traces}
echo "Using Jaeger endpoint ${jaeger_endpoint}"

books_tag=${tag}
customers_tag=${tag}
services_tag=${tag}
gateway_tag=${tag}

echo "Using images:"
echo "  books-service:${books_tag}"
echo "  customer-order-service:${customers_tag}"
echo "  bookshop-services:${services_tag}"
echo "  gateway-service:${gateway_tag}"

function deploy {
  local tag=$1
  local service=$2
  for resource in deployment service route; do
    file=${service}/${resource}.yaml
    if [[ -f ${file} ]]; then
      sed -e "s&{{NAMESPACE}}&${namespace}&g" \
        -e "s&{{REPOSITORY}}&${repository}&g" \
        -e "s&{{TAG}}&${tag}&g" \
        -e "s&{{JAEGER_ENDPOINT}}&${jaeger_endpoint}&g" \
        -e "s&{{LANGUAGE}}&${actual_language}&g" \
        -e "s&{{LANGUAGES}}&${service_lang}&g" \
        -e "s&{{ALL_LANGUAGE}}&${language}&g" \
        ${file} |
        oc apply -f -
    fi
  done
}

echo "Deploying default books-service..."
actual_language=""
service_lang="en"
deploy "${books_tag}" books-service

for lang in $language; do
  echo "Deploying ${lang} books-service..."
  actual_language="$lang-"
  service_lang="$lang"
  deploy "${books_tag}" books-service
done

echo "Deploying customer-order-service..."
deploy "${customers_tag}" customer-order-service

echo "Deploying services..."
deploy "${services_tag}" services

echo "Deploying gateway..."
deploy ${gateway_tag} gateway-service

echo "Exposing the Jaeger Query API..."
sed -e "s&{{NAMESPACE}}&${namespace}&g" \
  jaeger-query-api.yaml |
  oc apply -f -
