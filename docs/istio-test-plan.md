# ISTIO Integration Test Plan for Galasa Ecosystem

This document outlines the comprehensive test plan for validating ISTIO service mesh integration with the Galasa Ecosystem.

## Test Environment Requirements

### Infrastructure
- Kubernetes cluster v1.26+
- ISTIO v1.20.0+ installed
- Helm v3.x
- kubectl with cluster-admin access
- Sufficient cluster resources (minimum 8 CPU cores, 16GB RAM)

### Test Tools
- `istioctl` CLI tool
- `galasactl` CLI tool
- `curl` or similar HTTP client
- Load testing tool (optional): `hey`, `k6`, or `Apache JMeter`

### Test Data
- Sample Galasa test classes
- Test configuration properties
- Authentication credentials
- Performance baseline metrics

## Test Phases

### Phase 1: Pre-Installation Tests
### Phase 2: ISTIO Installation Validation
### Phase 3: Galasa Deployment with ISTIO
### Phase 4: Functional Testing
### Phase 5: Security Testing
### Phase 6: Performance Testing
### Phase 7: Failure Scenario Testing
### Phase 8: Rollback Testing

---

## Phase 1: Pre-Installation Tests

### TC1.1: Cluster Prerequisites Validation

**Objective**: Verify cluster meets minimum requirements

**Steps**:
```bash
# Check Kubernetes version
kubectl version --short

# Check available resources
kubectl top nodes

# Check storage classes
kubectl get storageclass
```

**Expected Results**:
- Kubernetes version ≥ 1.26
- Sufficient CPU and memory available
- Valid storage class exists

**Status**: [ ] Pass [ ] Fail

---

### TC1.2: Baseline Performance Measurement

**Objective**: Establish performance baseline without ISTIO

**Steps**:
```bash
# Deploy Galasa without ISTIO
helm install galasa-baseline galasa/ecosystem -f values-no-istio.yaml

# Run performance tests
# Measure: API response time, test execution time, resource usage

# Record baseline metrics
```

**Expected Results**:
- Baseline metrics recorded for comparison
- All services functioning normally

**Status**: [ ] Pass [ ] Fail

---

## Phase 2: ISTIO Installation Validation

### TC2.1: ISTIO Component Installation

**Objective**: Verify ISTIO components are properly installed

**Steps**:
```bash
# Check ISTIO namespace
kubectl get namespace istio-system

# Check ISTIO pods
kubectl get pods -n istio-system

# Verify istiod
kubectl get deployment istiod -n istio-system

# Verify ingress gateway
kubectl get deployment istio-ingressgateway -n istio-system
```

**Expected Results**:
- `istio-system` namespace exists
- `istiod` pod running (1/1)
- `istio-ingressgateway` pod running (1/1)
- All pods in Ready state

**Status**: [ ] Pass [ ] Fail

---

### TC2.2: ISTIO Webhook Configuration

**Objective**: Verify sidecar injection webhook is configured

**Steps**:
```bash
# Check mutating webhook
kubectl get mutatingwebhookconfigurations | grep istio

# Verify webhook configuration
kubectl get mutatingwebhookconfigurations istio-sidecar-injector -o yaml
```

**Expected Results**:
- Webhook configuration exists
- Webhook is active and properly configured
- Namespace selector includes labeled namespaces

**Status**: [ ] Pass [ ] Fail

---

### TC2.3: ISTIO Version Verification

**Objective**: Confirm ISTIO version meets requirements

**Steps**:
```bash
# Check ISTIO version
istioctl version

# Verify control plane version
kubectl get deployment istiod -n istio-system -o yaml | grep image:
```

**Expected Results**:
- ISTIO version ≥ 1.18.0
- Client and control plane versions match
- Recommended version 1.20.0 or higher

**Status**: [ ] Pass [ ] Fail

---

## Phase 3: Galasa Deployment with ISTIO

### TC3.1: Namespace Configuration

**Objective**: Verify namespace is properly configured for ISTIO

**Steps**:
```bash
# Create/verify namespace
kubectl create namespace galasa-istio-test

# Label namespace for sidecar injection
kubectl label namespace galasa-istio-test istio-injection=enabled

# Verify label
kubectl get namespace galasa-istio-test --show-labels
```

**Expected Results**:
- Namespace exists
- Label `istio-injection=enabled` is present

