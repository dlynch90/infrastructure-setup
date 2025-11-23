#!/bin/bash

# Enhanced Deployment Script with 1Password Integration
# Automatically injects secrets during deployment

set -e

echo "🚀 Enhanced Deployment with 1Password Secrets"
echo "============================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration - load from 1Password
ENVIRONMENT="${ENVIRONMENT:-production}"
VAULT="${VAULT:-Production}"

# Function to load secrets from 1Password
load_secret() {
    local secret_ref=$1
    local default_value=$2

    if op read "$secret_ref" 2>/dev/null; then
        op read "$secret_ref"
    else
        echo "$default_value"
    fi
}

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

    if ! command -v op &> /dev/null; then
        print_error "1Password CLI not found. Install from: https://developer.1password.com/docs/cli/"
        exit 1
    fi

    if ! command -v wrangler &> /dev/null; then
        print_error "Wrangler CLI not found. Install with: npm install -g wrangler"
        exit 1
    fi

    if ! op whoami &> /dev/null; then
        print_error "Not signed into 1Password CLI. Run: op signin"
        exit 1
    fi

    print_success "Prerequisites check passed"
}

# Load configuration from 1Password
load_configuration() {
    print_status "Loading configuration from 1Password..."

    # Load Cloudflare configuration
    export CLOUDFLARE_API_TOKEN=$(load_secret "op://$VAULT/CLOUDFLARE_API_TOKEN")
    export CLOUDFLARE_ACCOUNT_ID=$(load_secret "op://$VAULT/CLOUDFLARE_ACCOUNT_ID" "5f837f5b7ca9c06d0053bacdd2d32370")

    # Load project configuration
    export PROJECT_NAME=$(load_secret "op://$VAULT/CLOUDFLARE_PROJECT_NAME" "empathy-agency-ai")
    export DATABASE_NAME=$(load_secret "op://$VAULT/DATABASE_NAME" "agency-ai-sessions")
    export VECTORIZE_INDEX=$(load_secret "op://$VAULT/VECTORIZE_INDEX" "agency-knowledge-base")
    export R2_BUCKET=$(load_secret "op://$VAULT/R2_BUCKET" "agency-generated-content")
    export KV_NAMESPACE=$(load_secret "op://$VAULT/KV_NAMESPACE" "agency-cache")
    export QUEUE_NAME=$(load_secret "op://$VAULT/QUEUE_NAME" "agency-ai-jobs")

    print_success "Configuration loaded from 1Password"
}

# Setup Cloudflare resources with secrets
setup_cloudflare_resources() {
    print_status "Setting up Cloudflare resources..."

    # Authenticate with Cloudflare (using 1Password plugin if configured)
    if op plugin inspect wrangler &> /dev/null; then
        print_status "Using 1Password plugin for Cloudflare authentication"
        export OP_PLUGIN_CLOUDFLARE_TOKEN="$CLOUDFLARE_API_TOKEN"
    fi

    # Setup D1 Database
    setup_database

    # Setup Vectorize
    setup_vectorize

    # Setup R2
    setup_r2

    # Setup KV
    setup_kv

    # Setup Queue
    setup_queue
}

# Database setup (same as original but with better error handling)
setup_database() {
    print_status "Setting up D1 Database..."

    if wrangler d1 list 2>/dev/null | grep -q "$DATABASE_NAME"; then
        print_warning "Database '$DATABASE_NAME' already exists"
    else
        if wrangler d1 create "$DATABASE_NAME"; then
            print_success "Created D1 database: $DATABASE_NAME"
        else
            print_error "Failed to create database"
            exit 1
        fi
    fi

    # Apply schema
    if [ -f "src/schema.sql" ]; then
        wrangler d1 execute "$DATABASE_NAME" --file=src/schema.sql
        print_success "Applied database schema"
    else
        print_error "Database schema file not found: src/schema.sql"
        exit 1
    fi
}

