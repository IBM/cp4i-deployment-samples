#!/bin/bash
CASE_REPO_PATH=https://github.com/IBM/cloud-pak/raw/master/repo/case
CASE_NAME=ibm-cp-integration
CASE_VERSION=$(curl -s https://raw.githubusercontent.com/IBM/cloud-pak/master/repo/case/ibm-cp-integration/index.yaml | grep "appVersion: $VERSION" -B 1 | grep -v appVersion | tr -d " :" | sort --version-sort | tail -n 1)
echo ${CASE_VERSION}
