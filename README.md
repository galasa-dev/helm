# Introduction

Galasa provides Helm charts to install various components, the main one being a Galasa Ecosystem.

## Prerequisites
**Note: The Galasa Ecosystem chart only supports x86-64 at the moment. It cannot be installed on ARM64-based systems.**

[Helm](https://helm.sh) must be installed to use the charts.  Please refer to
Helm's [documentation](https://helm.sh/docs) to get started.

## Galasa Ecosystem chart
### Minikube
It is highly discouraged to use minikube for production purposes since it only provides a single Kubernetes node and will not scale well in demanding situations. Only use minikube for development and testing purposes.

If you would like to install the chart into minikube, ensure you have minikube [installed](https://minikube.sigs.k8s.io/docs/start/) and that it is running with `minikube status`. If minikube is not running, start it by running `minikube start`.

Once minikube is running, follow the instructions in the sections below to install the Galasa Ecosystem chart. 

### RBAC
If RBAC is active on your Kubernetes cluster, you will need to get your Kubernetes administrator to replace the [placeholder username](https://github.com/galasa-dev/helm/blob/main/charts/ecosystem/rbac-admin.yaml#L39) in the [rbac-admin.yaml](./charts/ecosystem/rbac-admin.yaml) file with a username corresponding to a user with access to your cluster to assign them the `galasa-admin` role. This role allows assigned users to run the helm install/upgrade/delete commands to interact with the helm chart.

If multiple users require admin privileges, multiple groups, users, or ServiceAccounts can be assigned the `galasa-admin` role by extending the [subjects](https://github.com/galasa-dev/helm/blob/main/charts/ecosystem/rbac-admin.yaml#L36) list (see [Using RBAC Authorization](https://kubernetes.io/docs/reference/access-authn-authz/rbac) for more information).

For chart versions following 0.23.0, the other RBAC file ([rbac.yaml](./charts/ecosystem/templates/rbac.yaml)) is applied automatically when installing the ecosystem chart. It creates a Galasa service account if one does not already exist so the API, Engine Controller, Metrics, and Resource Monitor can coordinate, while allowing the Engine Controller to create and manage engine pods.

For chart version 0.23.0 and prior, you will need to apply [rbac.yaml](./charts/ecosystem/rbac.yaml) manually. You can do this by running the following command in this repository's [`ecosystem`](./charts/ecosystem/) directory:
```console
kubectl apply -f rbac.yaml
```

### Installation
First, add the galasa repository as follows:

```console
helm repo add galasa https://galasa-dev.github.io/helm
```

If you have already added this repository earlier, run `helm repo update` to retrieve
the latest versions of the packages. You can then run `helm search repo galasa` to see the available charts.

Note: The Galasa Ecosystem Helm chart will deploy three persistent volumes. If you need to provide a Kubernetes storage class for these PVs, update the `storageClass` value in your [values.yaml](./charts/ecosystem/values.yaml) file with the name of a valid StorageClass on your cluster.

If you are deploying to minikube, you can use the `standard` storage class created for you by minikube, but this is not required.

In your [values.yaml](charts/ecosystem/values.yaml) file:

  1. Set the `galasaVersion` value to a version of galasa you want to run (see [releases](https://galasa.dev/releases) for released versions). You should not use latest to ensure each pod in the Ecosystem is running at the same level.
  2. Set the `externalHostname` value to the DNS hostname or IP address of the Kubernetes node that will be used to access the Galasa NodePort services.
     * If you are deploying to minikube, the cluster's IP address can be retrieved by running `minikube ip`.

Having configured your [values.yaml](charts/ecosystem/values.yaml) file, use the following command to install the Galasa Ecosystem chart:

```console
helm install <release-name> galasa/ecosystem --wait 
``` 

The `--wait` flag ensures the chart installation has completed before marking it as "Deployed". During the installation, the API pod waits for the etcd and RAS pods to initialise while the engine-controller, metrics, and resource-monitor pods wait for the API pod to initialise.

You can view the status of the deployed pods at any time by running `kubectl get pods` in another terminal. The results should look similar to the following:
```console
NAME                                      READY   STATUS     RESTARTS      AGE
test-api-7945f959dd-v8tbs                 1/1     Running    0             65s
test-engine-controller-56fb476f45-msj4x   0/1     Init:0/1   0             65s
test-etcd-0                               1/1     Running    0             65s
test-metrics-5fd9f687b6-rwcww             0/1     Init:0/1   0             65s
test-ras-0                                1/1     Running    0             65s
test-resource-monitor-778c647995-x75z9    0/1     Init:0/1   0             65s
```

After the `helm install` command ends with a successful deployment message, you can run the following command to ensure the Ecosystem can be accessed externally to Kubernetes and a simple test engine can be run:

```console
helm test <release-name>
```

Once the `helm test` command ends and displays a success message, the Ecosystem has been set up correctly and is ready to be used.

To determine the URL of the Ecosystem bootstrap, issue the command:

```console
kubectl get svc
```

Look for the `api-external` service and the NodePort associated with the 8080 port. Combine that with the external hostname you provided to form the bootstrap URL. For example, the following snippet shows `30960` to be associated with port 8080:

```console
test-api-external  NodePort  10.107.160.208  <none>  9010:31359/TCP,9011:31422/TCP,8080:30960/TCP  18s
```

If the external hostname you provided was `example.com`, the bootstrap URL will be `http://example.com:30960/boostrap`. You will enter this into the Eclipse plugin preferences, or in a galasactl command's `--bootstrap` option.

### Upgrading the Galasa Ecosystem

If you want to upgrade the Galasa Ecosystem to use a newer version of Galasa, for example, then you can use the following command:

```console
helm upgrade --reuse-values --set galasaVersion=0.25.0 --wait
```

### Development
To install the latest development version of the Galasa Ecosystem chart, clone this repository and update the following values in your [values.yaml](charts/ecosystem/values.yaml) file:

1. Set the `galasaVersion` value to `main`
2. Set the `galasaRegistry` value to `harbor.galasa.dev/galasadev`
3. Set the `externalHostname` value to the DNS hostname or IP address of the Kubernetes node that will be used to access the Galasa NodePort services.
   * If you are deploying to minikube, the cluster's IP address can be retrieved by running `minikube ip`.

Next, run the following command, providing the path to the [`ecosystem`](./charts/ecosystem) directory in this repository (e.g. `~/helm/charts/ecosystem`).

```console
helm install <release-name> /path/to/helm/charts/ecosystem --wait 
``` 

Once the `helm install` command ends with a successful deployment message, you can follow the installation instructions above to test the deployed ecosystem using `helm test` and determine the bootstrap URL.
