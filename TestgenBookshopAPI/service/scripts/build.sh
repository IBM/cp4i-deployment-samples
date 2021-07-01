#!/bin/bash

# build.sh [repository]
# Build the Bookshop images and push them to the specified repository.
# You must already be logged in to the repository.

cd $(dirname $0)
script="$(basename $0)"
repository=""

USAGE="Usage:
  ${script} <repository>
"

function usage {
  local msg="$1"
  echo && echo "${msg}" >&2
  echo && echo "${USAGE}" >&2
  exit 2
}

while [[ $# > 0 ]]; do
  case "$1" in
  -*)
    usage "Unrecognised option: $1"
    ;;
  *)
    repository=$1
    shift
    ;;
  esac
done

if [[ -z "${repository}" ]]; then
  usage "repository is required"
fi

tag=$(date +"%Y-%m-%d-%H%M")
branch=$(git branch --show-current)
if [[ "${branch}" != main ]]; then
  tag="${tag}-${branch}"
fi

echo $repository
echo $api_key
echo $tag

exit 1

# build images, retag as latest and push all to the specified repository

image=${repository}/books-service:${tag}
latest=${repository}/books-service:latest
docker build -t ${image} --build-arg SRC_DIR=books-microservice . || exit 1
docker tag ${image} ${latest} || exit 1
images="${images} ${image} ${latest}"

image=${repository}/customer-order-service:${tag}
latest=${repository}/customer-order-service:latest
docker build -t ${image} --build-arg SRC_DIR=customer-microservice . || exit 1
docker tag ${image} ${latest} || exit 1
images="${images} ${image} ${latest}"

image=${repository}/bookshop-services:${tag}
latest=${repository}/bookshop-services:latest
docker build -t ${image} --build-arg SRC_DIR=services . || exit 1
docker tag ${image} ${latest} || exit 1
images="${images} ${image} ${latest}"

image=${repository}/gateway-service:${tag}
latest=${repository}/gateway-service:latest
docker build -t ${image} --build-arg SRC_DIR=gateway-service . || exit 1
docker tag ${image} ${latest} || exit 1
images="${images} ${image} ${latest}"

# push to repository if not local
if [[ ${repository} == *.* ]]; then
  for image in ${images}; do
    docker push ${image}
  done
fi

echo "Image tag: '${tag}'"
echo "Image tag: 'latest'"
echo ${images}
