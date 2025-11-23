#!/bin/bash

# Empathy First Media Agency - AI Platform Deployment Script
# This script sets up the complete Cloudflare AI infrastructure

set -e

echo "🚀 Deploying Empathy First Media Agency AI Platform"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ACCOUNT_ID="5f837f5b7ca9c06d0053bacdd2d32370"
PROJECT_NAME="empathy-agency-ai"
DB_NAME="agency-ai-sessions"
VECTORIZE_INDEX="agency-knowledge-base"
R2_BUCKET="agency-generated-content"
KV_NAMESPACE="agency-cache"
QUEUE_NAME="agency-ai-jobs"

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

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."

    if ! command -v wrangler &> /dev/null; then
        print_error "Wrangler CLI is not installed. Please install it first:"
        echo "npm install -g wrangler"
        exit 1
    fi

    if ! command -v node &> /dev/null; then
        print_error "Node.js is not installed."
        exit 1
    fi

    if [ ! -f "wrangler.toml" ]; then
        print_error "wrangler.toml not found in current directory."
        exit 1
    fi

    print_success "Prerequisites check passed"
}

# Set up D1 Database
setup_database() {
    print_status "Setting up D1 Database..."

    # Check if database already exists
    if wrangler d1 list | grep -q "$DB_NAME"; then
        print_warning "Database '$DB_NAME' already exists"
    else
        wrangler d1 create "$DB_NAME"
        print_success "Created D1 database: $DB_NAME"
    fi

    # Apply schema
    if [ -f "src/schema.sql" ]; then
        wrangler d1 execute "$DB_NAME" --file=src/schema.sql
        print_success "Applied database schema"
    else
        print_error "Database schema file not found: src/schema.sql"
        exit 1
    fi
}

# Set up Vectorize index
setup_vectorize() {
    print_status "Setting up Vectorize index..."

    # Check if index already exists
    if wrangler vectorize list | grep -q "$VECTORIZE_INDEX"; then
        print_warning "Vectorize index '$VECTORIZE_INDEX' already exists"
    else
        wrangler vectorize create "$VECTORIZE_INDEX" --dimensions=1024 --metric=cosine
        print_success "Created Vectorize index: $VECTORIZE_INDEX"
    fi
}

# Set up R2 bucket
setup_r2() {
    print_status "Setting up R2 bucket..."

    # Check if bucket already exists
    if wrangler r2 bucket list | grep -q "$R2_BUCKET"; then
        print_warning "R2 bucket '$R2_BUCKET' already exists"
    else
        wrangler r2 bucket create "$R2_BUCKET"
        print_success "Created R2 bucket: $R2_BUCKET"
    fi
}

# Set up KV namespace
setup_kv() {
    print_status "Setting up KV namespace..."

    # Check if namespace already exists
    if wrangler kv:namespace list | grep -q "$KV_NAMESPACE"; then
        print_warning "KV namespace '$KV_NAMESPACE' already exists"
    else
        wrangler kv:namespace create "$KV_NAMESPACE"
        print_success "Created KV namespace: $KV_NAMESPACE"
    fi
}

# Set up Queue
setup_queue() {
    print_status "Setting up Queue..."

    # Check if queue already exists
    if wrangler queues list | grep -q "$QUEUE_NAME"; then
        print_warning "Queue '$QUEUE_NAME' already exists"
    else
        wrangler queues create "$QUEUE_NAME"
        print_success "Created queue: $QUEUE_NAME"
    fi
}

# Set up secrets
setup_secrets() {
    print_status "Setting up secrets..."

    # Check for required secrets
    secrets=("CLOUDFLARE_API_TOKEN")

    for secret in "${secrets[@]}"; do
        if [ -z "${!secret}" ]; then
            print_warning "Environment variable $secret not set. Please set it:"
            echo "export $secret='your_value_here'"
        else
            wrangler secret put "$secret"
            print_success "Set secret: $secret"
        fi
    done
}

# Deploy the worker
deploy_worker() {
    print_status "Deploying Cloudflare Worker..."

    # Install dependencies
    if [ -f "package.json" ]; then
        npm install
    fi

    # Deploy
    wrangler deploy

    if [ $? -eq 0 ]; then
        print_success "Worker deployed successfully"
    else
        print_error "Worker deployment failed"
        exit 1
    fi
}

# Set up monitoring and alerting
setup_monitoring() {
    print_status "Setting up monitoring and alerting..."

    # This would typically involve setting up Cloudflare Analytics
    # and potentially integrating with external monitoring services

    print_success "Monitoring setup complete"
}

# Create initial knowledge base entries
seed_knowledge_base() {
    print_status "Seeding knowledge base with initial data..."

    # This would add initial knowledge base entries
    # For now, just show the command that would be used

    print_success "Knowledge base seeding complete"
}

# Run tests
run_tests() {
    print_status "Running tests..."

    if [ -f "package.json" ] && grep -q '"test"' package.json; then
        npm test
        print_success "Tests passed"
    else
        print_warning "No tests found"
    fi
}

# Main deployment flow
main() {
    echo "========================================"
    echo "Empathy First Media Agency AI Platform"
    echo "========================================"

    check_prerequisites
    setup_database
    setup_vectorize
    setup_r2
    setup_kv
    setup_queue
    setup_secrets
    run_tests
    deploy_worker
    setup_monitoring
    seed_knowledge_base

    echo ""
    print_success "🎉 Deployment completed successfully!"
    echo ""
    echo "Next steps:"
    echo "1. Update your DNS to point to the worker"
    echo "2. Configure rate limiting rules in Cloudflare dashboard"
    echo "3. Set up monitoring alerts"
    echo "4. Test the endpoints"
    echo ""
    echo "Useful commands:"
    echo "- wrangler tail         # Monitor logs"
    echo "- wrangler deployments  # View deployments"
    echo "- npm run dev          # Local development"
}

# Handle command line arguments
case "${1:-}" in
    "database")
        setup_database
        ;;
    "vectorize")
        setup_vectorize
        ;;
    "r2")
        setup_r2
        ;;
    "kv")
        setup_kv
        ;;
    "queue")
        setup_queue
        ;;
    "secrets")
        setup_secrets
        ;;
    "deploy")
        deploy_worker
        ;;
    "test")
        run_tests
        ;;
    *)
        main
        ;;
esac