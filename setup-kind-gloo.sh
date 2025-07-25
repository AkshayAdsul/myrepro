#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if required tools are installed
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if Docker is installed and running
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        print_error "Docker is not running. Please start Docker first."
        exit 1
    fi
    
    # Check if KinD is installed
    if ! command -v kind &> /dev/null; then
        print_error "KinD is not installed. Please install KinD first."
        print_status "You can install KinD with: go install sigs.k8s.io/kind@latest"
        exit 1
    fi
    
    # Check if kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed. Please install kubectl first."
        exit 1
    fi
    
    # Check if GLOO_LICENSE_KEY is set
    if [ -z "$GLOO_LICENSE_KEY" ]; then
        print_error "GLOO_LICENSE_KEY environment variable is not set."
        print_status "Please set your Gloo Edge Enterprise license key:"
        print_status "export GLOO_LICENSE_KEY=your_license_key_here"
        print_status "You can get a license key from: https://www.solo.io/products/gloo-edge/"
        exit 1
    fi
    
    print_success "All prerequisites are satisfied!"
}

# Create KinD cluster configuration
create_kind_config() {
    print_status "Creating KinD cluster configuration..."
    
    cat > kind-config.yaml << EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
- role: worker
- role: worker
EOF
    
    print_success "KinD cluster configuration created!"
}

# Create KinD cluster
create_kind_cluster() {
    print_status "Creating KinD cluster..."
    
    # Delete existing cluster if it exists
    if kind get clusters | grep -q "gloo-cluster"; then
        print_warning "Existing cluster 'gloo-cluster' found. Deleting it..."
        kind delete cluster --name gloo-cluster
    fi
    
    # Create new cluster
    kind create cluster --name gloo-cluster --config kind-config.yaml --wait 5m
    
    print_success "KinD cluster 'gloo-cluster' created successfully!"
}

# Install Gloo Edge Enterprise
install_gloo_edge() {
    print_status "Installing Gloo Edge Enterprise 1.18.11..."
    
    # Add the Gloo Edge Enterprise Helm repository
    helm repo add gloo https://storage.googleapis.com/gloo-ee-helm || true
    helm repo update
    
    # Create namespace for Gloo Edge
    kubectl create namespace gloo-system --dry-run=client -o yaml | kubectl apply -f -
    
    # Install Gloo Edge Enterprise
    helm install gloo-ee glooe/gloo-ee \
        --namespace gloo-system \
        --version 1.18.11 \
        --set license_key="$GLOO_LICENSE_KEY" \
        --set gloo.gatewayProxies.gatewayProxy.service.type=NodePort \
        --set gloo.gatewayProxies.gatewayProxy.service.httpPort=80 \
        --set gloo.gatewayProxies.gatewayProxy.service.httpsPort=443 \
        --set gloo-fed.enabled=false \
        --set gloo-fed.glooFedApiserver.enable=false \
        --set gloo.discovery.enabled=false \
        --wait
    
    print_success "Gloo Edge Enterprise 1.18.11 installed successfully!"
}

# Wait for Gloo Edge to be ready
wait_for_gloo() {
    print_status "Waiting for Gloo Edge to be ready..."
    
    kubectl rollout status -n gloo-system deployment/gloo
    kubectl rollout status -n gloo-system deployment/gateway-proxy
    
    print_success "Gloo Edge is ready!"
}

install_gloo_portal() {
    print_status "Installing Gloo Portal..."

    helm repo add gloo-portal https://storage.googleapis.com/dev-portal-helm || true
    helm repo update
    
    helm upgrade --install gloo-portal gloo-portal/gloo-portal \
        --version 1.4.2 \
        -n gloo-system \
        --values portal-values.yaml \
        --wait
}

deploy_petstore() {
    print_status "Deploying Petstore..."
    kubectl apply -f petstore.yaml
    print_success "Petstore deployed successfully!"
}

deploy_portal_config() {
    print_status "Deploying Portal Config..."
    helm upgrade --install config portal-config-chart
    print_success "Portal Config deployed successfully!"
}

# Main execution
main() {
    print_status "Starting KinD cluster setup with Gloo Edge Enterprise 1.18.11..."
    
    check_prerequisites
    create_kind_config
    create_kind_cluster
    install_gloo_edge
    wait_for_gloo
    #install_gloo_portal
    #deploy_petstore
    #deploy_portal_config
    
    print_success "Setup completed successfully!"
    print_status "Your KinD cluster with Gloo Edge Enterprise 1.18.11 is ready!"
}

# Run main function
main "$@" 
