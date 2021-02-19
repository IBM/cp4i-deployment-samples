# Name

IBM&reg; Cloud Pak for Integration Demos Operator
# Introduction

## Summary

* IBM&reg; Cloud Pak for Integration&reg; Demos operator allows the user to setup demos that use the capabilities available
in IBM&reg; Cloud Pak for Integration&reg;. It deploys pre-designed demos that gives the user an overview of what can be achieved
using IBM&reg; Cloud Pak for Integration&reg;

## Features

- Setup Multiple Demos
  - Drive Dent Deletion: This demo shows the 'Scatter Gather' pattern being used to create an API which exposes three independent integration services being called in parallel from one request, with the result being combined into a single response to the user. This pattern is often used in buying comparison sites e.g. for Hotels, Air Fares, Insurance, Financial Products etc.The demo uses a full CI/CD pipeline built on OpenShift pipelines which builds containers for each of the components and then deploys them all together with all the correct credentials and bindings. It also shows live deployment updates of integrations with zero downtime. It shows live fixpack application with zero downtime - also showing that CP4i can run multiple versions of products at the same time and patch/upgrade them independently. Shows tracing/Operational Dashboard to show the flow of the request through the system allowing performance bottlenecks to be applied. 

  - Event Enabled Insurance: This demo shows a powerful combination of Event Driven integration using Event Streams, coupled with APIs using assured delivery through IBM MQ.This enables back end systems to 'Project' data out to where it's most useful and allow a large scale of queries to be performed on the data without touching the System of Record. Even if the SOR is online, it allows customers to query their data 24/7/365.Using MQ between the API and the backend allows CP4i to 'buffer' requests that are too much volume for the back-end, allowing them to flow at a constant rate and avoid overloading it. In addition, when the SOR is offline, write requests are buffered in the queue to allow customers to make new claims 24/7/365. Event streams also enables real-time notification of claim status changes, direct to their application thus enhancing their experience with the company.

  - Car Crash Demo: The Car Crash Repair Demo is a comprehensive API led solution built using powerful Cloud Pak for Integration Capabilities. The demo will show you how to rapidly build APIs that connect with SaaS applications and Watson services and securely expose them to partners.

  - Mapping Assist: This demo shows how mapping assist can significantly accelerate building an API by reducing the time it takes to map complex fields.

- Configure the Demos as per need

- Makes use of multiple capabilities available as part of the IBM&reg; Cloud Pak for Integration&reg;

# Details

## Prerequisites

- Red Hat openshift operator installed
- Postgres

### Resources Required
Minimum resources required to run the demos
| Software                 | Storage                             | Min CPU       | Min Memory | 
| -----------------------  | ----------------------------------- | ------------- | ---------- | 
| `Demos`                  | `331.84 GB`                         |  `33.9 Cores` | `87.5Gi`   |  

### Cognitive Car Repair
| Integration capability            | CPU        | Memory   | Disk Space |
| --------------------------------- | ---------- | -------- | ---------- |
| Application Integration Dashboard | 1 core     | 4 GiB    | 2.3 GB     |
| --------------------------------- | ---------- | -------- | ---------- |
| Application Integration Designer  | 1 core     | 5.75 GiB | 30 GB      |
| --------------------------------- | ---------- | -------- | ---------- |
| API Lifecycle and Management      | 12 cores   | 48 GiB   | 280 GB     |
| --------------------------------- | ---------- | -------- | ---------- |
| Asset Repository                  | 0.7 cores  | 1 GiB    | 0.4 GB     |
| --------------------------------- | ---------- | -------- | ---------- |
| Operations Dashboard              | 6 cores    | 16 GiB   | 16 GB      |
### Driveway Dent Deletion

| Integration capability            | CPU        | Memory   | Disk Space |
| --------------------------------- | ---------- | -------- | ---------- |
| Queue Manager                     | 1 core     | 1 GiB    | 2 GB       |
| --------------------------------- | ---------- | -------- | ---------- |
| Application Integration Dashboard | 1 core     | 4 GiB    | 2.3 GB     |
| --------------------------------- | ---------- | -------- | ---------- |
| API Lifecycle and Management      | 12 cores   | 48 GiB   | 280 GB     |
| --------------------------------- | ---------- | -------- | ---------- |
| Operations Dashboard              | 6 cores    | 16 GiB   | 16 GB      |
### Event Enabled Insurance

| Integration capability            | CPU        | Memory   | Disk Space |
| --------------------------------- | ---------- | -------- | ---------- |
| Queue Manager                     | 1 core     | 1 GiB    | 2 GB       |
| --------------------------------- | ---------- | -------- | ---------- |
| Application Integration Dashboard | 1 core     | 4 GiB    | 2.3 GB     |
| --------------------------------- | ---------- | -------- | ---------- |
| API Lifecycle and Management      | 12 cores   | 48 GiB   | 280 GB     |
| --------------------------------- | ---------- | -------- | ---------- |
| Event Streams                     | 8.2 cores  | 8.2 GiB  | 1.5 GB     |
| --------------------------------- | ---------- | -------- | ---------- |
| Operations Dashboard              | 6 cores    | 16 GiB   | 16 GB      |
### Mapping Assist

| Integration capability            | CPU        | Memory   | Disk Space |
| --------------------------------- | ---------- | -------- | ---------- |
| Application Integration Designer  | 1 core     | 5.75 GiB | 30 GB      |

# Installing

* Installation is based on [k8s Operator](https://kubernetes.io/docs/concepts/extend-kubernetes/operator/) 
* [Github Link](https://github.com/IBM/cp4i-deployment-samples/blob/main/DemosOperator/Hack/README.md)

# Operator scope
| Namespace scope installation              | Supported |

| Cluster scope installation                | Supported |

# Deploying multiple instances on to single cluster
Requirements to create multiple instances of the demo operator in each namespace you will need:

- Platform Navigator
- The operators of API Connect, App Connect, Asset Repository, Event Streams, MQ and Operations Dashboard installed.
- The secret to pull in the demo operator image.

## Storage

Our demos use both Read Write Many (RWX) and Read Write Only (RWO) modes of storage depending upon the capabilities that are being used.

## Limitations
- Only runs on AMD64 architectures
- Only runs on Linux operating systems
## SecurityContextConstraints Requirement

This chart is supported on Red Hat OpenShift. The predefined SecurityContextConstraint name `privileged` has been verified for this chart.

Custom SecurityContextConstraints definition:
 `+kubebuilder:rbac:groups=security.openshift.io,resources=securitycontextconstraints,resourceNames=privileged,verbs=use`

 ```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  creationTimestamp: null
  name: manager-role
rules: 
- apiGroups:
  - security.openshift.io
  resourceNames:
  - privileged
  resources:
  - securitycontextconstraints
  verbs:
  - use
  ```