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
    - [Configuring ISTIO Service Mesh (Optional)](#configuring-istio-service-mesh-optional)
    - [Optional Configurations](#optional-configurations)
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

### Configuring ISTIO Service Mesh (Optional)

As of Galasa version 0.47.0, the Galasa Ecosystem supports ISTIO service mesh integration to provide secure mutual TLS (mTLS) communication between all services within the Kubernetes cluster.

#### Prerequisites

Before enabling ISTIO in your Galasa deployment:

1. **ISTIO must be installed** in your Kubernetes cluster (version 1.18.0 or higher, 1.20.0+ recommended)
2. **Namespace must be labeled** for automatic sidecar injection

If ISTIO is not yet installed, follow the comprehensive [ISTIO Installation Guide](./docs/istio-installation.md).

#### Quick Start

1. **Install ISTIO** (if not already installed):
   ```bash
   # Using istioctl (recommended)
   curl -L https://istio.io/downloadIstio | sh -
   cd istio-1.20.0
   export PATH=$PWD/bin:$PATH
   istioctl install --set profile=default -y
   ```

2. **Label your Galasa namespace** for automatic sidecar injection:
   ```bash
   kubectl label namespace <your-namespace> istio-injection=enabled
   ```

3. **Enable ISTIO in your `values.yaml`**:
   ```yaml
   istio:
     enabled: true
     mtlsMode: "PERMISSIVE"  # Use PERMISSIVE for initial deployment
     
     proxy:
       resources:
         requests:
           cpu: "100m"
           memory: "128Mi"
         limits:
           cpu: "200m"
           memory: "256Mi"
   ```

4. **Deploy or upgrade your Galasa ecosystem**:
   ```bash
   helm upgrade --install galasa galasa/ecosystem \
     -f values.yaml \
     -n <your-namespace> \
     --wait
   ```

5. **Verify ISTIO sidecars are injected**:
   ```bash
   kubectl get pods -n <your-namespace>
   ```
   Each pod should show `2/2` containers (application + istio-proxy)

6. **After validation, switch to STRICT mTLS mode** (recommended for production):
   ```yaml
   istio:
     enabled: true
     mtlsMode: "STRICT"  # Only accept mTLS connections
   ```
   
   Then upgrade again:
   ```bash
   helm upgrade galasa galasa/ecosystem -f values.yaml -n <your-namespace>
   ```

#### Configuration Options

The ISTIO integration provides several configuration options in `values.yaml`:

```yaml
istio:
  # Enable/disable ISTIO integration
  enabled: false
  
  # mTLS mode: PERMISSIVE (mixed) or STRICT (mTLS only)
  mtlsMode: "PERMISSIVE"
  
  # Sidecar injection mode
  injection: "enabled"
  
  # ISTIO proxy resource limits
  proxy:
    resources:
      requests:
        cpu: "100m"
        memory: "128Mi"
      limits:
        cpu: "200m"
        memory: "256Mi"
  
  # Traffic management policies
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        http1MaxPendingRequests: 50
        http2MaxRequests: 100
    outlierDetection:
      consecutiveErrors: 5
      interval: 30s
      baseEjectionTime: 30s
```

#### Security Benefits

Enabling ISTIO provides:

- **Encryption in Transit**: All pod-to-pod traffic encrypted with mutual TLS
- **Identity Verification**: SPIFFE-based workload identity for service-to-service authentication
- **Zero Trust Security**: No implicit trust between services
- **Automatic Certificate Management**: Certificates automatically issued and rotated (default: 24h)
- **Traffic Observability**: Enhanced monitoring and tracing capabilities
- **Circuit Breaking**: Automatic failure detection and traffic management

#### Migration Path

For existing Galasa deployments, follow the [ISTIO Migration Guide](./docs/istio-migration.md) for a zero-downtime migration strategy.

**Recommended migration steps:**
1. Install ISTIO in your cluster
2. Label namespace for sidecar injection
3. Enable ISTIO with `mtlsMode: "PERMISSIVE"` (accepts both mTLS and plain text)
4. Validate all services are functioning correctly
5. Switch to `mtlsMode: "STRICT"` (mTLS only) for maximum security

#### Monitoring and Troubleshooting

After enabling ISTIO, you can access various dashboards for monitoring:

```bash
# Kiali (Service Mesh Dashboard)
istioctl dashboard kiali

# Grafana (Metrics)
istioctl dashboard grafana

# Jaeger (Distributed Tracing)
istioctl dashboard jaeger
```

For troubleshooting, see the [ISTIO Troubleshooting Guide](./docs/istio-troubleshooting.md).

#### Additional Resources

- [ISTIO Installation Guide](./docs/istio-installation.md) - Detailed installation instructions
- [ISTIO Migration Guide](./docs/istio-migration.md) - Zero-downtime migration for existing deployments
- [ISTIO Test Plan](./docs/istio-test-plan.md) - Comprehensive testing procedures
- [ISTIO Official Documentation](https://istio.io/latest/docs/) - Complete ISTIO documentation


### Optional Configurations

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
