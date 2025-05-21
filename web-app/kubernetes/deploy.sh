#!/bin/bash
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_step() {
    echo -e "${GREEN}Step $1:${NC} $2"
}

check_command() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${RED}Error: $1 is not installed${NC}"
        exit 1
    fi
}

check_command kubectl
check_command docker
check_command istioctl
check_command helm

print_step "1" "Setting up Istio service mesh"
if ! kubectl get namespace istio-system &> /dev/null; then
    curl -L https://istio.io/downloadIstioctl | sh -
    export PATH=$PATH:$HOME/.istioctl/bin
    istioctl install --set profile=demo -y
    kubectl label namespace default istio-injection=enabled
fi

print_step "2" "Installing Prometheus and Grafana"
if ! kubectl get namespace monitoring &> /dev/null; then
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update
    helm install prometheus prometheus-community/kube-prometheus-stack \
        --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
        --set grafana.enabled=true \
        --set grafana.adminPassword=admin \
        --set prometheus.prometheusSpec.maximumStartupDurationSeconds=300
fi

print_step "3" "Building and pushing Docker images"
docker build -t flask-app:latest web-app/
docker build -t log-agent:latest web-app/kubernetes/log-agent/

print_step "4" "Creating Kubernetes resources"

kubectl apply --validate=false -f web-app/kubernetes/config.yaml

kubectl apply --validate=false -f web-app/kubernetes/pv.yaml
kubectl apply --validate=false -f web-app/kubernetes/pvc.yaml

kubectl apply --validate=false -f web-app/kubernetes/deployment.yaml

kubectl apply --validate=false -f web-app/kubernetes/service.yaml

kubectl apply --validate=false -f web-app/kubernetes/log-agent-daemonset.yaml

kubectl apply --validate=false -f web-app/kubernetes/log-archiver-cronjob.yaml

print_step "5" "Applying Istio configurations"
kubectl apply --validate=false -f web-app/kubernetes/istio/gateway.yaml
kubectl apply --validate=false -f web-app/kubernetes/istio/virtual-service.yaml
kubectl apply --validate=false -f web-app/kubernetes/istio/destination-rule.yaml

print_step "6" "Applying Prometheus ServiceMonitor"
kubectl apply --validate=false -f web-app/kubernetes/monitoring/servicemonitor.yaml

print_step "7" "Waiting for resources to be ready"
kubectl wait --for=condition=available --timeout=300s deployment/flask-app
kubectl wait --for=condition=available --timeout=300s daemonset/flask-log-agent

print_step "8" "Getting Istio Ingress Gateway IP"
INGRESS_IP=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
if [ -z "$INGRESS_IP" ]; then
    INGRESS_IP=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
fi

print_step "9" "Deployment Summary"
echo -e "${YELLOW}Deployment completed successfully!${NC}"
echo -e "Flask application is accessible at: http://$INGRESS_IP"
echo -e "Available endpoints:"
echo -e "  - GET /"
echo -e "  - GET /health"
echo -e "  - GET /log"
echo -e "  - GET /logs"
echo -e "  - GET /metrics"
echo -e "  - GET /wrong (returns 404)"

echo -e "\n${YELLOW}Pod Status:${NC}"
kubectl get pods

echo -e "\n${YELLOW}Service Status:${NC}"
kubectl get services

echo -e "\n${YELLOW}Istio Gateway Status:${NC}"
kubectl get gateway
kubectl get virtualservice
kubectl get destinationrule

echo -e "\n${YELLOW}Monitoring Status:${NC}"
echo -e "Prometheus UI: kubectl port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090"
echo -e "Grafana UI: kubectl port-forward svc/prometheus-grafana 3000:80"
echo -e "Grafana credentials: admin/admin" 