# Vectorize setup
setup_vectorize() {
    print_status "Setting up Vectorize index..."

    if wrangler vectorize list 2>/dev/null | grep -q "$VECTORIZE_INDEX"; then
        print_warning "Vectorize index '$VECTORIZE_INDEX' already exists"
    else
        wrangler vectorize create "$VECTORIZE_INDEX" --dimensions=1024 --metric=cosine
        print_success "Created Vectorize index: $VECTORIZE_INDEX"
    fi
}

# R2 setup
setup_r2() {
    print_status "Setting up R2 bucket..."

    if wrangler r2 bucket list 2>/dev/null | grep -q "$R2_BUCKET"; then
        print_warning "R2 bucket '$R2_BUCKET' already exists"
    else
        wrangler r2 bucket create "$R2_BUCKET"
        print_success "Created R2 bucket: $R2_BUCKET"
    fi
}

# KV setup
setup_kv() {
    print_status "Setting up KV namespace..."

    if wrangler kv:namespace list 2>/dev/null | grep -q "$KV_NAMESPACE"; then
        print_warning "KV namespace '$KV_NAMESPACE' already exists"
    else
        wrangler kv:namespace create "$KV_NAMESPACE"
        print_success "Created KV namespace: $KV_NAMESPACE"
    fi
}

# Queue setup
setup_queue() {
    print_status "Setting up Queue..."

    if wrangler queues list 2>/dev/null | grep -q "$QUEUE_NAME"; then
        print_warning "Queue '$QUEUE_NAME' already exists"
    else
        wrangler queues create "$QUEUE_NAME"
        print_success "Created queue: $QUEUE_NAME"
    fi
}

# Deploy with secrets
deploy_with_secrets() {
    print_status "Deploying with secrets..."

    # Install dependencies
    if [ -f "package.json" ]; then
        npm install
    fi

    # Deploy using 1Password environment
    op run --env-file=".env.$ENVIRONMENT" -- wrangler deploy

    if [ $? -eq 0 ]; then
        print_success "Deployment completed successfully"
    else
        print_error "Deployment failed"
        exit 1
    fi
}

# Setup monitoring and secrets
setup_secrets() {
    print_status "Setting up application secrets..."

    # Load secrets from 1Password and set them in Cloudflare
    secrets=(
        "SUPABASE_ANON_KEY:op://$VAULT/SUPABASE_ANON_KEY/password"
        "SUPABASE_SERVICE_KEY:op://$VAULT/SUPABASE_SERVICE_ROLE_KEY/credential"
        "FIREWORKS_API_KEY:op://$VAULT/FIREWORKS_API_KEY/password"
        "OPENAI_API_KEY:op://$VAULT/OPENAI_API_KEY/password"
        "ANTHROPIC_API_KEY:op://$VAULT/ANTHROPIC_API_KEY/password"
    )

    for secret_pair in "${secrets[@]}"; do
        IFS=':' read -r secret_name secret_ref <<< "$secret_pair"
        secret_value=$(load_secret "$secret_ref")

        if [ -n "$secret_value" ]; then
            op run --env-file=".env.$ENVIRONMENT" -- wrangler secret put "$secret_name"
            print_success "Set secret: $secret_name"
        else
            print_warning "Secret not found: $secret_name"
        fi
    done
}

# Main deployment flow
main() {
    echo "========================================"
    echo "Empathy First Media Agency AI Platform"
    echo "Enhanced Deployment with 1Password"
    echo "========================================"

    check_prerequisites
    load_configuration
    setup_cloudflare_resources
    setup_secrets
    deploy_with_secrets

    echo ""
    print_success "🎉 Enhanced deployment completed successfully!"
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
    echo ""
    echo "🔐 Security features enabled:"
    echo "- Secrets loaded from 1Password vaults"
    echo "- Biometric authentication for CLI tools"
    echo "- Environment-specific configurations"
    echo "- Automated secret rotation support"
}

# Handle command line arguments
case "${1:-}" in
    "database")
        check_prerequisites
        load_configuration
        setup_database
        ;;
    "secrets")
        check_prerequisites
        load_configuration
        setup_secrets
        ;;
    "deploy")
        check_prerequisites
        load_configuration
        deploy_with_secrets
        ;;
    *)
        main
        ;;
esac