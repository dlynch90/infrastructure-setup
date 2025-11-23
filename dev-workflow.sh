#!/bin/bash

# Enhanced Cloudflare Development Workflow
# Supports multiple environments with local development

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default environment
ENVIRONMENT="${ENVIRONMENT:-development}"

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
        print_error "Wrangler not found. Install with: npm install -g wrangler"
        exit 1
    fi

    if ! command -v node &> /dev/null; then
        print_error "Node.js not found"
        exit 1
    fi

    if [ ! -f "package.json" ]; then
        print_error "package.json not found. Are you in the project root?"
        exit 1
    fi

    print_success "Prerequisites check passed"
}

# Setup local development environment
setup_local_dev() {
    print_status "Setting up local development environment..."

    # Create persistence directory
    mkdir -p .wrangler-dev/local
    mkdir -p .wrangler-dev/remote

    # Create gitignore for dev state
    if ! grep -q ".wrangler-dev" .gitignore 2>/dev/null; then
        echo "# Wrangler local development state" >> .gitignore
        echo ".wrangler-dev/" >> .gitignore
        print_success "Added .wrangler-dev to .gitignore"
    fi

    # Create .env.development.local if it doesn't exist
    if [ ! -f ".env.development.local" ]; then
        cat > .env.development.local << EOF
# Local development overrides
DEBUG=true
LOG_LEVEL=debug
LOCAL_DEV=true

# Add your local secrets here (not committed to git)
# CLOUDFLARE_API_TOKEN=your-token-here
# OPENAI_API_KEY=your-key-here
EOF
        print_success "Created .env.development.local template"
    fi

    print_success "Local development environment ready"
}

# Start local development server
start_local_dev() {
    local config_file="wrangler.${ENVIRONMENT}.toml"

    if [ ! -f "$config_file" ]; then
        print_error "Configuration file not found: $config_file"
        print_error "Run: ENVIRONMENT=$ENVIRONMENT ./dev-workflow.sh setup"
        exit 1
    fi

    print_status "Starting local development server for $ENVIRONMENT environment..."
    print_status "Config file: $config_file"
    print_status "Persistence: ./.wrangler-dev"
    print_status "Access at: http://localhost:8787"
    echo ""
    print_warning "Press Ctrl+C to stop the server"
    echo ""

    # Start wrangler dev with persistence
    wrangler dev \
        --config "$config_file" \
        --persist-to ./.wrangler-dev \
        --port 8787 \
        --log-level debug
}

# Deploy to environment
deploy_environment() {
    local target="${1:-$ENVIRONMENT}"
    local config_file="wrangler.${target}.toml"

    if [ ! -f "$config_file" ]; then
        print_error "Configuration file not found: $config_file"
        exit 1
    fi

    print_status "Deploying to $target environment..."
    print_status "Config file: $config_file"

    # Deploy with environment-specific config
    wrangler deploy --config "$config_file"

    print_success "Deployment to $target completed"
}

# Show environment status
show_status() {
    print_status "Environment: $ENVIRONMENT"
    echo ""

    # Check configuration files
    for env in development staging production; do
        if [ -f "wrangler.${env}.toml" ]; then
            echo -e "✅ wrangler.${env}.toml - ${GREEN}Present${NC}"
        else
            echo -e "❌ wrangler.${env}.toml - ${RED}Missing${NC}"
        fi
    done

    echo ""

    # Check persistence directory
    if [ -d ".wrangler-dev" ]; then
        echo -e "✅ Local persistence - ${GREEN}Ready${NC}"
        echo "   Location: .wrangler-dev/"
    else
        echo -e "❌ Local persistence - ${RED}Not set up${NC}"
    fi

    echo ""

    # Check environment files
    for env_file in ".env.${ENVIRONMENT}" ".env.${ENVIRONMENT}.local"; do
        if [ -f "$env_file" ]; then
            echo -e "✅ $env_file - ${GREEN}Present${NC}"
        else
            echo -e "⚠️  $env_file - ${YELLOW}Missing${NC}"
        fi
    done

    echo ""

    # Check wrangler authentication
    if wrangler whoami &> /dev/null; then
        echo -e "✅ Cloudflare authentication - ${GREEN}Logged in${NC}"
    else
        echo -e "❌ Cloudflare authentication - ${RED}Not logged in${NC}"
        echo "   Run: wrangler login"
    fi
}

# Switch environment
switch_environment() {
    local new_env="$1"

    if [[ ! "$new_env" =~ ^(development|staging|production)$ ]]; then
        print_error "Invalid environment. Choose: development, staging, production"
        exit 1
    fi

    export ENVIRONMENT="$new_env"
    print_success "Switched to $new_env environment"
    print_status "Set ENVIRONMENT=$new_env for future commands"
}

# Clean local development state
clean_dev_state() {
    print_warning "This will remove all local development state and data"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf .wrangler-dev
        print_success "Local development state cleaned"
    else
        print_status "Clean cancelled"
    fi
}

# Show usage
show_usage() {
    echo "Cloudflare Development Workflow"
    echo "=============================="
    echo ""
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  setup          Setup local development environment"
    echo "  dev            Start local development server"
    echo "  deploy [env]   Deploy to environment (development/staging/production)"
    echo "  status         Show environment status"
    echo "  switch [env]   Switch active environment"
    echo "  clean          Clean local development state"
    echo "  help           Show this help"
    echo ""
    echo "Environment variables:"
    echo "  ENVIRONMENT    Current environment (development/staging/production)"
    echo "                 Default: development"
    echo ""
    echo "Examples:"
    echo "  $0 setup                    # Setup local dev environment"
    echo "  $0 dev                      # Start local development server"
    echo "  ENVIRONMENT=staging $0 dev # Start staging-like local server"
    echo "  $0 deploy production        # Deploy to production"
    echo "  $0 status                   # Show current status"
}

# Main command handling
case "${1:-help}" in
    "setup")
        check_prerequisites
        setup_local_dev
        ;;
    "dev")
        check_prerequisites
        start_local_dev
        ;;
    "deploy")
        check_prerequisites
        deploy_environment "$2"
        ;;
    "status")
        show_status
        ;;
    "switch")
        switch_environment "$2"
        ;;
    "clean")
        clean_dev_state
        ;;
    "help"|*)
        show_usage
        ;;
esac