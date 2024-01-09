# cp4i-deployment-samples

Samples for deploying Cloud Pak for Integration capabilities in a pipeline.

These samples are aimed at providing a way to quickly configure CP4I for running demos and exploring functionality. They are not designed for production use.
# Demo script Usage
Instructions on how to use demo script can be found [here](products/bash/setup-demos-readme.md).

# How to find the username and password for the Navigator
Username CLI command:

`oc get secret integration-admin-initial-temporary-credentials -n <namespace> -o jsonpath='{.data.username}' | base64 --decode`

Password CLI command:

`oc get secret integration-admin-initial-temporary-credentials -n <namespace> -o jsonpath='{.data.password}' | base64 --decode`