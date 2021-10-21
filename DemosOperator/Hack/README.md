# IBM Cloud Pak for Integration Demos Operator
## Development build/test/use
### Update the deep copy code
After modifying the *_types.go file always run the following command to update the generated code for that resource type:
```bash
$ make generate
go: creating new go.mod: module tmp
go: found sigs.k8s.io/controller-tools/cmd/controller-gen in sigs.k8s.io/controller-tools v0.3.0
/Users/daniel.pinkuk.ibm.com/go/bin/controller-gen object:headerFile="hack/boilerplate.go.txt" paths="./..."
```
### Update CRD from *_types.go code
Once the API is defined with spec/status fields and CRD validation markers, the CRD manifests can be generated and updated with the following command:
```bash
$ make manifests
go: creating new go.mod: module tmp
go: found sigs.k8s.io/controller-tools/cmd/controller-gen in sigs.k8s.io/controller-tools v0.3.0
/Users/daniel.pinkuk.ibm.com/go/bin/controller-gen "crd:trivialVersions=true" rbac:roleName=manager-role webhook paths="./..." output:crd:artifacts:config=config/crd/bases
```

### Run the operator locally without OLM
This is to run the operator on your local dev env and have it connected to a remote cluster. This involves applying the CRD yaml
to the cluster, then running the operator which will monitor the cluster for CR changes.
#### Register CRD
Before running the operator, the CRD must be registered with the Kubernetes apiserver. Connect to a cluster then run the following to install the CRD:
```bash
$ make install
go: creating new go.mod: module tmp
go: found sigs.k8s.io/controller-tools/cmd/controller-gen in sigs.k8s.io/controller-tools v0.3.0
/Users/daniel.pinkuk.ibm.com/go/bin/controller-gen "crd:trivialVersions=true" rbac:roleName=manager-role webhook paths="./..." output:crd:artifacts:config=config/crd/bases
/usr/local/bin/kustomize build config/crd | kubectl apply -f -
I1109 15:36:12.139652   79334 request.go:621] Throttling request took 1.08813123s, request: GET:https://c100-e.eu-gb.containers.cloud.ibm.com:30797/apis/ibmcpcs.ibm.com/v1?timeout=32s
customresourcedefinition.apiextensions.k8s.io/demos.integration.ibm.com created
```
#### Run the operator
To run the operator locally connected to your cluster set the `SETUP_DEMOS_SCRIPT` to point to your local copy of the setup-demos.sh script and then use `make run` to run the operator:
```bash
$ export SETUP_DEMOS_SCRIPT="/Users/daniel.pinkuk.ibm.com/Documents/git/IBM-public/cp4i-deployment-samples/products/bash/setup-demos.sh"
$ make run ENABLE_WEBHOOKS=false
go: creating new go.mod: module tmp
go: found sigs.k8s.io/controller-tools/cmd/controller-gen in sigs.k8s.io/controller-tools v0.3.0
/Users/daniel.pinkuk.ibm.com/go/bin/controller-gen object:headerFile="hack/boilerplate.go.txt" paths="./..."
go fmt ./...
go vet ./...
/Users/daniel.pinkuk.ibm.com/go/bin/controller-gen "crd:trivialVersions=true" rbac:roleName=manager-role webhook paths="./..." output:crd:artifacts:config=config/crd/bases
go run ./main.go
I1109 15:50:38.865745   80101 request.go:621] Throttling request took 1.019427629s, request: GET:https://c100-e.eu-gb.containers.cloud.ibm.com:30797/apis/coordination.k8s.io/v1beta1?timeout=32s
2020-11-09T15:50:41.639Z	INFO	controller-runtime.metrics	metrics server is starting to listen	{"addr": ":8080"}
2020-11-09T15:50:41.640Z	INFO	setup	starting manager
2020-11-09T15:50:41.640Z	INFO	controller-runtime.manager	starting metrics server	{"path": "/metrics"}
2020-11-09T15:50:41.640Z	INFO	controller	Starting EventSource	{"reconcilerGroup": "integration.ibm.com", "reconcilerKind": "Demo", "controller": "demo", "source": "kind source: /, Kind="}
2020-11-09T15:50:41.740Z	INFO	controller	Starting Controller	{"reconcilerGroup": "integration.ibm.com", "reconcilerKind": "Demo", "controller": "demo"}
2020-11-09T15:50:41.740Z	INFO	controller	Starting workers	{"reconcilerGroup": "integration.ibm.com", "reconcilerKind": "Demo", "controller": "demo", "worker count": 1}
```

