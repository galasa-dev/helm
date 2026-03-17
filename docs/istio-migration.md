# Migrating Existing Galasa Deployment to ISTIO Service Mesh

This guide provides step-by-step instructions for migrating an existing Galasa Ecosystem deployment to use ISTIO service mesh with minimal downtime.

## Overview

The migration process uses a phased approach to ensure zero downtime:

1. **Phase 1**: Install ISTIO (if not already installed)
2. **Phase 2**: Enable PERMISSIVE mTLS mode (accepts both mTLS and plain text)
3. **Phase 3**: Test and validate functionality
4. **Phase 4**: Switch to STRICT mTLS mode (mTLS only)
5. **Phase 5**: Monitor and optimize

## Prerequisites

Before starting the migration:

- [ ] Backup current Galasa configuration
- [ ] Backup current `values.yaml` file
- [ ] Document current service endpoints
- [ ] Ensure you have cluster-admin access
- [ ] Schedule maintenance window (recommended, though not required)
- [ ] Notify users of potential brief service interruptions
- [ ] Have rollback plan ready

## Pre-Migration Checklist

```bash
# 1. Backup current configuration
kubectl get all -n <galasa-namespace> -o yaml > galasa-backup.yaml

# 2. Export current Helm values
helm get values <release-name> -n <galasa-namespace> > current-values.yaml

# 3. Check current pod status
kubectl get pods -n <galasa-namespace>

# 4. Test current functionality
# Run a test suite to establish baseline
```

## Phase 1: Install ISTIO

If ISTIO is not already installed in your cluster, follow the [ISTIO Installation Guide](./istio-installation.md).

### Verify ISTIO Installation

```bash
# Check ISTIO is running
kubectl get pods -n istio-system

# Verify version
istioctl version

# Expected output should show both client and control plane versions
```

## Phase 2: Enable PERMISSIVE mTLS Mode

PERMISSIVE mode allows both mTLS and plain text traffic, enabling a gradual migration.

### Step 1: Update values.yaml

Create or update your `values.yaml` file with ISTIO configuration:

```yaml
# Enable ISTIO with PERMISSIVE mode
istio:
  enabled: true
  mtlsMode: "PERMISSIVE"  # Accepts both mTLS and plain text
  
  # Configure proxy resources
  proxy:
    resources:
      requests:
        cpu: "100m"
        memory: "128Mi"
      limits:
        cpu: "200m"
        memory: "256Mi"
```

### Step 2: Label Namespace for Sidecar Injection

```bash
# Label your Galasa namespace
kubectl label namespace <galasa-namespace> istio-injection=enabled

# Verify the label
kubectl get namespace <galasa-namespace> --show-labels
```

### Step 3: Upgrade Galasa Ecosystem

```bash
# Perform Helm upgrade
helm upgrade <release-name> galasa/ecosystem \
  -f values.yaml \
  -n <galasa-namespace> \
  --wait

# Monitor the upgrade
kubectl get pods -n <galasa-namespace> -w
```

### Step 4: Verify Sidecar Injection

After the upgrade, all pods should restart with ISTIO sidecars:

```bash
# Check pod container count (should be 2/2 for most pods)
kubectl get pods -n <galasa-namespace>

# Verify istio-proxy container is present
kubectl get pod <pod-name> -n <galasa-namespace> -o jsonpath='{.spec.containers[*].name}'

# Expected output: <app-container> istio-proxy
```

### Step 5: Check ISTIO Proxy Status

```bash
# View proxy status for all pods
istioctl proxy-status

# Check specific pod configuration
istioctl proxy-config cluster <pod-name> -n <galasa-namespace>
```

## Phase 3: Test and Validate

### Functional Testing

1. **API Server Testing**:
   ```bash
   # Test API endpoints
   curl -k https://<external-hostname>/api/health
   
   # Test authentication
   # Login via WebUI or CLI
   ```

2. **Run Test Suite**:
   ```bash
   # Submit a test run
   galasactl runs submit \
     --bootstrap https://<external-hostname>/api/bootstrap \
     --class <test-class>
   
   # Monitor test execution
   galasactl runs get --name <run-name>
   ```

