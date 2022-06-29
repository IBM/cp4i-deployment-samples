# Overview
The `create-catalog-sources.sh` script in the parent dir contains a whole bunch of environment
variables that define the catalog name, image, and display name. I.e. something like:
```sh
WML_TRAINING_CATALOG_NAME=ibm-ai-wmltraining-catalog
WML_TRAINING_CATALOG_IMAGE=icr.io/cpopen/ibm-ai-wmltraining-operator-catalog@sha256:4e88b9f2df60be6af156d188657763dfa4cbe074c40ea85ba82858796e3cd6a3
WML_TRAINING_CATALOG_DISPLAY_NAME="WML Training Operators 1.1.1"
...
MQ_CATALOG_NAME=mq-operators
MQ_CATALOG_IMAGE=icr.io/cpopen/ibm-mq-operator-catalog@sha256:8ad0fe91b535b6169933b0270ea7266fcaf73173f26ea17bb50255c39d5b2aa6
MQ_CATALOG_DISPLAY_NAME="MQ Operators 1.8.1"
```

This list needs to be re-calculated for each new release of CP4I and doing this manually is a pain,
so this dir provides some scripts to help do this.

## find-catalog-images.sh
This is the main script which finds the latest catalog images for all CP4I cases. I.e.:
```
./find-catalog-images.sh
```

If this script works then the output can be copied straight into `create-catalog-sources.sh`, job
done!

If there are problems with dependency changes (either addition or removal) then this script will
output error messages and the problems will need to be fixed, see the following sections:

### Dependencies added
If the CASE contains a dependency not currently supported then a line such as the following will be
output:
```
Found the following in the list of catalog images but not supported by create-catalog-sources.sh:
  icr.io,cpopen/ibm-mq-operator-catalog,v1.8.1-amd64,sha256:8ad0fe91b535b6169933b0270ea7266fcaf73173f26ea17bb50255c39d5b2aa6,IMAGE,linux,amd64,"",0,CASE,olm-catalog,""
```
To fix this:
1) Add the new dependency to `find-catalog-images.sh` in the json for `FIXED_DATA_JSON`
2) Edit `../create-catalog-sources.sh` to add the new envs and to use them (calling `create_catalog_source`)
3) Edit `../deploy-og-sub.sh` to create the subscription and wait for it at the appropriate place, before any operator that depends on it is installed.

### Dependencies removed
If the CASE has had a dependency removed then a line such as the following will be output:
```
  Catalog image not found for catalog: ibm-mq-operator-catalog
```
To fix this:
1) Remove the dependencies' entry from `find-catalog-images.sh` in the json for `FIXED_DATA_JSON`
2) Edit `../create-catalog-sources.sh` to remove the new envs and to stop using them (remove the call to `create_catalog_source`)
3) Edit `../deploy-og-sub.sh` to remove references to the operator subscription and avoid waiting for it.

## get-latest.sh
This finds the latest CASE version for ibm-cp-integration.

## list-versions.sh
This gets a list of all CASE versions for ibm-cp-integration.