**Status**: [ ] Pass [ ] Fail

---

### TC3.2: Galasa Deployment with ISTIO Enabled

**Objective**: Deploy Galasa with ISTIO integration

**Steps**:
```bash
# Deploy Galasa with ISTIO enabled
helm install galasa-istio galasa/ecosystem \
  -f values-istio-permissive.yaml \
  -n galasa-istio-test \
  --wait

# Monitor deployment
kubectl get pods -n galasa-istio-test -w
```

**Expected Results**:
- All pods deploy successfully
- Each pod shows 2/2 containers (app + istio-proxy)
- No CrashLoopBackOff or Error states

**Status**: [ ] Pass [ ] Fail

---

### TC3.3: Sidecar Injection Verification

**Objective**: Confirm ISTIO sidecars are injected into all pods

**Steps**:
```bash
# Check all pods have sidecars
kubectl get pods -n galasa-istio-test

# Verify specific pod containers
kubectl get pod <api-pod-name> -n galasa-istio-test -o jsonpath='{.spec.containers[*].name}'

# Check for all components
for pod in $(kubectl get pods -n galasa-istio-test -o name); do
  echo "Checking $pod"
  kubectl get $pod -n galasa-istio-test -o jsonpath='{.spec.containers[*].name}'
  echo ""
done
```

**Expected Results**:
- All pods show 2/2 containers
- Each pod has `istio-proxy` container
- Components verified: API, Engine Controller, etcd, RAS, Dex, WebUI, Metrics, Resource Monitors

**Status**: [ ] Pass [ ] Fail

---

### TC3.4: ISTIO Proxy Status

**Objective**: Verify ISTIO proxies are healthy and synchronized

**Steps**:
```bash
# Check proxy status
istioctl proxy-status

# Verify proxy configuration sync
istioctl proxy-config cluster <pod-name> -n galasa-istio-test
```

**Expected Results**:
- All proxies show "SYNCED" status
- No configuration errors
- Proxies connected to istiod

**Status**: [ ] Pass [ ] Fail

---

## Phase 4: Functional Testing

### TC4.1: API Server Accessibility

**Objective**: Verify API server is accessible and functional

**Steps**:
```bash
# Test health endpoint
curl -k https://<external-hostname>/api/health

# Test bootstrap endpoint
curl -k https://<external-hostname>/api/bootstrap

# Test authentication
# Login via WebUI or CLI
```

**Expected Results**:
- Health endpoint returns 200 OK
- Bootstrap endpoint returns valid JSON
- Authentication works correctly

**Status**: [ ] Pass [ ] Fail

---

### TC4.2: Service-to-Service Communication

**Objective**: Verify internal services can communicate via mTLS

**Steps**:
```bash
# Check API to etcd communication
kubectl logs <api-pod-name> -n galasa-istio-test -c api | grep etcd

# Check API to RAS communication
kubectl logs <api-pod-name> -n galasa-istio-test -c api | grep couchdb

# Check Engine Controller to etcd
kubectl logs <engine-controller-pod> -n galasa-istio-test -c engine-controller | grep etcd
```

**Expected Results**:
- No connection errors in logs
- Services successfully communicate
- mTLS connections established

**Status**: [ ] Pass [ ] Fail

---

### TC4.3: Test Execution

**Objective**: Verify test pods can be created and execute successfully

**Steps**:
```bash
# Submit a test run
galasactl runs submit \
  --bootstrap https://<external-hostname>/api/bootstrap \
  --class dev.galasa.example.TestClass \
  --stream inttests

# Monitor test pod creation
kubectl get pods -n galasa-istio-test -w

# Check test pod has sidecar
kubectl get pod <test-pod-name> -n galasa-istio-test -o jsonpath='{.spec.containers[*].name}'

# Wait for test completion
galasactl runs get --name <run-name>
```

**Expected Results**:
- Test pod created successfully
- Test pod has istio-proxy sidecar (2/2 containers)
- Test executes and completes
- Test results stored in RAS

**Status**: [ ] Pass [ ] Fail

---

### TC4.4: WebUI Functionality

**Objective**: Verify WebUI is accessible and functional

**Steps**:
```bash
# Access WebUI
open https://<external-hostname>

# Test navigation
# - Login page
# - Dashboard
# - Test runs page
# - Test results page
```

