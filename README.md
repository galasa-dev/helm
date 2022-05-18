# Introduction

Galasa provides Helm charts to install various components, the main one being a Galasa Ecosystem.

## Usage

[Helm](https://helm.sh) must be installed to use the charts.  Please refer to
Helm's [documentation](https://helm.sh/docs) to get started.

Once Helm has been set up correctly, add the repo as follows:

  helm repo add galasa https://galasa-dev.github.io/helm

If you had already added this repo earlier, run `helm repo update` to retrieve
the latest versions of the packages.  You can then run `helm search repo galasa` to see the charts.


## Galasa Ecosystem chart

If RBAC is active on your Kubernetes cluster, you will need to get your Kubernetes administrator to apply a couple of RBAC yaml files to allow the Galasa Ecosystem to operate and for you to install the helm chart.

The first RBAC file which can be found at [here](https://raw.githubusercontent.com/galasa-dev/helm/release/charts/ecosystem/rbac.yaml) can be applied without modification.   It allows Galasa to complete the installation, creates a Galasa service account so the Engine Controller can create and manage engine pods.

The second RBAC file which can be found at [here](https://raw.githubusercontent.com/galasa-dev/helm/release/charts/ecosystem/rbac-admin.yaml) allows someone to do the helm install/upgrade/delete commands, this will need to be modified slightly to include authorised users.

To install a Galasa Ecosystem using Helm, use the following command (after adding the repo detailed above) :-

    helm install --set galasaVersion=0.23.0 --set externalHostname=my.host.name <release-name> galasa/ecosystem --wait 

It is very important that the `--wait` is included as the chart uses a post-install hook to complete the installation.  During the installation, you will see the engine-controller, metrics and resource-monitor pods restart a few times, this is expected as they cannot start until the api pod has correct initialised and the api pod cannot start until the etcd and couchdb have completed their startups. 

The `galasaVersion` value is the version of Galasa you want to run with.  You should not use latest to ensure each pod in the Ecosystem is running at the same level.

The `externalHostname` value is the DNS hostname or IP address of the Kubernetes node that be used to access the Galasa NodePort services.

The Galasa Ecosystem Helm chart will deploy three persistent volumes.  If you need to provide a Kubernetes storage class for these PVs, then please use the following command:-

    helm install --set storageClass=mysgtorageclass --set galasaVersion=0.23.0 --set externalHostname=my.host.name <release-name> galasa/ecosystem --wait 

After the Ecosystem has been successfully deployed, you can run the following command to ensure the Ecosystem can be accessed externally to Kubernetes and a simple test engine can be run:-

    helm test <release-name>

Once the Ecosystem is up and running,  you will need to determine the URL of the Ecosystem bootstrap.  Issue the command:-

    kubectl get svc
    
Look for the api-external service and the node port associated with the 8080 port.   Combine that with the external hostname you provided.  for example:-

```
test-api-external                 NodePort    10.107.160.208   <none>        9010:31359/TCP,9011:31422/TCP,8080:30960/TCP   18s
```

If the external hostname you provided was `example.com`,  the bootstrap URL will be `http://example.com:30960/boostrap`.  You will enter this into the Eclipse plugin preferences, or the galasactl command.
