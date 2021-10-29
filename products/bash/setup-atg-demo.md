# Overview
The setup-atg-demo.sh script does the following:
- Creates catalog sources for:
  - IAF/CS
  - Navigator
  - WML Training
  - DP/APIC
- Installs operators for:
  - Elastic Search (needed for Jaeger)
  - Jaeger
  - Navigator
  - APIC
- Installs Navigator/APIC
- Installs Jaeger
- Install Bookshop
- Calls configure-apic-atg.sh:
  - Waits for APIC to be ready
  - Enables the api-manager-lur provider
  - Creates the "atg-org" organization
  - Add the CS admin user to the org as an administrator
  - Creates the "atg-cat" catalog
  - Publishes the bookshop API
  - Runs the bookshop client to create some initial traces
  - Creates a CRON job to run the bookshop client that will add 25 traces per minute

# How to use
## Create a cluster
### ROKS
1) Use automation to create a medium ROKS cluster with ICSP and no CS/IAF.
### Fyre
1) Use automation to create a medium Fyre cluster with ICSP and no CS/IAF.
2) Use automation to install CEPHFS/NFS on the cluster

## Install the ATG demo
### Via 1-click
Using a private 1-click catalog install using this branch (`test-atg`)

### Manually
- Create a project/namespace
- Clone this repo/branch and run the `setup-atg-demo.sh` script. It defaults to the `cp4i` namespace, override with `-n <namespace>`

## Further manual steps required
- Create an APIC user with developer role to use with Analytics
- Work out the settings to use to create the ATG project