**Expected Results**:
- WebUI loads successfully
- All pages render correctly
- No JavaScript errors
- Data displays correctly

**Status**: [ ] Pass [ ] Fail

---

### TC4.5: Metrics Collection

**Objective**: Verify metrics service is collecting data

**Steps**:
```bash
# Check metrics endpoint
curl -k https://<external-hostname>/metrics

# Verify Prometheus metrics
kubectl port-forward -n galasa-istio-test svc/<metrics-service> 9090:9090
# Access http://localhost:9090
```

**Expected Results**:
- Metrics endpoint accessible
- Metrics data being collected
- No errors in metrics pod logs

**Status**: [ ] Pass [ ] Fail

---

## Phase 5: Security Testing

### TC5.1: mTLS Verification - PERMISSIVE Mode

**Objective**: Verify mTLS is working in PERMISSIVE mode

**Steps**:
```bash
# Check mTLS status
istioctl authn tls-check <api-pod-name>.<namespace>

# Verify connections accept both mTLS and plain text
kubectl exec <api-pod-name> -n galasa-istio-test -c istio-proxy -- \
  pilot-agent request GET stats | grep ssl
```

**Expected Results**:
- mTLS connections shown as "mTLS"
- Plain text connections also accepted
- No connection failures

**Status**: [ ] Pass [ ] Fail

---

### TC5.2: mTLS Verification - STRICT Mode

**Objective**: Verify STRICT mTLS mode enforces encryption

**Steps**:
```bash
# Update to STRICT mode
helm upgrade galasa-istio galasa/ecosystem \
  -f values-istio-strict.yaml \
  -n galasa-istio-test \
  --wait

# Check PeerAuthentication
kubectl get peerauthentication -n galasa-istio-test -o yaml

# Verify all connections use mTLS
istioctl authn tls-check <api-pod-name>.<namespace>

# Attempt plain text connection (should fail)
kubectl run test-client --image=curlimages/curl -n galasa-istio-test -- \
  curl http://<service-name>:8080
```

**Expected Results**:
- PeerAuthentication mode is STRICT
- All connections show "mTLS"
- Plain text connections rejected
- Services continue functioning

**Status**: [ ] Pass [ ] Fail

---

### TC5.3: Certificate Validation

**Objective**: Verify certificates are properly issued and valid

**Steps**:
```bash
# Check certificate status
istioctl proxy-config secret <api-pod-name> -n galasa-istio-test

# Verify certificate details
kubectl exec <api-pod-name> -n galasa-istio-test -c istio-proxy -- \
  openssl s_client -connect <service-name>:8080 -showcerts
```

**Expected Results**:
- Certificates present and valid
- Issued by ISTIO CA
- Expiry date in future (default: 24h from issue)
- Certificate chain complete

**Status**: [ ] Pass [ ] Fail

---

### TC5.4: Certificate Rotation

**Objective**: Verify automatic certificate rotation works

**Steps**:
```bash
# Record current certificate serial number
istioctl proxy-config secret <api-pod-name> -n galasa-istio-test | grep ROOTCA

# Wait for rotation period (or force rotation)
# Default rotation: 24 hours

# Check new certificate issued
istioctl proxy-config secret <api-pod-name> -n galasa-istio-test | grep ROOTCA

# Verify services still communicate
# Run test suite
```

**Expected Results**:
- New certificate issued after rotation period
- Serial number changed
- No service disruption
- All services continue functioning

**Status**: [ ] Pass [ ] Fail

---

### TC5.5: Authorization Policies

**Objective**: Verify ISTIO authorization policies work correctly

**Steps**:
```bash
# Apply test authorization policy
kubectl apply -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: test-deny-all
  namespace: galasa-istio-test
spec:
  action: DENY
  rules:
  - from:
    - source:
        notNamespaces: ["galasa-istio-test"]
EOF

# Test external access (should be denied)
# Test internal access (should work)

# Remove policy
kubectl delete authorizationpolicy test-deny-all -n galasa-istio-test
```

**Expected Results**:
- Policy applied successfully
- External access denied
- Internal access allowed
- Policy removal restores access

**Status**: [ ] Pass [ ] Fail

---

## Phase 6: Performance Testing

### TC6.1: Latency Measurement

**Objective**: Measure latency overhead introduced by ISTIO

