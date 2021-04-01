#!/bin/bash
#******************************************************************************
# Licensed Materials - Property of IBM
# (c) Copyright IBM Corporation 2020. All Rights Reserved.
#
# Note to U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.
#******************************************************************************

#******************************************************************************

CURRENT_DIR=$(dirname $0)

while getopts "i:o:" opt; do
  case ${opt} in
  i)
    in_file="$OPTARG"
    ;;
  o)
    out_file="$OPTARG"
    ;;
  \?)
    usage
    exit
    ;;
  esac
done

echo "${in_file}"
echo "${out_file}"


git clone --branch main https://github.com/IBM/cp4i-deployment-samples.git /code-repo
echo "PWD: $PWD"
echo "CURRENT_DIR: $CURRENT_DIR"
echo ls
if ! $CURRENT_DIR/code-repo/products/bash/setup-demos.sh -i ${in_file} -o ${out_file} ; then
echo "Failed to start setup-demos.sh"
exit 1
fi

