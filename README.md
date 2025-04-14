# Distributed System Example

This project demonstrates a distributed system built with Flask, Docker, and Kubernetes, featuring logging, monitoring, and archiving capabilities.

## System Components

1. **Flask Web Application**
   - REST API endpoints for status and logging
   - Configurable via ConfigMap
   - Load-balanced across multiple replicas

2. **Log Collection System**
   - DaemonSet for collecting logs from all nodes
   - Logs accessible via kubectl logs

3. **Log Archiving System**
   - CronJob running every 10 minutes
   - Archives logs to tar.gz files
   - Fallback mechanisms for reliability

## Prerequisites

- Docker installed and configured
- Kubernetes cluster (Minikube, Kind, or a cloud provider)
- kubectl configured to connect to your cluster

## Quick Start

To deploy the entire system with a single command:

```bash
cd web-app
./deploy.sh
```

This script will:
1. Build all necessary Docker images
2. Deploy all Kubernetes resources in the correct order
3. Wait for all components to be ready
4. Show the status of the deployment

## Accessing the Application

After deployment, you can access the application via port-forwarding:

```bash
kubectl port-forward service/flask-app-service 8080:80
```

Then access the API at: http://localhost:8080

## API Endpoints

- `GET /` - Returns welcome message
- `GET /status` - Returns status information
- `POST /log` - Accepts JSON `{"message": "log message"}` to write to logs
- `GET /logs` - Returns all logs

## Monitoring the System

```bash
# View application logs
kubectl logs -l app=flask-app

# View log agent logs
kubectl logs -l app=flask-log-agent

# Check archived logs
kubectl create job --from=cronjob/flask-log-archiver manual-log-archive-$(date +%s)
kubectl logs job/manual-log-archive-<timestamp>
```

## Detailed Documentation

For more detailed information about each component, please refer to:
- [Web Application README](web-app/README.md)
- [Kubernetes Deployment Guide](web-app/kubernetes/README.md)

## Cleanup

To remove all resources:

```bash
kubectl delete -f web-app/kubernetes/log-archiver/cronjob.yaml
kubectl delete -f web-app/kubernetes/log-agent-daemonset.yaml
kubectl delete -f web-app/kubernetes/service.yaml
kubectl delete -f web-app/kubernetes/deployment.yaml
kubectl delete -f web-app/kubernetes/config.yaml
```