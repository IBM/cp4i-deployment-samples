# cp4i-deployment-samples

Samples for deploying Cloud Pak for Integration capabilities in a pipeline.

These samples are aimed at providing a way to quickly configure CP4I for running demos and exploring functionality. They are not designed for production use.

# Known Issues
- APIC fails to install on a cluster when the hostname is too long. To work around this, find your release config map by running:  
```
oc get cm
```
And find the configmap with your release name at the start. Then run:  
```
oc edit cm <configmap-name>
```  
Then change:  
```
server_names_hash_bucket_size 128
```  
to:  
```
server_names_hash_bucket_size 256
```  
Find the pod that is in a CrashLoopBackoff state by running:  
```
oc get pods
```  
and finding one with your release name at the start that has the state CrashLoopBackoff. Delete that pod by running:  
```
oc delete <pod-name>
```  
Then wait for the pod to restart.  

- On APIC, if your release name and project name lengths combined are greater than 14, you get an error with: `CR name + namespace must be less than 15 characters in length.` When using these samples we provide a release name of length 4, so ensure that a project name less than 11 is used. 