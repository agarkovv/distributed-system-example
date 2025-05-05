#!/bin/bash
set -e

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

section() {
  echo -e "\n${BLUE}=== $1 ===${NC}\n"
}

success() {
  echo -e "${GREEN}$1${NC}"
}

info() {
  echo -e "${YELLOW}$1${NC}"
}

check_prereqs() {
  section "Checking Prerequisites"
  
  for cmd in kubectl docker; do
    if ! command -v $cmd &> /dev/null; then
      echo "$cmd is required but not installed"
      exit 1
    fi
  done
  
  success "Prerequisites OK"
}

build_images() {
  section "Building Docker Images"
  
  docker build -t flask-app:latest .
  success "Flask app image built"
  
  if [ -f "$KUBERNETES_DIR/log-archiver/Dockerfile" ]; then
    docker build -t flask-log-archiver:latest -f "$KUBERNETES_DIR/log-archiver/Dockerfile" "$KUBERNETES_DIR/log-archiver"
    success "Log archiver image built"
  else
    echo "Log archiver Dockerfile not found at $KUBERNETES_DIR/log-archiver/Dockerfile"
    exit 1
  fi
  
  if command -v minikube &> /dev/null && minikube status &> /dev/null; then
    info "Loading images to Minikube"
    minikube image load flask-app:latest
    
    if docker images flask-log-archiver:latest --format "{{.Repository}}" | grep -q "flask-log-archiver"; then
      eval $(minikube docker-env)
      docker build -t flask-log-archiver:latest -f "$KUBERNETES_DIR/log-archiver/Dockerfile" "$KUBERNETES_DIR/log-archiver"
      eval $(minikube docker-env -u)
      success "Images loaded to Minikube"
    fi
  fi
}

deploy_resource() {
  local resource_type=$1
  local file_path=$2
  local resource_name=$3
  local wait_cmd=$4
  
  echo "Deploying $resource_type: $resource_name"
  
  if [ ! -f "$file_path" ]; then
    echo "File not found: $file_path"
    exit 1
  fi
  
  kubectl apply -f "$file_path"
  
  if [ -n "$wait_cmd" ]; then
    echo "Waiting for $resource_type to be ready..."
    eval $wait_cmd
    success "$resource_type ready"
  else
    success "$resource_type applied"
  fi
}

show_summary() {
  section "Deployment Summary"
  
  echo "Deployments:"
  kubectl get deployments
  
  echo -e "\nServices:"
  kubectl get services
  
  echo -e "\nPods:"
  kubectl get pods
  
  echo -e "\nDaemonSets:"
  kubectl get daemonsets
  
  echo -e "\nCronJobs:"
  kubectl get cronjobs
}

main() {
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  cd "$SCRIPT_DIR"
  
  KUBERNETES_DIR="$SCRIPT_DIR/kubernetes"
  LOG_ARCHIVER_DIR="$KUBERNETES_DIR/log-archiver"
  
  section "Flask Application Deployment"
  
  check_prereqs
  
  build_images
  
  section "Deploying Kubernetes Resources"
  
  deploy_resource "ConfigMap" "$KUBERNETES_DIR/config.yaml" "app-config"
  
  deploy_resource "Deployment" "$KUBERNETES_DIR/deployment.yaml" "flask-app" \
    "kubectl rollout status deployment/flask-app --timeout=300s"
  
  deploy_resource "Service" "$KUBERNETES_DIR/service.yaml" "flask-app-service"
  
  deploy_resource "DaemonSet" "$KUBERNETES_DIR/log-agent-daemonset.yaml" "flask-log-agent" \
    "sleep 10 && kubectl rollout status daemonset/flask-log-agent --timeout=60s"
  
  deploy_resource "CronJob" "$KUBERNETES_DIR/log-archiver/cronjob.yaml" "flask-log-archiver"
  
  show_summary
  
  section "Deployment Complete"
  echo "Flask application deployed successfully."
  echo -e "\nAccess the application: kubectl port-forward service/flask-app-service 8080:80"
  echo "View app logs: kubectl logs -l app=flask-app"
  echo "View agent logs: kubectl logs -l app=flask-log-agent"
  echo "Trigger archive job: kubectl create job --from=cronjob/flask-log-archiver manual-archive-$(date +%s)"
}

main "$@" 