To test create a CR in the namespace being monitored:
```bash
cat << EOF | oc apply -f -
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

  apic:
    emailAddress: "your@email.address"
    mailServerHost: "smtp.mailtrap.io"
    mailServerPort: 2525
    mailServerUsername: "<your-username>"
    mailServerPassword: "<your-password>"

  demos:
    all: false
    cognitiveCarRepair: true
    drivewayDentDeletion: false
    eventEnabledInsurance: false
    mappingAssist: false
    weatherChatbot: false

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
    # Installs the pipelines operator cluster scoped
    ocpPipelines: false
EOF

```
If the operator is running something like the following should appear in the logs:
```
2020-11-12T11:39:18.608Z	INFO	controllers.Demo	jsonCmd: oc get demo -n cp4i demo-sample -o json > /var/folders/pz/476tpvhd4q1blkjfgynl9zsw0000gn/T/in802445183.json

-------------------------------------------------------------------------------------------------------------------

ℹ Script directory: '/Users/daniel.pinkuk.ibm.com/Documents/git/IBM-public/cp4i-deployment-samples/products/bash'
ℹ Input yaml file: '/var/folders/pz/476tpvhd4q1blkjfgynl9zsw0000gn/T/in802445183.json'
ℹ Output yaml file : '/var/folders/pz/476tpvhd4q1blkjfgynl9zsw0000gn/T/out037254866.json'

yq version 2.4.1
jq-1.6
Client Version: openshift-clients-4.5.0-202006231303.p0-16-g3f6a83fb7
[DEBUG] Got the following JSON for /var/folders/pz/476tpvhd4q1blkjfgynl9zsw0000gn/T/in802445183.json:
{
  "apiVersion": "integration.ibm.com/v1beta1",
  "kind": "Demo",
  "metadata": {
    "annotations": {
      "kubectl.kubernetes.io/last-applied-configuration": "{\"apiVersion\":\"integration.ibm.com/v1beta1\",\"kind\":\"Demo\",\"metadata\":{\"annotations\":{},\"name\":\"demo-sample\",\"namespace\":\"cp4i\"},\"spec\":{\"demos\":{\"cognitiveCarRepair\":{\"enabled\":true}}}}\n"
    },
    "creationTimestamp": "2020-11-12T11:39:18Z",
    "generation": 1,
    "managedFields": [
      {
        "apiVersion": "integration.ibm.com/v1beta1",
        "fieldsType": "FieldsV1",
        "fieldsV1": {
          "f:metadata": {
            "f:annotations": {
              ".": {},
              "f:kubectl.kubernetes.io/last-applied-configuration": {}
            }
          },
          "f:spec": {
            ".": {},
            "f:demos": {
              ".": {},
              "f:cognitiveCarRepair": {
                ".": {},
                "f:enabled": {}
              }
            }
          }
        },
        "manager": "oc",
        "operation": "Update",
        "time": "2020-11-12T11:39:18Z"
      }
    ],
    "name": "demo-sample",
    "namespace": "cp4i",
    "resourceVersion": "4270466",
    "selfLink": "/apis/integration.ibm.com/v1beta1/namespaces/cp4i/demos/demo-sample",
    "uid": "a6ce02d4-aa7f-4331-84cc-8aabe398268b"
  },
  "spec": {
    "demos": {
      "cognitiveCarRepair": {
        "enabled": true
      }
    }
  }
}
[DEBUG] Get storage classes and branch from /var/folders/pz/476tpvhd4q1blkjfgynl9zsw0000gn/T/in802445183.json

ℹ Block storage class: 'cp4i-block-performance'
ℹ File storage class: 'ibmc-file-gold-gid'
ℹ Samples repo branch: 'main'
ℹ Namespace: 'cp4i'

-------------------------------------------------------------------------------------------------------------------

ℹ All demos enabled: 'false'

-------------------------------------------------------------------------------------------------------------------

ℹ [INFO] Changing the status to 'Pending' as installation is starting...

-------------------------------------------------------------------------------------------------------------------

ℹ [INFO] update_phase(): phase(Pending)

-------------------------------------------------------------------------------------------------------------------

ℹ [INFO] Check if the 'cp4i' namespace and the secret 'ibm-entitlement-key' exists...

✅ [SUCCESS] Namespace 'cp4i' exists

-------------------------------------------------------------------------------------------------------------------

ℹ [INFO] Current installation phase is 'Pending', continuing the installation...

-------------------------------------------------------------------------------------------------------------------

✅ [SUCCESS] Secret 'ibm-entitlement-key' exists in the 'cp4i' namespace

-------------------------------------------------------------------------------------------------------------------

ℹ [INFO] Current installation phase is 'Pending', continuing the installation...

-------------------------------------------------------------------------------------------------------------------

ℹ [INFO] Installing and setting up addons:

-------------------------------------------------------------------------------------------------------------------

Namespaces:
cp4i

-------------------------------------------------------------------------------------------------------------------

Products:
{
  "enabled": true,
  "type": "aceDashboard",
  "name": "ace-dashboard-demo",
  "namespace": "cp4i"
}
{
  "enabled": true,
  "type": "aceDesigner",
  "name": "ace-designer-demo",
  "namespace": "cp4i"
}
{
  "enabled": true,
  "type": "apic",
  "name": "ademo",
  "emailAddress": "your@email.address",
  "mailServerHost": "smtp.mailtrap.io",
  "mailServerPassword": "<your-password>",
  "mailServerPort": 2525,
  "mailServerUsername": "<your-username>",
  "namespace": "cp4i"
}
{
  "enabled": true,
  "type": "assetRepo",
  "name": "ar-demo",
  "namespace": "cp4i"
}
{
  "enabled": true,
  "type": "tracing",
  "name": "tracing-demo",
  "namespace": "cp4i"
}

-------------------------------------------------------------------------------------------------------------------

Demos:
cognitiveCarRepair

-------------------------------------------------------------------------------------------------------------------

Status:

{
  "phase": "Pending",
  "namespaces": [
    {
      "name": "cp4i"
    }
  ]
}

-------------------------------------------------------------------------------------------------------------------

ℹ [INFO] Current installation phase is 'Pending', continuing the installation...

-------------------------------------------------------------------------------------------------------------------

✅ [SUCCESS] Successfully installed all selected addons, products and demos. Changing the overall status to 'Running'...

-------------------------------------------------------------------------------------------------------------------

ℹ [INFO] update_phase(): phase(Running)

-------------------------------------------------------------------------------------------------------------------

2020-11-12T11:39:23.510Z	DEBUG	controller	Successfully Reconciled	{"reconcilerGroup": "integration.ibm.com", "reconcilerKind": "Demo", "controller": "demo", "name": "demo-sample", "namespace": "cp4i"}
```