3. **Check Service Communication**:
   ```bash
   # View service mesh traffic
   istioctl dashboard kiali
   
   # Check mTLS status
   istioctl authn tls-check <pod-name>.<namespace>
   ```

### Verify mTLS is Working

```bash
# Check which connections are using mTLS
kubectl exec <api-pod-name> -n <galasa-namespace> -c istio-proxy -- \
  pilot-agent request GET stats | grep ssl

# View certificates
istioctl proxy-config secret <pod-name> -n <galasa-namespace>
```

### Performance Validation

```bash
# Check pod resource usage
kubectl top pods -n <galasa-namespace>

# Compare with pre-migration baseline
# Expect 5-10% overhead from ISTIO proxies
```

### Monitor Logs

```bash
# Check for any errors in application logs
kubectl logs <pod-name> -n <galasa-namespace> -c <container-name>

# Check ISTIO proxy logs
kubectl logs <pod-name> -n <galasa-namespace> -c istio-proxy

# Check istiod logs
kubectl logs -n istio-system -l app=istiod
```

## Phase 4: Switch to STRICT mTLS Mode

After validating that everything works in PERMISSIVE mode, switch to STRICT mode for maximum security.

### Step 1: Update values.yaml

```yaml
istio:
  enabled: true
  mtlsMode: "STRICT"  # Only accept mTLS connections
  
  proxy:
    resources:
      requests:
        cpu: "100m"
        memory: "128Mi"
      limits:
        cpu: "200m"
        memory: "256Mi"
```

### Step 2: Apply the Change

```bash
# Upgrade with STRICT mode
helm upgrade <release-name> galasa/ecosystem \
  -f values.yaml \
  -n <galasa-namespace> \
  --wait

# Monitor the rollout
kubectl rollout status deployment -n <galasa-namespace>
```

### Step 3: Verify STRICT Mode

```bash
# Check PeerAuthentication policy
kubectl get peerauthentication -n <galasa-namespace>

# Verify mTLS is enforced
istioctl authn tls-check <pod-name>.<namespace>

# All connections should show "mTLS" in the output
```

### Step 4: Test Connectivity

```bash
# Ensure all services can still communicate
# Run comprehensive test suite

# Check for any connection errors
kubectl logs -n <galasa-namespace> --all-containers --tail=100 | grep -i "error\|fail"
```

## Phase 5: Monitor and Optimize

### Set Up Monitoring

```bash
# Access ISTIO dashboards
istioctl dashboard kiali &
istioctl dashboard grafana &
istioctl dashboard prometheus &
```

### Key Metrics to Monitor

1. **Request Success Rate**: Should remain at baseline levels
2. **Latency**: Expect 1-5ms additional latency from mTLS
3. **Resource Usage**: Monitor CPU and memory for proxy containers
4. **Certificate Rotation**: Verify automatic rotation works (default: 24h)

### Optimization Tips

1. **Adjust Proxy Resources** if needed:
   ```yaml
   istio:
     proxy:
       resources:
         requests:
           cpu: "150m"  # Increase if CPU-bound
           memory: "192Mi"  # Increase if memory-bound
   ```

2. **Configure Connection Pools**:
   ```yaml
   istio:
     trafficPolicy:
       connectionPool:
         tcp:
           maxConnections: 200  # Adjust based on load
         http:
           http1MaxPendingRequests: 100
           http2MaxRequests: 200
   ```

3. **Enable Circuit Breaking** (already configured in DestinationRules)

## Rollback Procedures

If issues occur during migration, follow these rollback steps:

### Rollback to Pre-ISTIO State

```bash
# 1. Disable ISTIO in values.yaml
cat > values-rollback.yaml <<EOF
istio:
  enabled: false
EOF

# 2. Upgrade with ISTIO disabled
helm upgrade <release-name> galasa/ecosystem \
  -f current-values.yaml \
  -f values-rollback.yaml \
  -n <galasa-namespace> \
  --wait

# 3. Remove namespace label
kubectl label namespace <galasa-namespace> istio-injection-

# 4. Restart pods to remove sidecars
kubectl rollout restart deployment -n <galasa-namespace>

# 5. Verify pods are running without sidecars
kubectl get pods -n <galasa-namespace>
# Should show 1/1 containers
```

