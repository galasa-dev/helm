# Introduction

Galasa provides Helm charts to install various components, the main one being a Galasa Ecosystem.

## Usage
**Note: The Galasa Ecosystem chart only supports x86-64 at the moment.**

[Helm](https://helm.sh) must be installed to use the charts.  Please refer to
Helm's [documentation](https://helm.sh/docs) to get started.

Once Helm has been set up correctly, add the repo as follows:

```
helm repo add galasa https://galasa-dev.github.io/helm
```

If you had already added this repo earlier, run `helm repo update` to retrieve
the latest versions of the packages. You can then run `helm search repo galasa` to see the charts.

If you would like to install the chart into minikube, ensure you have minikube [installed](https://minikube.sigs.k8s.io/docs/start/).

## Galasa Ecosystem chart
### RBAC
If RBAC is active on your Kubernetes cluster, you will need to get your Kubernetes administrator to apply a couple of RBAC yaml files to allow the Galasa Ecosystem to operate and for you to install the helm chart. This also applies to minikube clusters.

The first RBAC file [(rbac.yaml)](https://raw.githubusercontent.com/galasa-dev/helm/release/charts/ecosystem/rbac.yaml) can be applied without modification. It allows Galasa to complete the installation, creates a Galasa service account so the Engine Controller can create and manage engine pods.

The second RBAC file [(rbac-admin.yaml)](https://raw.githubusercontent.com/galasa-dev/helm/release/charts/ecosystem/rbac-admin.yaml) allows someone to run the helm install/upgrade/delete commands, this will need to be modified slightly to include authorised users.

### Installation
To install a Galasa Ecosystem using Helm, use the following command (after adding the repo detailed above). Note: The Galasa Ecosystem Helm chart will deploy three persistent volumes. If you need to provide a Kubernetes storage class for these PVs, you can override the `storageClass` value as shown in the command below. If you are deploying to minikube, you can use the `standard` storage class created for you by minikube.

```
helm install [--set storageClass=mystorageclass] --set galasaVersion=0.23.0 --set externalHostname=my.host.name <release-name> galasa/ecosystem --wait 
``` 

To install the latest development version of the Galasa Ecosystem chart, replace `galasa/ecosystem` in the above command with the path to the [`ecosystem`](./charts/ecosystem) directory in this repository.

It is very important that the `--wait` is included as the chart uses a post-install hook to complete the installation.  During the installation, you will see the engine-controller, metrics and resource-monitor pods restart a few times, this is expected as they cannot start until the api pod has correct initialised and the api pod cannot start until the etcd and couchdb have completed their startups. 

The `galasaVersion` value is the version of Galasa you want to run. You should not use latest to ensure each pod in the Ecosystem is running at the same level.

The `externalHostname` value is the DNS hostname or IP address of the Kubernetes node that be used to access the Galasa NodePort services. If you are deploying to minikube, this can be retrieved by running `minikube ip`.

After the Ecosystem has been successfully deployed, you can run the following command to ensure the Ecosystem can be accessed externally to Kubernetes and a simple test engine can be run:

```
helm test <release-name>
```

Once the Ecosystem is up and running, you will need to determine the URL of the Ecosystem bootstrap. Issue the command:

```
kubectl get svc
```

Look for the api-external service and the node port associated with the 8080 port.   Combine that with the external hostname you provided. For example:

```
test-api-external                 NodePort    10.107.160.208   <none>        9010:31359/TCP,9011:31422/TCP,8080:30960/TCP   18s
```

If the external hostname you provided was `example.com`, the bootstrap URL will be `http://example.com:30960/boostrap`. You will enter this into the Eclipse plugin preferences, or the galasactl command.

### Upgrading the Galasa Ecosystem chart

If you want to upgrade the Galasa Ecosystem to increase the Galasa version, for example, then you can use the following command:

```
helm upgrade --reuse-values --set galasaVersion=0.24.0 --wait
```

**Warning**: If you have made changes to the configmaps that this helm chart manages, those changes will be lost and will have to be reapplied manually.