## Run as a Deployment inside the cluster

NOTE: The dockerfile by default builds for amd64 arch. To change it for Z-Linux change the ARCH agrument to s390x.
At the moment the make docker-build command doesn't take build-args.
Going to cover this when creating Jenkins Job for it.


Push the image to the cluster:

The following steps will expose the route to push the image to the cluster

```
export TAG=13
oc patch configs.imageregistry.operator.openshift.io/cluster --patch '{"spec":{"defaultRoute":true}}' --type=merge
export DOCKER_REGISTRY="$(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')"
echo "DOCKER_REGISTRY=${DOCKER_REGISTRY}"
export INSTALLER_NAMESPACE=default
kubectl get namespace ${INSTALLER_NAMESPACE} || kubectl create namespace ${INSTALLER_NAMESPACE}
kubectl -n ${INSTALLER_NAMESPACE} get serviceaccount image-bot || kubectl -n ${INSTALLER_NAMESPACE} create serviceaccount image-bot
oc -n ${INSTALLER_NAMESPACE} policy add-role-to-user registry-editor system:serviceaccount:${INSTALLER_NAMESPACE}:image-bot
export username=image-bot
export password="$(oc -n ${INSTALLER_NAMESPACE} serviceaccounts get-token image-bot)"

echo -e "username=$username\npassword=$password\nDOCKER_REGISTRY=$DOCKER_REGISTRY"

docker login -u $username -p $password $DOCKER_REGISTRY

```
This will build the docker image
```

make docker-build IMG=${DOCKER_REGISTRY}/${INSTALLER_NAMESPACE}/test-image:$TAG

example:
 /demos-operator# make docker-build IMG=default-route-openshift-image-registry.hr-test-33-ec111ed5d7db435e1c5eeeb4400d693f-0000.eu-gb.containers.appdomain.cloud/default/test-image:13
```

