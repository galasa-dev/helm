# ISTIO Installation Guide for Galasa Ecosystem

This guide provides step-by-step instructions for installing ISTIO service mesh as a prerequisite for deploying a Galasa Ecosystem with secure inter-service communication.

## Prerequisites

Before installing ISTIO, ensure you have:

- **Kubernetes cluster**: Version 1.26 or higher
- **Helm**: Version 3.x installed and configured
- **kubectl**: Configured with cluster-admin privileges
- **Cluster resources**:
  - Control plane: Minimum 2 CPU cores, 4GB RAM
  - Per sidecar proxy: 100m CPU, 128Mi RAM (configurable)
  - Storage: Sufficient for ISTIO components and logs

## ISTIO Components Overview

The Galasa Ecosystem requires the following ISTIO components:

- **Istiod** (Control Plane) - Required
  - Service discovery
  - Configuration distribution
  - Certificate management
  - Sidecar injection webhook

- **Istio Ingress Gateway** - Required
  - External access to Galasa services
  - TLS termination
  - Traffic routing

- **Istio Egress Gateway** - Optional
  - Controlled external traffic
  - Not required for basic Galasa deployment

## Network Requirements

Ensure the following ports are accessible:

| Component | Port | Protocol | Purpose |
|-----------|------|----------|---------|
| Istiod | 15010 | TCP | XDS and CA services |
| Istiod | 15012 | TCP | XDS and CA services (TLS) |
| Istiod | 15014 | TCP | Control plane monitoring |
| Istiod | 15017 | TCP | Webhook container port |
| Ingress Gateway | 80 | TCP | HTTP |
| Ingress Gateway | 443 | TCP | HTTPS |
| Ingress Gateway | 15021 | TCP | Health checks |

## Installation Methods

Choose one of the following installation methods:

### Method 1: Install ISTIO using istioctl (Recommended)

This is the recommended method for production deployments.

#### Step 1: Download istioctl

```bash
# Download the latest ISTIO release
curl -L https://istio.io/downloadIstio | sh -

# Navigate to the ISTIO directory (version may vary)
cd istio-1.20.0

# Add istioctl to your PATH
export PATH=$PWD/bin:$PATH

# Verify installation
istioctl version
```

#### Step 2: Install ISTIO with Default Profile

```bash
# Install ISTIO with the default configuration profile
istioctl install --set profile=default -y
```

The default profile includes:
- Istiod (control plane)
- Istio Ingress Gateway
- Recommended settings for production

#### Step 3: Verify Installation

```bash
# Check ISTIO components are running
kubectl get pods -n istio-system

# Expected output:
# NAME                                    READY   STATUS    RESTARTS   AGE
# istiod-xxxxx                           1/1     Running   0          2m
# istio-ingressgateway-xxxxx             1/1     Running   0          2m

# Verify ISTIO version
istioctl version

# Check webhook configuration
kubectl get mutatingwebhookconfigurations | grep istio
```

### Method 2: Install ISTIO using Helm

This method provides more control over configuration and is suitable for GitOps workflows.

#### Step 1: Add ISTIO Helm Repository

```bash
# Add the ISTIO Helm repository
helm repo add istio https://istio-release.storage.googleapis.com/charts

# Update Helm repositories
helm repo update

# Verify the repository
helm search repo istio
```

#### Step 2: Create ISTIO System Namespace

```bash
# Create the istio-system namespace
kubectl create namespace istio-system
```

#### Step 3: Install ISTIO Base Chart

The base chart contains cluster-wide resources and CRDs.

```bash
helm install istio-base istio/base \
  -n istio-system \
  --version 1.20.0 \
  --wait
```

#### Step 4: Install Istiod (Control Plane)

```bash
helm install istiod istio/istiod \
  -n istio-system \
  --version 1.20.0 \
  --wait
```

#### Step 5: Install ISTIO Ingress Gateway

```bash
helm install istio-ingress istio/gateway \
  -n istio-system \
  --version 1.20.0 \
  --wait
```

#### Step 6: Verify Installation

```bash
# Check all ISTIO components
kubectl get pods -n istio-system

# Check Helm releases
helm list -n istio-system

# Verify ISTIO CRDs
kubectl get crd | grep istio
```

## Post-Installation Configuration

### Configure Namespace for Galasa Deployment

After ISTIO is installed, configure the namespace where Galasa will be deployed:

#### Step 1: Create Namespace (if it doesn't exist)

```bash
# Create the Galasa namespace
kubectl create namespace galasa
```

#### Step 2: Enable Automatic Sidecar Injection

```bash
# Label the namespace for automatic sidecar injection
kubectl label namespace galasa istio-injection=enabled

# Verify the label
kubectl get namespace galasa --show-labels
```

Expected output should include: `istio-injection=enabled`

#### Step 3: Verify Sidecar Injection Configuration

```bash
# Check the sidecar injector configuration
kubectl get mutatingwebhookconfigurations istio-sidecar-injector -o yaml

# Test sidecar injection (optional)
kubectl run test-pod --image=nginx -n galasa
kubectl get pod test-pod -n galasa -o jsonpath='{.spec.containers[*].name}'
# Should show: nginx istio-proxy

# Clean up test pod
kubectl delete pod test-pod -n galasa
```

## Validation and Testing

### Verify ISTIO Installation

