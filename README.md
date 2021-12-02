# oci_openshift_installer
Install RedHat OpenShift 4.9 on Oracle Cloud Infrastructure

## Simplified Diagram 
![Simplified Diagram](https://github.com/damithkothalawala/oci_openshift_installer/raw/main/images/simplified.png)

## Full Map
Or open https://raw.githubusercontent.com/damithkothalawala/oci_openshift_installer/main/images/diagram.digraph using [GraphvizOnline](https://dreampuf.github.io/GraphvizOnline)

![Full Map](https://github.com/damithkothalawala/oci_openshift_installer/raw/main/images/graphviz.svg)

## Instructions
Please note that this terraform script is designed to used only with-in **CloudShell** on your Oracle Cloud Account.  And make sure that you have enough privileges to create resources or manage tenancy before executing this script. `You should have your own Domain` and Point to the Name Servers provided at the end of the `Terraform` script executiom

This installer designed to work with https://console.redhat.com/openshift assisted cluster installation method. And you will have to terminate and re-create nodes with preserved boot volumes per each node manually.

 1. Clone/Download this repository to your **CloudShell** 
 2. Generate OpenSSH key pairs using ssh-keygen if you do not have it already on your CloudShell environment
 3. Go to Assisted Cluster Creation Wizard on RedHat OpenShift Conole and copy live ISO download command after providing your ssh public key
 4. Edit **terraform.tfvars** file with your tenancy information
 5. Execute **terraform apply** command and wait until process completed and your Instances shows up on RedHat OpenShift console (See video at bottom of this page)
 6. When all shows up, continue the cluster creation as demonstrated on the video
 7. RedHat OpenShift Console will show amber color warning when Instances got boot back to the live ISO (Expected Situation). Then Terminate specific instance while preserving its boot volume (Do not use terraform to destroy)
 8. Re create instance manually using **preserved boot volume** on **OpenShift VCN -> Cluster Subnet** with having **Same IP Address** for the new Instance.
 9. Please note that the **OpenShift Console**  will take upto 5-10 mins to show up instance upon creation. So have some patience on the process (This is the reason for having multiple pauses on bottom demo video)
 10. Please make sure to download **kubeconfig** file from OpenShift Assisted Cluster Installation page and it will be available to download from the console for 20 days.

## ***Note on Deployment Security***
Please note that this is a Proof of Concept for running OpenShift on Oracle Cloud Infrastructure.  Please review security using provided tools on Oracle Cloud to ensure that your installation is fully secured against known threats before going to production

### Must do Actions
Please make sure to `Terminate` or `Power Off` the instance used to create `iPXE` environment. Instance Name -> `iPXE Web Server`. 

### Ports Exposed to Public Internet
Port `80` and `443` being exposed to public internet on this setup. Kubernates API not exposed to internet by default and please add new Listener / Backend Set and Backend towards Private LB's IP and Port `6443` then you will have to change `api` dns record to have `Public IP` of the `Public Loadbalancer`


## Demo Video

[![Installation Guide](https://img.youtube.com/vi/9njc_7GJIoc/0.jpg)](https://www.youtube.com/watch?v=9njc_7GJIoc)

You should watch this video https://www.youtube.com/watch?v=9njc_7GJIoc before starting the installation


## How To Contribute
All are welcome for pull requests and please raise issues under GitHub issues section. Strongly appreciate contributions on commenting the code and improving and optimizing the deployment flow.

Thank You
**Damith Rushika Kothalawala** 27th November 2021  