**Steps**:
```bash
# Measure API response time with ISTIO
for i in {1..100}; do
  curl -w "%{time_total}\n" -o /dev/null -s https://<external-hostname>/api/health
done | awk '{sum+=$1; count++} END {print "Average:", sum/count}'

# Compare with baseline (without ISTIO)
```

**Expected Results**:
- Average latency increase < 5ms
- P95 latency increase < 10ms
- No timeout errors

**Status**: [ ] Pass [ ] Fail

---

### TC6.2: Throughput Testing

**Objective**: Measure throughput with ISTIO enabled

**Steps**:
```bash
# Run load test
hey -n 10000 -c 50 -m GET https://<external-hostname>/api/health

# Compare with baseline throughput
```

**Expected Results**:
- Throughput reduction < 10%
- No failed requests
- Acceptable response times under load

**Status**: [ ] Pass [ ] Fail

---

### TC6.3: Resource Usage

**Objective**: Measure resource overhead of ISTIO proxies

**Steps**:
```bash
# Check pod resource usage
kubectl top pods -n galasa-istio-test

# Check proxy-specific usage
kubectl top pods -n galasa-istio-test --containers | grep istio-proxy

# Compare with baseline (without ISTIO)
```

**Expected Results**:
- Proxy CPU usage < 100m per pod
- Proxy memory usage < 128Mi per pod
- Total overhead < 15% of baseline

**Status**: [ ] Pass [ ] Fail

---

### TC6.4: Test Execution Performance

**Objective**: Verify test execution time is not significantly impacted

**Steps**:
```bash
# Run standard test suite
# Measure execution time

# Compare with baseline execution time
```

**Expected Results**:
- Test execution time increase < 5%
- All tests pass
- No timeout issues

**Status**: [ ] Pass [ ] Fail

---

## Phase 7: Failure Scenario Testing

### TC7.1: Proxy Container Failure

**Objective**: Verify pod recovery when proxy fails

**Steps**:
```bash
# Kill istio-proxy container
kubectl exec <api-pod-name> -n galasa-istio-test -c istio-proxy -- kill 1

# Monitor pod status
kubectl get pod <api-pod-name> -n galasa-istio-test -w

# Verify service recovery
curl https://<external-hostname>/api/health
```

**Expected Results**:
- Pod restarts automatically
- Service recovers within 30 seconds
- No data loss
- Connections re-established

**Status**: [ ] Pass [ ] Fail

---

### TC7.2: Istiod Failure

**Objective**: Verify system continues functioning if istiod fails

**Steps**:
```bash
# Scale down istiod
kubectl scale deployment istiod -n istio-system --replicas=0

# Test service communication
curl https://<external-hostname>/api/health

# Run test
galasactl runs submit --class dev.galasa.example.TestClass

# Scale up istiod
kubectl scale deployment istiod -n istio-system --replicas=1
```

**Expected Results**:
- Existing connections continue working
- New connections may fail temporarily
- System recovers when istiod returns
- No permanent damage

**Status**: [ ] Pass [ ] Fail

---

### TC7.3: Network Partition

**Objective**: Verify behavior during network issues

**Steps**:
```bash
# Simulate network delay
kubectl exec <api-pod-name> -n galasa-istio-test -c istio-proxy -- \
  tc qdisc add dev eth0 root netem delay 100ms

# Test service behavior
# Monitor for timeouts or errors

# Remove network delay
kubectl exec <api-pod-name> -n galasa-istio-test -c istio-proxy -- \
  tc qdisc del dev eth0 root
```

**Expected Results**:
- Services handle delays gracefully
- Retries work correctly
- Circuit breakers activate if needed
- System recovers when network improves

**Status**: [ ] Pass [ ] Fail

---

### TC7.4: Pod Scaling

**Objective**: Verify ISTIO works correctly during pod scaling

**Steps**:
```bash
# Scale up API server
kubectl scale deployment <api-deployment> -n galasa-istio-test --replicas=5

# Verify new pods get sidecars
kubectl get pods -n galasa-istio-test

# Test load balancing
for i in {1..20}; do
  curl https://<external-hostname>/api/health
done

# Scale down
kubectl scale deployment <api-deployment> -n galasa-istio-test --replicas=2
```

**Expected Results**:
- New pods get sidecars automatically
- Load balancing works correctly
- No connection errors during scaling
- Graceful pod termination

**Status**: [ ] Pass [ ] Fail

---

