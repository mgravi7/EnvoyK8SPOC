# Troubleshooting Guide - EnvoyK8SPOC

Common issues and solutions for EnvoyK8SPOC Kubernetes deployment.

## Table of Contents
- [Pod Issues](#pod-issues)
- [Service Issues](#service-issues)
- [Network Issues](#network-issues)
- [Application Issues](#application-issues)
- [Performance Issues](#performance-issues)
- [Debugging Commands](#debugging-commands)

## Pod Issues

### Pods Stuck in Pending

**Symptoms:**
```bash
kubectl get pods -n api-gateway-poc
NAME                   READY   STATUS    RESTARTS   AGE
redis-xxx              0/1     Pending   0          5m
```

**Common Causes:**
1. Insufficient cluster resources
2. PVC not bound
3. Node selector mismatch

**Solutions:**
```bash
# Check pod events
kubectl describe pod redis-xxx -n api-gateway-poc

# Check PVC status
kubectl get pvc -n api-gateway-poc

# Increase Docker Desktop resources
# Settings -> Resources -> Memory: 4GB+

# Check nodes
kubectl get nodes
kubectl describe node docker-desktop
```

### Pods in CrashLoopBackOff

**Symptoms:**
```bash
NAME                   READY   STATUS             RESTARTS   AGE
customer-service-xxx   0/1     CrashLoopBackOff   5          5m
```

**Common Causes:**
1. Application error on startup
2. Missing dependencies (e.g., Redis, Keycloak not ready)
3. Configuration error

**Solutions:**
```bash
# Check logs
kubectl logs customer-service-xxx -n api-gateway-poc

# Check previous container logs (if restarted)
kubectl logs customer-service-xxx -n api-gateway-poc --previous

# Check environment variables
kubectl describe pod customer-service-xxx -n api-gateway-poc | grep -A 20 Environment

# Verify dependencies are running
kubectl get pods -n api-gateway-poc

# Check ConfigMap
kubectl get configmap customer-config -n api-gateway-poc -o yaml
```

### Pods in ImagePullBackOff

**Symptoms:**
```bash
NAME             READY   STATUS             RESTARTS   AGE
envoy-xxx        0/1     ImagePullBackOff   0          2m
```

**Common Causes:**
1. Image not built locally
2. Image name mismatch
3. Wrong imagePullPolicy

**Solutions:**
```bash
# Check if image exists
docker images | grep envoy

# Rebuild image
cd scripts/bash
./build-images.sh

# Check deployment image name
kubectl get deployment envoy -n api-gateway-poc -o yaml | grep image:

# Verify imagePullPolicy is IfNotPresent
kubectl get deployment envoy -n api-gateway-poc -o yaml | grep imagePullPolicy
```

### Pods Not Ready (Readiness Probe Failing)

**Symptoms:**
```bash
NAME             READY   STATUS    RESTARTS   AGE
keycloak-xxx     0/1     Running   0          3m
```

**Common Causes:**
1. Application still starting up
2. Readiness probe misconfigured
3. Application health endpoint failing

**Solutions:**
```bash
# Check logs
kubectl logs keycloak-xxx -n api-gateway-poc

# Check readiness probe definition
kubectl get deployment keycloak -n api-gateway-poc -o yaml | grep -A 5 readinessProbe

# Test health endpoint manually (port-forward)
kubectl port-forward keycloak-xxx 8080:8080 -n api-gateway-poc
curl http://localhost:8080/health/ready

# Wait longer (Keycloak takes 90+ seconds)
kubectl get pods -n api-gateway-poc -w
```

## Service Issues

### Service Has No Endpoints

**Symptoms:**
```bash
kubectl get endpoints -n api-gateway-poc
NAME               ENDPOINTS
customer-service   <none>
```

**Common Causes:**
1. No pods match service selector
2. Pods not ready
3. Port mismatch

**Solutions:**
```bash
# Check service selector
kubectl get svc customer-service -n api-gateway-poc -o yaml | grep -A 3 selector

# Check pod labels
kubectl get pods -n api-gateway-poc --show-labels | grep customer

# Verify pod is ready
kubectl get pods -n api-gateway-poc | grep customer

# Check if ports match
kubectl get svc customer-service -n api-gateway-poc -o yaml | grep -A 3 ports
kubectl get pod <pod-name> -n api-gateway-poc -o yaml | grep -A 3 containerPort
```

### LoadBalancer Stuck in Pending

**Symptoms:**
```bash
kubectl get svc -n api-gateway-poc
NAME      TYPE           EXTERNAL-IP   PORT(S)
envoy     LoadBalancer   <pending>     8080:30123/TCP
```

**Common Causes:**
1. Docker Desktop LoadBalancer not ready
2. Port conflict

**Solutions:**
```bash
# Wait a minute (Docker Desktop assigns localhost automatically)
kubectl get svc -n api-gateway-poc

# Restart Docker Desktop

# Use NodePort or port-forward as alternative
kubectl port-forward -n api-gateway-poc svc/envoy 8080:8080

# Check Docker Desktop is running Kubernetes
kubectl cluster-info
```

### Cannot Access Service via LoadBalancer

**Symptoms:**
```bash
curl http://localhost:8080
curl: (7) Failed to connect to localhost port 8080: Connection refused
```

**Common Causes:**
1. Service not ready
2. Port conflict
3. Firewall blocking

**Solutions:**
```bash
# Check if LoadBalancer IP is assigned
kubectl get svc envoy -n api-gateway-poc

# Check if pods are running
kubectl get pods -n api-gateway-poc | grep envoy

# Check if port is in use
# Windows
netstat -ano | findstr :8080
# Linux/Mac
lsof -i :8080

# Try port-forward
kubectl port-forward -n api-gateway-poc svc/envoy 8080:8080
curl http://localhost:8080/products
```

## Network Issues

### DNS Resolution Failing

**Symptoms:**
- Logs show "could not resolve host: keycloak"
- Services cannot connect to each other

**Common Causes:**
1. Incorrect service name
2. Wrong namespace
3. CoreDNS not running

**Solutions:**
```bash
# Check CoreDNS is running
kubectl get pods -n kube-system | grep coredns

# Verify service names
kubectl get svc -n api-gateway-poc

# Test DNS from a pod
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -n api-gateway-poc -- sh
# Inside pod:
nslookup keycloak
curl http://keycloak:8080/health/ready

# Check service FQDN format
# Should be: <service-name>.<namespace>.svc.cluster.local
# Short form works within same namespace: <service-name>
```

### Connection Timeouts

**Symptoms:**
- Services timing out when connecting to dependencies
- Logs show connection timeout errors

**Common Causes:**
1. Target service not ready
2. Network policy blocking traffic
3. Firewall rules

**Solutions:**
```bash
# Check target service is ready
kubectl get pods -n api-gateway-poc

# Check endpoints exist
kubectl get endpoints -n api-gateway-poc

# Test connectivity from source pod
kubectl exec -it <source-pod> -n api-gateway-poc -- curl http://<target-service>:8000/health

# Check for network policies
kubectl get networkpolicies -n api-gateway-poc

# Increase timeout in application if needed
```

## Application Issues

### Keycloak Not Starting

**Symptoms:**
- Keycloak pod running but not ready after 5+ minutes
- Logs show errors or hangs

**Common Causes:**
1. Insufficient memory
2. H2 database issues
3. Realm import failing

**Solutions:**
```bash
# Check logs for errors
kubectl logs -f deployment/keycloak -n api-gateway-poc

# Increase Docker Desktop memory (4GB minimum)

# Check for "Keycloak ... started" message
kubectl logs deployment/keycloak -n api-gateway-poc | grep "started"

# Verify realm import
kubectl logs deployment/keycloak -n api-gateway-poc | grep realm-export

# If stuck, restart pod
kubectl delete pod <keycloak-pod> -n api-gateway-poc
```

### Redis Connection Errors

**Symptoms:**
- authz-service logs show Redis connection errors
- "Connection refused" or "Could not connect to Redis"

**Common Causes:**
1. Redis not running
2. Wrong Redis URL
3. Network issue

**Solutions:**
```bash
# Check Redis is running
kubectl get pods -n api-gateway-poc | grep redis

# Check Redis service
kubectl get svc redis -n api-gateway-poc

# Verify Redis URL in ConfigMap
kubectl get configmap authz-config -n api-gateway-poc -o yaml | grep REDIS_URL

# Test Redis connectivity
kubectl exec -it <authz-pod> -n api-gateway-poc -- sh
# Inside pod:
nc -zv redis 6379

# Check Redis logs
kubectl logs deployment/redis -n api-gateway-poc
```

### JWT Validation Failing

**Symptoms:**
- Authenticated requests return 401
- Envoy logs show JWT validation errors

**Common Causes:**
1. Keycloak JWKS endpoint unreachable
2. Token expired
3. Wrong issuer

**Solutions:**
```bash
# Check Keycloak is accessible from Envoy
kubectl exec -it <envoy-pod> -n api-gateway-poc -- sh
# Inside pod:
curl http://keycloak:8080/realms/api-gateway-poc/protocol/openid-connect/certs

# Check Envoy config
kubectl get configmap envoy-config -n api-gateway-poc -o yaml | grep jwks

# Get fresh token
TOKEN=$(curl -s -X POST "http://localhost:8180/realms/api-gateway-poc/protocol/openid-connect/token" \
  -d "client_id=test-client" \
  -d "username=testuser" \
  -d "password=testpass" \
  -d "grant_type=password" \
  | jq -r '.access_token')

# Check Envoy logs
kubectl logs -f deployment/envoy -n api-gateway-poc
```

### External AuthZ Failing

**Symptoms:**
- Requests return 403 Forbidden
- Envoy logs show ext_authz errors

**Common Causes:**
1. authz-service not reachable
2. Redis caching issues
3. Role lookup failing

**Solutions:**
```bash
# Check authz-service is running
kubectl get pods -n api-gateway-poc | grep authz

# Check authz-service logs
kubectl logs -f deployment/authz-service -n api-gateway-poc

# Test authz-service health
kubectl exec -it <envoy-pod> -n api-gateway-poc -- curl http://authz-service:9000/authz/health

# Check Redis caching (look for HIT/MISS in logs)
kubectl logs deployment/authz-service -n api-gateway-poc | grep "Cache"

# Verify Envoy ext_authz config
kubectl get configmap envoy-config -n api-gateway-poc -o yaml | grep -A 10 ext_authz
```

## Performance Issues

### High Memory Usage

**Symptoms:**
- Pods being OOMKilled
- Docker Desktop slow

**Solutions:**
```bash
# Check resource usage
kubectl top nodes
kubectl top pods -n api-gateway-poc

# Increase Docker Desktop memory
# Settings -> Resources -> Memory: 6GB+

# Add resource limits to deployments (optional)
kubectl set resources deployment/customer-service \
  --limits=memory=512Mi \
  -n api-gateway-poc
```

### Slow Response Times

**Symptoms:**
- API calls taking long time
- Timeouts occurring

**Solutions:**
```bash
# Check pod CPU/memory
kubectl top pods -n api-gateway-poc

# Check for restarts (indicates crashes)
kubectl get pods -n api-gateway-poc

# Check Envoy access logs
kubectl logs deployment/envoy -n api-gateway-poc | tail -100

# Check service logs for slow queries/operations
kubectl logs deployment/customer-service -n api-gateway-poc | tail -100

# Verify health checks aren't too aggressive
kubectl get deployment <name> -n api-gateway-poc -o yaml | grep -A 10 readinessProbe
```

## Debugging Commands

### Essential kubectl Commands

```bash
# Get all resources in namespace
kubectl get all -n api-gateway-poc

# Detailed pod information
kubectl describe pod <pod-name> -n api-gateway-poc

# View logs
kubectl logs <pod-name> -n api-gateway-poc
kubectl logs -f <pod-name> -n api-gateway-poc              # Follow logs
kubectl logs <pod-name> -n api-gateway-poc --previous      # Previous container
kubectl logs <pod-name> -n api-gateway-poc --tail=50       # Last 50 lines

# Execute commands in pod
kubectl exec -it <pod-name> -n api-gateway-poc -- sh
kubectl exec -it <pod-name> -n api-gateway-poc -- curl http://localhost:8000/health

# Port forwarding
kubectl port-forward <pod-name> 8080:8080 -n api-gateway-poc
kubectl port-forward svc/<service-name> 8080:8080 -n api-gateway-poc

# Resource usage
kubectl top pods -n api-gateway-poc
kubectl top nodes

# Events
kubectl get events -n api-gateway-poc --sort-by='.lastTimestamp'

# Configuration
kubectl get configmap <name> -n api-gateway-poc -o yaml
kubectl get secret <name> -n api-gateway-poc -o yaml
```

### Debugging Specific Components

**Redis:**
```bash
# Access Redis CLI
kubectl exec -it <redis-pod> -n api-gateway-poc -- redis-cli

# Inside redis-cli:
PING
KEYS *
GET user:platform-roles:testuser@example.com
```

**Keycloak:**
```bash
# Access admin console
# http://localhost:8180

# Check health from pod
kubectl exec -it <envoy-pod> -n api-gateway-poc -- \
  curl http://keycloak:8080/health/ready
```

**Envoy:**
```bash
# Access admin interface
# http://localhost:9901

# Check config dump
curl http://localhost:9901/config_dump

# Check stats
curl http://localhost:9901/stats

# Check clusters
curl http://localhost:9901/clusters
```

### Log Analysis

```bash
# Find errors in logs
kubectl logs deployment/customer-service -n api-gateway-poc | grep -i error

# Count log levels
kubectl logs deployment/authz-service -n api-gateway-poc | grep INFO | wc -l

# Monitor multiple pods
kubectl logs -f deployment/envoy -n api-gateway-poc &
kubectl logs -f deployment/authz-service -n api-gateway-poc &

# Save logs to file
kubectl logs deployment/keycloak -n api-gateway-poc > keycloak-logs.txt
```

### Network Debugging

```bash
# Test DNS
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -n api-gateway-poc -- sh
nslookup keycloak
nslookup customer-service

# Test HTTP connectivity
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -n api-gateway-poc -- \
  curl -v http://customer-service:8000/customers/health

# Check service endpoints
kubectl get endpoints -n api-gateway-poc -o wide
```

## Getting Help

If you're still stuck after trying these solutions:

1. Check logs for all related components
2. Verify the deployment order (Redis -> Keycloak -> AuthZ -> Services -> Envoy)
3. Review the kubernetes-deployment.md guide
4. Check project-plan.md for architecture details
5. Compare your setup with docker-compose.yml (Phase 1 reference)

## Reference

- Deployment Guide: `docs/kubernetes-deployment.md`
- Project Plan: `project-plan.md`
- Kubernetes Manifests: `kubernetes/`
- Scripts: `scripts/`
