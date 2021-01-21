# Overview
[This script](setup-demos.sh) is used to install and setup the required addons, products and demos on a cluster with CP4I already setup on it. Addons and products for a demo will automatically be installed and setup via this script. Additional addons and products can also be setup apart from the ones required by the demos.

The demo script enables to install and setup the following demos:
- Cognitive Car Repair Demo
- Driveway Dent Deletion Demo
- Event Enabled Insurance Demo
- Mapping Assist Demo
- Weather Chatbot Demo
<br /><br />

# Prerequisites
- A cluster with CP4I and Platform navigator already setup on it
  - If it is an AWS cluster, a small size with 3 workers of size m5.8xlarge and 3 masters of size m5.xlarge is needed
  - If it is an AWS cluster, 3 worker nodes of configuration 32 vCPU and Memory of 128 GB is needed

  Note: Different instance sizes for AWS instances can be found [here](https://aws.amazon.com/ec2/instance-types/)

- If the cluster is an AWS cluster, then EFS storage class should be setup on it as it is used as the file storage class for the demos
- Logged into the cluster via `oc`
- Following cli tools setup:
  - `jq`
  - `yq` (if the input file is a `yaml` file)
  - `oc`
- The CP4I can be setup as either namespace or cluster scoped.

  If the CP4I is installed as cluster scoped, then:
  - The namespace where the demos is to be setup should exist on the cluster
  - The namespace where the demos is to be setup should have a secret that will be used to pull images from the Entitled Registry

  If the CP4I is installed as namespace scoped, then:
  - The namespace where the demos is to be setup must be the same as CP4I/Platform Navigator.
- Keytool is needed on the client side where the script is run, if the Event Enabled Insurance demo is to be setup. This can be setup by installing Open Java JDK.
<br /><br />

# Example INPUT FILE for the script:
The script takes an input `yaml` or `json` file specifying the following:
  - Addons
  - Products
  - Demos
  - [Samples Repository](https://github.com/IBM/cp4i-deployment-samples) branch
  - File storage class
  - Block storage class
  - Namespace for installing everything
  - APIC configuration parameters

An example `yaml` input file for the script:
```yaml
apiVersion: integration.ibm.com/v1beta1
kind: Demo
metadata:
  namespace: cp4i
  name: demos
spec:
  general:
    storage:
      block:
        class: cp4i-block-performance
      file:
        class: ibmc-file-gold-gid
    samplesRepoBranch: main

  apic:
    emailAddress: "your@email.address"
    mailServerHost: "smtp.mailtrap.io"
    mailServerPort: 2525
    mailServerUsername: "<your-username>"
    mailServerPassword: "<your-password>"

  demos:
    all: true
    cognitiveCarRepair: true
    drivewayDentDeletion: true
    eventEnabledInsurance: true
    mappingAssist: true
    weatherChatbot: true

  # Allow products to be enabled independently. Enabling a demo will automatically
  # enable required products.
  products:
    aceDashboard: false
    aceDesigner: false
    apic: false
    assetRepo: false
    eventStreams: false
    mq: false
    tracing: false

  # Allow additional addon applications to be enabled independently. Enabling a
  # demo will automatically enable required addons.
  addons:
    postgres: false
    elasticSearch: false
    # Installs the pipelines operator cluster scoped regardless if the CP4I was setup namespace scoped
    ocpPipelines: false
```
<br /><br />

# Running the test script
- Run the [demos script script](setup-demos.sh) with `INPUT-FILE` file (in `yaml` or `json` format) and an `OUTPUT-FILE` file (in `yaml` or `json` format) parameter:
    ```
    ./setup-demos.sh -i <INPUT-FILE> -o <OUTPUT-FILE>
    ```
- If either of the parameters are not provided, the script will not run, returning an appropriate error.
<br /><br />

# Working of the demo script
The demo script does the following actions sequentially:
- Validate the input parameters passed in
- Validate if required tools are setup
- Read and convert input file to json (if `yaml`), extract and display necessary information from it
- For each demo, parse to add to the `requiredAddons` and `requiredProducts` lists
- Check if the namespace and the required secret exists
- Setup and configure the required addons
- Install the selected and required products
- Register tracing if tracing is amongst the selected products
- Configure APIC if it is amongst the selected product. Tracing registration is a pre-req for this step.
- If asset repository is enabled, create Asset Repository remote
- Setup the required demos
- All above steps keeps the status array updated at all times
- Print the names of the addons, products and demos that failed to install if any
- Exit only if any one of the previous step(s) (addons/products/demos) changed the phase to Failed
- Change final status to Running at end of installation if nothing fails

Note: If the `DEBUG` is set to true in the script, it will print debug logs, final status at the end of the installation along with the total time taken for the run.
<br /><br />

# Stopping the test script
- To stop the script at any point after starting, press `ctrl` + `c` before it finishes execution.
<br /><br />

# NOTE:
- The CP4I products and the demos together with a basic level of automated test for Driveway Dent Deletion can be done by running the [1-click script](1-click-install.sh) and passing the right parameters to it.
- This demo script is already live on ROKS via the 1-click [here](https://cloud.ibm.com/catalog/content/ibm-cp-integration-72f63273-f2f6-4e9c-8626-60fe798c57be-global).