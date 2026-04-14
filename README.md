# Galasa Helm Charts

Helm charts for deploying Galasa components to Kubernetes, including the complete Galasa Ecosystem.

## Quick Start

### Prerequisites

- [Helm 3 or 4](https://helm.sh/docs/intro/install/) installed
- Access to a Kubernetes cluster (v1.30.3 or later recommended)
- `kubectl` configured to access your cluster

### Basic Installation

1. **Add the Galasa Helm repository:**

   ```bash
   helm repo add galasa https://galasa-dev.github.io/helm
   helm repo update
   ```

2. **Download and configure values:**

   ```bash
   curl -O https://raw.githubusercontent.com/galasa-dev/helm/main/charts/ecosystem/values.yaml
   ```

   Edit `values.yaml` and set:
   - `galasaVersion`: Your desired Galasa version (see [releases](https://galasa.dev/releases))
   - `externalHostname`: The hostname for accessing your ecosystem (e.g., `galasa.example.com`)

3. **Configure network access:**

   Choose either Ingress (default) or Gateway API. For Ingress, update:
   ```yaml
   ingress:
     enabled: true
     ingressClassName: nginx  # Change to your IngressClass
   ```

   For Gateway API or HTTPS setup, see [Network Access](#network-access-ingressgateway-api).

4. **Configure authentication (Dex):**

   Update the `dex` section in `values.yaml`:
   ```yaml
   dex:
     config:
       issuer: https://galasa.example.com/dex  # Use your hostname
       connectors:
       - type: github  # Or another supported connector
         id: github
         name: GitHub
         config:
           clientID: $GITHUB_CLIENT_ID
           clientSecret: $GITHUB_CLIENT_SECRET
           redirectURI: https://galasa.example.com/dex/callback
   ```

   See [Configuring Authentication](#configuring-authentication-dex) for detailed setup.

5. **Install the ecosystem:**

   ```bash
   helm install my-galasa galasa/ecosystem -f values.yaml --wait
   ```

6. **Verify the installation:**

   ```bash
   helm test my-galasa
   ```

Your Galasa Ecosystem is now accessible at `https://galasa.example.com/api/bootstrap`

---

## Table of Contents

- [Galasa Helm Charts](#galasa-helm-charts)
  - [Quick Start](#quick-start)
    - [Prerequisites](#prerequisites)
    - [Basic Installation](#basic-installation)
  - [Table of Contents](#table-of-contents)
  - [Configuration Guide](#configuration-guide)
    - [RBAC Setup](#rbac-setup)
    - [Network Access (Ingress/Gateway API)](#network-access-ingressgateway-api)
      - [Option 1: Ingress (Default)](#option-1-ingress-default)
      - [Option 2: Gateway API (v0.47.0+)](#option-2-gateway-api-v0470)
    - [Configuring Authentication (Dex)](#configuring-authentication-dex)
      - [GitHub Example](#github-example)
      - [Other Identity Providers](#other-identity-providers)
    - [Optional Configurations](#optional-configurations)
      - [Istio Service Mesh](#istio-service-mesh)
      - [Storage Class](#storage-class)
      - [Kafka Integration](#kafka-integration)
      - [Custom Logging (Log4j2)](#custom-logging-log4j2)
      - [Internal Certificates](#internal-certificates)
  - [Installation Guides](#installation-guides)
    - [Remote Kubernetes Cluster](#remote-kubernetes-cluster)
    - [Minikube (Development)](#minikube-development)
      - [Prerequisites](#prerequisites-1)
      - [Linux Setup](#linux-setup)
      - [macOS Setup](#macos-setup)
  - [Operations](#operations)
    - [Verifying Installation](#verifying-installation)
    - [Upgrading](#upgrading)
    - [Uninstalling](#uninstalling)
    - [Rotating Encryption Keys](#rotating-encryption-keys)
      - [Prerequisites](#prerequisites-2)
      - [Automated Rotation (Linux/macOS)](#automated-rotation-linuxmacos)
      - [Manual Rotation](#manual-rotation)
  - [Development](#development)
  - [Support](#support)

---

## Configuration Guide

### RBAC Setup

If RBAC is enabled on your cluster, configure user permissions:

**For chart versions after 0.23.0:** RBAC is configured automatically during installation.

**For chart version 0.23.0 and earlier:** Apply RBAC manually:
```bash
kubectl apply -f https://raw.githubusercontent.com/galasa-dev/helm/ecosystem-0.23.0/charts/ecosystem/rbac.yaml
```

**Admin access:** Update [`rbac-admin.yaml`](./charts/ecosystem/rbac-admin.yaml) to grant users the `galasa-admin` role for managing the Helm chart. Replace the placeholder username with actual usernames or add multiple subjects as needed.

### Network Access (Ingress/Gateway API)

Choose one method to expose your Galasa services:

#### Option 1: Ingress (Default)

Most common for production deployments. Configure in `values.yaml`:

```yaml
ingress:
  enabled: true
  ingressClassName: nginx  # Change to your IngressClass
  # For HTTPS, add:
  tls:
    - hosts:
        - galasa.example.com
      secretName: galasa-tls-secret
```

See [Kubernetes Ingress documentation](https://kubernetes.io/docs/concepts/services-networking/ingress/#tls) for TLS setup.

#### Option 2: Gateway API (v0.47.0+)

**Prerequisites:**
- [Gateway Controller](https://gateway-api.sigs.k8s.io/guides/getting-started/#installing-a-gateway-controller) installed
- [Gateway API CRDs](https://gateway-api.sigs.k8s.io/guides/getting-started/#installing-gateway-api) installed

For clusters with Gateway API support:

```yaml
gateway:
  enabled: true
  gatewayClassName: my-gateway-class
  # For HTTPS, add:
  tls:
    certificateRefs:
      - kind: Secret
        group: ""
        name: my-certificate-secret
```

### Configuring Authentication (Dex)

Galasa uses [Dex](https://dexidp.io) for authentication. Configure a connector to your identity provider:

#### GitHub Example

1. **Create a GitHub OAuth App:**
   - Go to [GitHub OAuth Apps](https://github.com/settings/applications/new)
   - Set **Homepage URL** to your external hostname (e.g., `https://galasa.example.com`)
   - Set **Callback URL** to `https://galasa.example.com/dex/callback`
   - Generate a client secret and save both the client ID and secret

2. **Configure Dex in values.yaml:**

   ```yaml
   dex:
     config:
       issuer: https://galasa.example.com/dex
       
       connectors:
       - type: github
         id: github
         name: GitHub
         config:
           clientID: $GITHUB_CLIENT_ID
           clientSecret: $GITHUB_CLIENT_SECRET
           redirectURI: https://galasa.example.com/dex/callback
           # Optional: Restrict to organization/team
           orgs:
           - name: my-org
             teams:
             - my-team
   ```

3. **Store credentials securely (recommended):**

   ```bash
   kubectl create secret generic github-oauth-credentials \
     --from-literal=GITHUB_CLIENT_ID="your-client-id" \
     --from-literal=GITHUB_CLIENT_SECRET="your-client-secret"
   ```

   Then reference the secret in `values.yaml`:
   ```yaml
   dex:
     envFrom:
       - secretRef:
           name: github-oauth-credentials
   ```

#### Other Identity Providers

Dex supports many connectors including Microsoft, LDAP, OIDC, and more. See the [Dex connectors documentation](https://dexidp.io/docs/connectors) for configuration examples.

### Optional Configurations

#### Istio Service Mesh

Galasa supports integration with [Istio](https://istio.io) service mesh to automatically encrypt all pod-to-pod traffic using mutual TLS (mTLS).

**Prerequisites:**
- Istio 1.29+ installed in your Kubernetes cluster
- See [Istio installation guide](https://istio.io/latest/docs/setup/getting-started/)

**Basic Configuration (Internal Traffic Only):**

To enable mTLS for internal pod-to-pod traffic:

```yaml
istio:
  enabled: true
  mtlsMode: "STRICT"  # Recommended for production
```

**External Traffic Routing:**

Istio can also handle external traffic routing. Choose one option:

**Option 1: Istio with Kubernetes Gateway API (Recommended)**

```yaml
istio:
  enabled: true
  mtlsMode: "STRICT"

gatewayApi:
  enabled: true
  gatewayClassName: "istio"  # Use Istio's Gateway implementation

```

**Option 2: Istio with Kubernetes Ingress**

First, create an Istio IngressClass:

```yaml
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: istio
spec:
  controller: istio.io/ingress-controller
EOF
```

Then configure the chart's values:

```yaml
istio:
  enabled: true
  mtlsMode: "STRICT"

ingress:
  enabled: true
  ingressClassName: "istio"  # Use Istio's Ingress controller

```

**Note:** When using Istio for external traffic, Istio handles both external ingress and internal mTLS encryption.

**Configuration Options:**

- `istio.enabled`: Enable or disable Istio integration (default: `false`)
- `istio.mtlsMode`: mTLS enforcement mode
  - `STRICT`: Only mTLS traffic allowed (recommended for production)
  - `PERMISSIVE`: Both mTLS and plaintext allowed (useful for migration)
  - `DISABLE`: mTLS disabled

**How It Works:**

When Istio is enabled:
1. All Galasa service pods receive an Istio sidecar proxy
2. The sidecar automatically encrypts all pod-to-pod traffic using mTLS
3. Application code continues to use HTTP URLs - encryption is transparent
4. Test pods launched by the Engine Controller also receive Istio sidecars

**Migration Strategy:**

For existing deployments, use a gradual migration approach:

1. **Enable with PERMISSIVE mode:**
   ```yaml
   istio:
     enabled: true
     mtlsMode: "PERMISSIVE"
   ```

2. **Upgrade your deployment:**
   ```bash
   helm upgrade my-galasa galasa/ecosystem -f values.yaml --wait
   ```

3. **Verify all services are working:**
   ```bash
   # Check that all pods have Istio sidecars (should show 2 containers per pod)
   kubectl get pods
   
   # Verify mTLS is enabled by checking Istio proxy config
   istioctl proxy-status 
   ```

4. **Switch to STRICT mode:**
   ```yaml
   istio:
     enabled: true
     mtlsMode: "STRICT"
   ```

5. **Upgrade again:**
   ```bash
   helm upgrade my-galasa galasa/ecosystem -f values.yaml --wait
   ```

**Troubleshooting:**

- **Pods not getting sidecars:** Verify Istio is installed with `kubectl get pods -n istio-system`
- **Connection failures:** Use PERMISSIVE mode during migration, then switch to STRICT
- **Check Istio proxy logs:** `kubectl logs <pod-name> -c istio-proxy`

#### Storage Class

If your cluster requires a specific StorageClass:

```yaml
storageClass: my-storage-class
```

#### Kafka Integration

To publish Galasa events to Kafka:

1. Create a secret with your Kafka token:
   ```yaml
   apiVersion: v1
   kind: Secret
   metadata:
     name: event-streams-token
   data:
     GALASA_EVENT_STREAMS_TOKEN: <base64-encoded-token>
   ```

2. Apply the secret before installing the chart

See [Kafka extension documentation](https://github.com/galasa-dev/extensions/blob/main/galasa-extensions-parent/dev.galasa.events.kafka/README.md) for details.

#### Custom Logging (Log4j2)

Customize log format by setting `log4j2Properties` in `values.yaml`:

```yaml
log4j2Properties: |
  status = error
  name = Default

  appender.console.type = Console
  appender.console.name = stdout
  appender.console.layout.type = PatternLayout
  appender.console.layout.pattern = %d{dd/MM/yyyy HH:mm:ss.SSS} %-5p %c{1.} - %m%n

  rootLogger.level = debug
  rootLogger.appenderRef.stdout.ref = stdout
```

For JSON templates, create a ConfigMap and reference it:
```yaml
log4jJsonTemplatesConfigMapName: my-json-layouts
```

#### Internal Certificates

For connecting to servers with internal or corporate certificates:

1. Create a ConfigMap with your certificates:
   ```bash
   kubectl create configmap my-certificates \
     --from-file=/path/to/certificate1.pem \
     --from-file=/path/to/certificate2.pem
   ```

2. Reference it in `values.yaml`:
   ```yaml
   certificatesConfigMapName: my-certificates
   ```

---

## Installation Guides

### Remote Kubernetes Cluster

Follow the [Quick Start](#quick-start) guide above, ensuring you've configured:
- Network access (Ingress or Gateway API)
- Authentication (Dex)
- Any optional features you need

### Minikube (Development)

⚠️ **Minikube is for development/testing only, not production use.**

#### Prerequisites

- [Minikube](https://minikube.sigs.k8s.io/docs/start/) installed and running
- Verify with: `minikube status`

#### Linux Setup

1. **Enable Ingress:**
   ```bash
   minikube addons enable ingress
   ```

2. **Configure /etc/hosts:**
   ```bash
   # Add this line (replace IP with output of 'minikube ip')
   192.168.49.2 galasa.local
   ```

3. **Configure values.yaml:**
   - Set `externalHostname: galasa.local`
   - Configure Dex and Ingress as described above

4. **Install:**
   ```bash
   helm install my-galasa ./charts/ecosystem -f values.yaml --wait
   ```

5. **Verify:**
   ```bash
   kubectl get pods  # Wait for all pods to be Ready
   helm test my-galasa
   ```

#### macOS Setup

1. **Enable Ingress:**
   ```bash
   minikube addons enable ingress
   ```

2. **Configure /etc/hosts:**
   ```bash
   # Add this line
   127.0.0.1 galasa.local
   ```

3. **Configure CoreDNS for internal resolution:**
   
   a. Get Minikube IP:
   ```bash
   minikube ip  # Note this IP (e.g., 192.168.49.2)
   ```
   
   b. Edit CoreDNS ConfigMap:
   ```bash
   kubectl -n kube-system edit configmap coredns
   ```
   
   c. Add this entry (replace IP with your Minikube IP):
   ```yaml
   galasa.local:53 {
     hosts {
       192.168.49.2 galasa.local
       fallthrough
     }
   }
   ```
   
   d. Restart CoreDNS:
   ```bash
   kubectl -n kube-system rollout restart deployment coredns
   ```

4. **Configure values.yaml:**
   - Set `externalHostname: galasa.local`
   - Configure Dex and Ingress as described above

5. **Install:**
   ```bash
   helm install my-galasa ./charts/ecosystem -f values.yaml --wait
   ```

6. **Start tunnel (keep running):**
   ```bash
   minikube tunnel
   ```

7. **Verify (in another terminal):**
   ```bash
   kubectl get pods  # Wait for all pods to be Ready
   helm test my-galasa
   ```

---

## Operations

### Verifying Installation

After installation, verify your ecosystem is working:

```bash
helm test <release-name>
```

Expected output:
```
TEST SUITE:     my-galasa-validate
Last Started:   Mon Mar  3 11:44:24 2025
Last Completed: Mon Mar  3 11:45:45 2025
Phase:          Succeeded
```

**Access your ecosystem:**
- Bootstrap URL: `https://<your-hostname>/api/bootstrap`
- Web UI: `https://<your-hostname>`

**Monitor pods:**
```bash
kubectl get pods
```

All pods should show `Running` status and `1/1` ready.

### Upgrading

To upgrade to a newer Galasa version:

```bash
helm repo update
helm upgrade <release-name> galasa/ecosystem \
  --reuse-values \
  --set galasaVersion=0.38.0 \
  --wait
```

Or update your `values.yaml` and run:
```bash
helm upgrade <release-name> galasa/ecosystem -f values.yaml --wait
```

### Uninstalling

```bash
helm uninstall <release-name>
```

This removes all Kubernetes resources created by the chart.

### Rotating Encryption Keys

Galasa encrypts credentials using AES-256-GCM. To rotate encryption keys:

#### Prerequisites

- `kubectl` (v1.30.3+)
- `galasactl` (0.38.0+)
- `openssl` (3.3.2+)
- Permissions to manage Secrets in your namespace
- Valid personal access token for Galasa

**⚠️ Backup your credentials first:**
```bash
galasactl secrets get --format yaml > backup.yaml
```

#### Automated Rotation (Linux/macOS)

Use the provided script:

```bash
./rotate-encryption-keys.sh \
  --release-name my-galasa \
  --namespace default \
  --bootstrap https://galasa.example.com/api/bootstrap
```

The script will:
1. Generate a new encryption key
2. Update the Kubernetes Secret
3. Restart API and engine controller pods
4. Re-encrypt all existing credentials
5. Clean up fallback keys

#### Manual Rotation

<details>
<summary>Click to expand manual steps</summary>

1. **Backup existing secrets:**
   ```bash
   galasactl secrets get --format yaml > backup.yaml
   ```

2. **Find the encryption secret:**
   ```bash
   kubectl get secrets
   # Look for: <release-name>-encryption-secret
   ```

3. **Get current encryption keys:**
   ```bash
   kubectl get secret <encryption-secret-name> \
     --output jsonpath='{ .data.encryption-keys\.yaml }' | \
     openssl base64 -d -A > current-keys.yaml
   ```

4. **Generate new key:**
   ```bash
   openssl rand -base64 32
   ```

5. **Update keys file:**
   Edit `current-keys.yaml` to move the old key to fallback and add the new key:
   ```yaml
   encryptionKey: <new-key-from-step-4>
   fallbackDecryptionKeys:
   - <old-key-from-step-3>
   ```

6. **Encode and update secret:**
   ```bash
   NEW_KEYS=$(openssl base64 -in current-keys.yaml | tr -d '\n')
   kubectl patch secret <encryption-secret-name> \
     --type='json' \
     -p="[{'op': 'replace', 'path': '/data/encryption-keys.yaml', 'value': '$NEW_KEYS'}]"
   ```

7. **Restart services:**
   ```bash
   kubectl rollout restart deployment <release-name>-api
   kubectl rollout status deployment <release-name>-api
   
   kubectl rollout restart deployment <release-name>-engine-controller
   kubectl rollout status deployment <release-name>-engine-controller
   ```

8. **Re-encrypt credentials:**
   ```bash
   galasactl resources apply -f backup.yaml
   ```

9. **Verify:**
   ```bash
   galasactl secrets get --format yaml
   # Compare with backup.yaml to ensure secrets are readable
   ```

</details>

---

## Development

To install the latest development version:

1. **Clone this repository:**
   ```bash
   git clone https://github.com/galasa-dev/helm.git
   cd helm
   ```

2. **Configure values.yaml for development:**
   ```yaml
   galasaVersion: main
   galasaRegistry: ghcr.io/galasa-dev
   galasaBootImage: galasa-boot-embedded
   pullPolicy: Always
   galasaWebUiImage: webui
   architecture: amd64  # or arm64
   externalHostname: galasa.local  # For Minikube
   ```

3. **Configure Ingress and Dex** as described in the [Configuration Guide](#configuration-guide)

4. **Install from local chart:**
   ```bash
   helm install my-galasa ./charts/ecosystem -f values.yaml --wait
   ```

---

## Support

- **Documentation:** [galasa.dev](https://galasa.dev)
- **Issues:** [GitHub Issues](https://github.com/galasa-dev/projectmanagement/issues)
- **Releases:** [Galasa Releases](https://galasa.dev/releases)
