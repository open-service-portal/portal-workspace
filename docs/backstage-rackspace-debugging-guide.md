# Backstage Rackspace Deployment Debugging Guide

## Quick Start

```bash
# Access the cluster
kubectl config use-context osp-openportal

# Find Backstage resources
kubectl get pods -n app-portal
kubectl get svc -n app-portal
```

## Essential Commands

### Get Pod Name
```bash
POD=$(kubectl get pods -n app-portal -o jsonpath='{.items[0].metadata.name}')
echo $POD
```

### View Logs
```bash
# Live logs
kubectl logs -f $POD -n app-portal

# Last 100 lines
kubectl logs $POD -n app-portal --tail=100

# Last hour
kubectl logs $POD -n app-portal --since=1h
```

### Search Logs
```bash
# Errors
kubectl logs $POD -n app-portal --since=1h | grep -i error

# Authentication
kubectl logs $POD -n app-portal --since=1h | grep -i auth

# GitHub activity
kubectl logs $POD -n app-portal --since=1h | grep -i github

# Ingestor activity
kubectl logs $POD -n app-portal --since=30m | grep -i ingestor
```

## Configuration

```bash
# Check environment variables
kubectl get deployment app-portal -n app-portal -o yaml | grep -A5 "env:"

# List secrets
kubectl get secrets -n app-portal

# List configmaps
kubectl get cm -n app-portal
```

## Pod Operations

```bash
# Restart pod
kubectl delete pod $POD -n app-portal

# Scale down/up
kubectl scale deployment app-portal -n app-portal --replicas=0
kubectl scale deployment app-portal -n app-portal --replicas=1

# Execute shell in pod
kubectl exec -it $POD -n app-portal -- /bin/sh

# Port forward for local access
kubectl port-forward -n app-portal deployment/app-portal 7007:7007
```

## Common Log Patterns

### Healthy logs
```
{"level":"info","message":"Reading GitHub users and groups"}
{"level":"info","message":"Ingestor found 5 XRD Entities"}
{"level":"info","message":"GET /healthcheck HTTP/1.1\" 200"}
```

### Issues to watch for
```
{"level":"error","message":"Failed to..."}
{"level":"warn","message":"Rate limit..."}
{"level":"warn","message":"Signing key has expired"}
```

## Troubleshooting Checklist

1. **Pod running?** → `kubectl get pods -n app-portal`
2. **Recent errors?** → `kubectl logs $POD -n app-portal --since=10m | grep -i error`
3. **GitHub working?** → Check for "Reading GitHub users" in logs
4. **Ingestors active?** → Check for "Ingestor found" messages
5. **Health checks passing?** → Look for HTTP 200 on `/healthcheck`