### Rollback from STRICT to PERMISSIVE

If STRICT mode causes issues:

```bash
# Update values.yaml
cat > values-permissive.yaml <<EOF
istio:
  enabled: true
  mtlsMode: "PERMISSIVE"
EOF

# Apply the change
helm upgrade <release-name> galasa/ecosystem \
  -f values.yaml \
  -f values-permissive.yaml \
  -n <galasa-namespace> \
  --wait
```

## Common Migration Issues

### Issue 1: Pods Stuck in Pending

**Symptoms**: Pods not starting after enabling ISTIO

**Cause**: Insufficient cluster resources for sidecar containers

**Solution**:
```bash
# Check node resources
kubectl top nodes

# Check pod events
kubectl describe pod <pod-name> -n <galasa-namespace>

# Reduce proxy resource requests if needed
```

### Issue 2: Service Communication Failures

**Symptoms**: Services cannot communicate, connection refused errors

**Cause**: Incorrect mTLS configuration or port naming

**Solution**:
```bash
# Check PeerAuthentication
kubectl get peerauthentication -n <galasa-namespace> -o yaml

# Verify DestinationRules
kubectl get destinationrule -n <galasa-namespace> -o yaml

# Check service port names (should be protocol-prefixed)
kubectl get svc -n <galasa-namespace> -o yaml
```

### Issue 3: Certificate Errors

**Symptoms**: TLS handshake failures, certificate validation errors

**Cause**: Certificate not properly distributed or expired

**Solution**:
```bash
# Check certificate status
istioctl proxy-config secret <pod-name> -n <galasa-namespace>

# Restart istiod to regenerate certificates
kubectl rollout restart deployment istiod -n istio-system

# Restart affected pods
kubectl rollout restart deployment <deployment-name> -n <galasa-namespace>
```

### Issue 4: Performance Degradation

**Symptoms**: Increased latency, slow response times

**Cause**: Insufficient proxy resources or misconfiguration

**Solution**:
```bash
# Check proxy resource usage
kubectl top pods -n <galasa-namespace>

# Increase proxy resources in values.yaml
# Review connection pool settings
# Check for any proxy errors in logs
```

## Post-Migration Checklist

After successful migration:

- [ ] All pods running with 2/2 containers
- [ ] All services communicating successfully
- [ ] Test suite passing
- [ ] mTLS verified on all connections
- [ ] Performance within acceptable range
- [ ] Monitoring dashboards configured
- [ ] Documentation updated
- [ ] Team trained on ISTIO operations
- [ ] Backup of working configuration saved

## Best Practices

1. **Gradual Rollout**: Start with PERMISSIVE mode, validate, then move to STRICT
2. **Monitor Continuously**: Use ISTIO dashboards to track service health
3. **Test Thoroughly**: Run comprehensive tests at each phase
4. **Document Changes**: Keep detailed notes of configuration changes
5. **Plan Rollback**: Always have a tested rollback procedure ready
6. **Communicate**: Keep stakeholders informed of migration progress

## Next Steps

After successful migration:

1. Review [ISTIO Configuration Guide](./istio-configuration.md) for advanced features
2. Set up [ISTIO Monitoring](./istio-installation.md#monitoring-and-observability)
3. Configure [Traffic Management](./istio-configuration.md#traffic-management) policies
4. Implement [Security Policies](./istio-configuration.md#security-policies)
5. Plan for regular ISTIO upgrades

## Additional Resources

- [ISTIO Installation Guide](./istio-installation.md)
- [ISTIO Troubleshooting Guide](./istio-troubleshooting.md)
- [ISTIO Test Plan](./istio-test-plan.md)
- [Galasa Documentation](https://galasa.dev)
- [ISTIO Official Documentation](https://istio.io/latest/docs/)

## Support

For migration assistance:
- Review [Troubleshooting Guide](./istio-troubleshooting.md)
- Check [GitHub Issues](https://github.com/galasa-dev/helm/issues)
- Contact Galasa support team