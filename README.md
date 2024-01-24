# cp4i-deployment-samples

Deploys a base of Cloud Pak for Integration. Installs the operators of each of the products and creates a Platform Navigator.

# How to find the username and password for the Navigator
Username CLI command:

`oc get secret integration-admin-initial-temporary-credentials -n <namespace> -o jsonpath='{.data.username}' | base64 --decode`

Password CLI command:

`oc get secret integration-admin-initial-temporary-credentials -n <namespace> -o jsonpath='{.data.password}' | base64 --decode`