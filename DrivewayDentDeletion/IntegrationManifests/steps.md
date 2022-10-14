```
cat <<EOF | oc apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: cp4i-block-performance
  labels:
    kubernetes.io/cluster-service: "true"
provisioner: ibm.io/ibmc-block
parameters:
  billingType: "hourly"
  classVersion: "2"
  sizeIOPSRange: |-
    "[1-39]Gi:[1000]"
    "[40-79]Gi:[2000]"
    "[80-99]Gi:[4000]"
    "[100-499]Gi:[5000-6000]"
    "[500-999]Gi:[5000-10000]"
    "[1000-1999]Gi:[10000-20000]"
    "[2000-2999]Gi:[20000-40000]"
    "[3000-12000]Gi:[24000-48000]"
  type: "Performance"
reclaimPolicy: Delete
volumeBindingMode: Immediate
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: cp4i-file-performance-gid
  labels:
    kubernetes.io/cluster-service: "true"
provisioner: ibm.io/ibmc-file
parameters:
  billingType: "hourly"
  classVersion: "2"
  gidAllocate: "true"
  sizeIOPSRange: |-
    "[1-39]Gi:[1000]"
    "[40-79]Gi:[2000]"
    "[80-99]Gi:[4000]"
    "[100-499]Gi:[5000-6000]"
    "[500-999]Gi:[5000-10000]"
    "[1000-1999]Gi:[10000-20000]"
    "[2000-2999]Gi:[20000-40000]"
    "[3000-12000]Gi:[24000-48000]"
  type: "Performance"
reclaimPolicy: Delete
volumeBindingMode: Immediate
EOF

defaultStorageClass=$(oc get sc -o json | jq -r '.items[].metadata | select(.annotations["storageclass.kubernetes.io/is-default-class"] == "true") | .name')
oc patch storageclass $defaultStorageClass -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
oc patch storageclass cp4i-block-performance -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
DEFAULT_BLOCK_STORAGE="cp4i-block-performance"
DEFAULT_FILE_STORAGE="cp4i-file-performance-gid"



```
namespace=cp4i
file_storage=ibmc-file-gold-gid
block_storage=ibmc-block-gold

block_storage="cp4i-block-performance"
file_storage="cp4i-file-performance-gid"
```

```
../../products/bash/create-catalog-sources.sh

oc new-project ${namespace}
../../products/bash/deploy-og-sub.sh -n ${namespace}

../../products/bash/release-navigator.sh -n ${namespace} -s ${file_storage}

../../products/bash/release-ace-dashboard.sh -n ${namespace} -s ${file_storage}

# TODO
./prereqs.sh -n ${namespace}
./cicd-apply-dev-pipeline.sh TODO
```
