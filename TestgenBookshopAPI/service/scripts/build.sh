#!/bin/bash

# build.sh [repository]
# Build the Bookshop images and push them to the specified repository.
# You must already be logged in to the repository.
# Provide the full path to the repository where the images will be pushed

script="$(basename $0)"
repository=""
using_main_branch=false

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
else
  using_main_branch=true
fi

echo "Using repository $repository"

# build images, retag as latest and push all to the specified repository

image=${repository}/books-service:${tag}
docker build -t ${image} --build-arg SRC_DIR=books-microservice . || exit 1
if [[ "$using_main_branch" == true ]]; then
  latest=${repository}/books-service:latest
  docker tag ${image} ${latest} || exit 1
  images="${images} ${image} ${latest}"
else
  images="${images} ${image}"
fi

image=${repository}/customer-order-service:${tag}
docker build -t ${image} --build-arg SRC_DIR=customer-microservice . || exit 1
if [[ "$using_main_branch" == true ]]; then
  latest=${repository}/customer-order-service:latest
  docker tag ${image} ${latest} || exit 1
  images="${images} ${image} ${latest}"
else
  images="${images} ${image}"
fi

image=${repository}/bookshop-services:${tag}
docker build -t ${image} --build-arg SRC_DIR=services . || exit 1
if [[ "$using_main_branch" == true ]]; then
  latest=${repository}/bookshop-services:latest
  docker tag ${image} ${latest} || exit 1
  images="${images} ${image} ${latest}"
else
  images="${images} ${image}"
fi

image=${repository}/gateway-service:${tag}
docker build -t ${image} --build-arg SRC_DIR=gateway-service . || exit 1
if [[ "$using_main_branch" == true ]]; then
  latest=${repository}/gateway-service:latest
  docker tag ${image} ${latest} || exit 1
  images="${images} ${image} ${latest}"
else
  images="${images} ${image}"
fi

# push to repository if not local
if [[ ${repository} == *.* ]]; then
  for image in ${images}; do
    docker push ${image}
  done
fi

echo -e "\nImage tag: '${tag}'"
$using_main_branch && echo -e "Latest image tag: 'latest'"

for image in ${images}; do
  echo ${image}
done