## Phase 8: Rollback Testing

### TC8.1: Disable ISTIO

**Objective**: Verify clean rollback to non-ISTIO deployment

**Steps**:
```bash
# Disable ISTIO in values
helm upgrade galasa-istio galasa/ecosystem \
  -f values-no-istio.yaml \
  -n galasa-istio-test \
  --wait

# Remove namespace label
kubectl label namespace galasa-istio-test istio-injection-

# Verify pods restart without sidecars
kubectl get pods -n galasa-istio-test
```

**Expected Results**:
- Pods restart successfully
- Pods show 1/1 containers (no sidecar)
- All services function normally
- No data loss

**Status**: [ ] Pass [ ] Fail

---

### TC8.2: Re-enable ISTIO

**Objective**: Verify ISTIO can be re-enabled after rollback

**Steps**:
```bash
# Re-label namespace
kubectl label namespace galasa-istio-test istio-injection=enabled

# Re-enable ISTIO
helm upgrade galasa-istio galasa/ecosystem \
  -f values-istio-permissive.yaml \
  -n galasa-istio-test \
  --wait

# Verify sidecars injected
kubectl get pods -n galasa-istio-test
```

**Expected Results**:
- Pods restart with sidecars
- All services function normally
- mTLS re-established
- No configuration issues

**Status**: [ ] Pass [ ] Fail

---

## Test Summary Report Template

```
ISTIO Integration Test Report
Date: _______________
Tester: _______________
Environment: _______________

Phase 1: Pre-Installation Tests
  TC1.1: [ ] Pass [ ] Fail
  TC1.2: [ ] Pass [ ] Fail

Phase 2: ISTIO Installation Validation
  TC2.1: [ ] Pass [ ] Fail
  TC2.2: [ ] Pass [ ] Fail
  TC2.3: [ ] Pass [ ] Fail

Phase 3: Galasa Deployment with ISTIO
  TC3.1: [ ] Pass [ ] Fail
  TC3.2: [ ] Pass [ ] Fail
  TC3.3: [ ] Pass [ ] Fail
  TC3.4: [ ] Pass [ ] Fail

Phase 4: Functional Testing
  TC4.1: [ ] Pass [ ] Fail
  TC4.2: [ ] Pass [ ] Fail
  TC4.3: [ ] Pass [ ] Fail
  TC4.4: [ ] Pass [ ] Fail
  TC4.5: [ ] Pass [ ] Fail

Phase 5: Security Testing
  TC5.1: [ ] Pass [ ] Fail
  TC5.2: [ ] Pass [ ] Fail
  TC5.3: [ ] Pass [ ] Fail
  TC5.4: [ ] Pass [ ] Fail
  TC5.5: [ ] Pass [ ] Fail

Phase 6: Performance Testing
  TC6.1: [ ] Pass [ ] Fail
  TC6.2: [ ] Pass [ ] Fail
  TC6.3: [ ] Pass [ ] Fail
  TC6.4: [ ] Pass [ ] Fail

Phase 7: Failure Scenario Testing
  TC7.1: [ ] Pass [ ] Fail
  TC7.2: [ ] Pass [ ] Fail
  TC7.3: [ ] Pass [ ] Fail
  TC7.4: [ ] Pass [ ] Fail

Phase 8: Rollback Testing
  TC8.1: [ ] Pass [ ] Fail
  TC8.2: [ ] Pass [ ] Fail

Overall Result: [ ] Pass [ ] Fail
Total Tests: 26
Passed: ___
Failed: ___
Pass Rate: ___%

Issues Found:
1. _______________
2. _______________

Recommendations:
1. _______________
2. _______________
```

## Success Criteria

The ISTIO integration is considered successful if:

- [ ] All test cases pass (100% pass rate)
- [ ] Performance overhead < 10%
- [ ] Latency increase < 5ms average
- [ ] Zero data loss during migration
- [ ] All Galasa functionality works with ISTIO
- [ ] mTLS properly configured and working
- [ ] Certificate rotation works automatically
- [ ] Rollback procedure tested and verified
- [ ] Documentation complete and accurate

## Additional Resources

- [ISTIO Installation Guide](./istio-installation.md)
- [ISTIO Migration Guide](./istio-migration.md)
- [ISTIO Troubleshooting Guide](./istio-troubleshooting.md)
- [Galasa Documentation](https://galasa.dev)