Then next command will push the image:


```
make docker-push IMG=${DOCKER_REGISTRY}/${INSTALLER_NAMESPACE}/test-image:$TAG

example:
/demos-operator# make docker-push IMG=default-route-openshift-image-registry.hr-test-33-ec111ed5d7db435e1c5eeeb4400d693f-0000.eu-gb.containers.appdomain.cloud/default/test-image:13
```
To deploy the operator fetch the image name b/c the deployment uses the internal registry name:

```
root@cron-jobs1:/demos-operator# oc get is
NAME         IMAGE REPOSITORY                                                      TAGS      UPDATED
test-image   image-registry.openshift-image-registry.svc:5000/default/test-image   13        6 hours ago

```

For this example we will run the operator in the default namespace which can be specified for all resources in config/default/kustomization.yaml:
```
$ cd config/default/ && kustomize edit set namespace "${INSTALLER_NAMESPACE}" && cd ../..
```
Run the following to deploy the operator. This will also install the RBAC manifests from config/rbac.
```
$ make deploy IMG=image-registry.openshift-image-registry.svc:5000/${INSTALLER_NAMESPACE}/test-image:$TAG

example:

make deploy IMG=image-registry.openshift-image-registry.svc:5000/${INSTALLER_NAMESPACE}/test-image:$TAG
```
as a result of above steps a deployment should appear on the cluster:

```
oc get deployments

NAME                                READY     UP-TO-DATE   AVAILABLE   AGE
demos-operator-controller-manager   1/1       1            1           23h

oc get pods

NAME                                                 READY     STATUS    RESTARTS   AGE
demos-operator-controller-manager-65cbbbdc78-kc6pp   2/2       Running   0          1h

```

### Test CSV changes in operand-create

> :information_source: CSV generated with [`operator-sdk generate kustomize manifests`](https://sdk.operatorframework.io/docs/cli/operator-sdk_generate_kustomize_manifests/).

1. Clone the [cp4i/cp4i-operand-create](https://github.ibm.com/cp4i/cp4i-operand-create) repo
2. Follow the repo readme to run the storybook:
    ```sh
    npm i && npm run storybook
    ```
3. Navigate to 'OperandCreate > Utils > Operand creation - with custom operator' in the storybook
4. Under 'Knobs':
    - Supply the CSV and CRD:
      - CSV: `config/manifests/bases/demos-operator.clusterserviceversion.yaml`
      - CRD: `config/crd/bases/integration.ibm.com_demos.yaml`
    - Select `Demo` for kind
    - Select `Schema driven` for format
