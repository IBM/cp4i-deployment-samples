#!/bin/bash

# build.sh [repository]
# Build the Bookshop client image and push to the specified repository.
# You must already be logged in to the repository.
# Provide the full path to the repository where the images will be pushed

script="$(basename $0)"
cd $(dirname $0)/..
echo $PWD
repository=""
using_main_branch=true

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
branch=$(git rev-parse --abbrev-ref HEAD)
if [[ "${branch}" != "main" ]]; then
  tag="${tag}-${branch}"
  using_main_branch=false
fi

echo "Using repository $repository"

# build image, (retag as latest) and push to the specified repository

image=${repository}/client:${tag}
docker build -t ${image} . || exit 1
docker push ${image} || exit 1

if [[ "${using_main_branch}" == true ]]; then
  latest=${repository}/client:latest
  docker tag ${image} ${latest} || exit 1
  docker push ${latest} || exit 1
fi

echo -e "\nImages:"
$using_main_branch && echo ${latest}
echo ${image}

echo -e "\nImage tags:"
$using_main_branch && echo "latest"
echo ${tag}