Run the following commands to ensure ISTIO is properly installed:

```bash
# Check ISTIO installation status
istioctl verify-install

# Analyze ISTIO configuration
istioctl analyze -n galasa

# Check ISTIO proxy status (after deploying workloads)
istioctl proxy-status
```

### Test mTLS Configuration

After deploying Galasa, verify mTLS is working:

```bash
# Check mTLS status for a specific pod
istioctl authn tls-check <pod-name>.<namespace>

# View certificates
istioctl proxy-config secret <pod-name> -n galasa
```

## Troubleshooting

### ISTIO Pods Not Starting

**Symptoms**: Istiod or ingress gateway pods stuck in Pending or CrashLoopBackOff

**Solutions**:
1. Check resource availability:
   ```bash
   kubectl describe pod <pod-name> -n istio-system
   ```

2. Check node resources:
   ```bash
   kubectl top nodes
   ```

3. Review pod logs:
   ```bash
   kubectl logs <pod-name> -n istio-system
   ```

### Sidecar Not Injecting

**Symptoms**: Pods in labeled namespace don't have istio-proxy container

**Solutions**:
1. Verify namespace label:
   ```bash
   kubectl get namespace galasa --show-labels
   ```

2. Check webhook configuration:
   ```bash
   kubectl get mutatingwebhookconfigurations
   ```

3. Check istiod logs:
   ```bash
   kubectl logs -n istio-system -l app=istiod
   ```

4. Manually trigger injection (for testing):
   ```bash
   kubectl get deployment <deployment-name> -n galasa -o yaml | \
     istioctl kube-inject -f - | \
     kubectl apply -f -
   ```

### Certificate Issues

**Symptoms**: Services cannot communicate, TLS errors in logs

**Solutions**:
1. Check certificate status:
   ```bash
   istioctl proxy-config secret <pod-name> -n galasa
   ```

2. Restart istiod to regenerate certificates:
   ```bash
   kubectl rollout restart deployment istiod -n istio-system
   ```

3. Check certificate expiry:
   ```bash
   kubectl get secret -n istio-system istio-ca-secret -o yaml
   ```

### Performance Issues

**Symptoms**: High latency, slow response times

**Solutions**:
1. Check proxy resource usage:
   ```bash
   kubectl top pods -n galasa
   ```

2. Adjust proxy resources in Galasa values.yaml:
   ```yaml
   istio:
     proxy:
       resources:
         requests:
           cpu: "200m"
           memory: "256Mi"
   ```

3. Review ISTIO metrics:
   ```bash
   istioctl dashboard prometheus
   ```

## Monitoring and Observability

### Install ISTIO Addons (Optional)

For enhanced observability, install ISTIO addons:

```bash
# Navigate to ISTIO directory
cd istio-1.20.0

# Install Prometheus
kubectl apply -f samples/addons/prometheus.yaml

# Install Grafana
kubectl apply -f samples/addons/grafana.yaml

# Install Kiali (Service Mesh Dashboard)
kubectl apply -f samples/addons/kiali.yaml

# Install Jaeger (Distributed Tracing)
kubectl apply -f samples/addons/jaeger.yaml
```

### Access Dashboards

```bash
# Kiali dashboard
istioctl dashboard kiali

# Grafana dashboard
istioctl dashboard grafana

# Prometheus dashboard
istioctl dashboard prometheus

# Jaeger dashboard
istioctl dashboard jaeger
```

## Upgrading ISTIO

To upgrade ISTIO to a newer version:

```bash
# Download new version
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.21.0 sh -

# Check upgrade compatibility
istioctl x precheck

# Perform canary upgrade (recommended)
istioctl upgrade --set profile=default

# Or direct upgrade
istioctl install --set profile=default -y
```

## Uninstalling ISTIO

If you need to remove ISTIO:

```bash
# Using istioctl
istioctl uninstall --purge -y

# Remove namespace
kubectl delete namespace istio-system

# Or using Helm
helm uninstall istio-ingress -n istio-system
helm uninstall istiod -n istio-system
helm uninstall istio-base -n istio-system
kubectl delete namespace istio-system
```

## Next Steps

After successfully installing ISTIO:

1. Proceed to deploy the Galasa Ecosystem with ISTIO enabled
2. Follow the [Galasa Ecosystem Installation Guide](../README.md)
3. Enable ISTIO in your `values.yaml`:
   ```yaml
   istio:
     enabled: true
     mtlsMode: "PERMISSIVE"
   ```

## Additional Resources

- [ISTIO Official Documentation](https://istio.io/latest/docs/)
- [ISTIO Best Practices](https://istio.io/latest/docs/ops/best-practices/)
- [ISTIO Performance and Scalability](https://istio.io/latest/docs/ops/deployment/performance-and-scalability/)
- [Galasa ISTIO Configuration Guide](./istio-configuration.md)
- [Galasa ISTIO Migration Guide](./istio-migration.md)

## Support

For issues specific to Galasa with ISTIO:
- Check the [Troubleshooting Guide](./istio-troubleshooting.md)
- Review [GitHub Issues](https://github.com/galasa-dev/helm/issues)
- Contact Galasa support team

For ISTIO-specific issues:
- Visit [ISTIO Community](https://istio.io/latest/about/community/)
- Check [ISTIO GitHub](https://github.com/istio/istio)