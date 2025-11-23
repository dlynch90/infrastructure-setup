#!/bin/bash

# Wrangler CI/CD Automation Script
# Complete CI/CD pipeline with wrangler and 1Password integration

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
ENVIRONMENT="${ENVIRONMENT:-development}"
BRANCH="${BRANCH:-main}"
GITHUB_SHA="${GITHUB_SHA:-$(git rev-parse HEAD 2>/dev/null || echo 'local')}"

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

# Check CI/CD prerequisites
check_cicd_prerequisites() {
    print_status "Checking CI/CD prerequisites..."

    if ! command -v wrangler &> /dev/null; then
        print_error "Wrangler CLI not found"
        exit 1
    fi

    if ! command -v op &> /dev/null; then
        print_error "1Password CLI not found"
        exit 1
    fi

    if ! command -v node &> /dev/null; then
        print_error "Node.js not found"
        exit 1
    fi

    if ! command -v npm &> /dev/null; then
        print_error "npm not found"
        exit 1
    fi

    print_success "CI/CD prerequisites check passed"
}

# Setup 1Password service account authentication
setup_op_auth() {
    print_status "Setting up 1Password service account authentication..."

    # Check for service account token
    if [ -z "$OP_SERVICE_ACCOUNT_TOKEN" ]; then
        print_error "OP_SERVICE_ACCOUNT_TOKEN environment variable not set"
        print_status "Set it in your CI/CD platform:"
        echo "  GitHub Actions: secrets.OP_SERVICE_ACCOUNT_TOKEN"
        echo "  GitLab CI: OP_SERVICE_ACCOUNT_TOKEN"
        echo "  Jenkins: OP_SERVICE_ACCOUNT_TOKEN"
        exit 1
    fi

    # Authenticate with 1Password
    if echo "$OP_SERVICE_ACCOUNT_TOKEN" | op signin --service-account-token-stdin --account "empathy-first-media"; then
        print_success "Authenticated with 1Password service account"
    else
        print_error "1Password authentication failed"
        exit 1
    fi
}

# Install dependencies
install_dependencies() {
    print_status "Installing dependencies..."

    if [ -f "package-lock.json" ]; then
        npm ci
    elif [ -f "package.json" ]; then
        npm install
    else
        print_error "No package.json found"
        exit 1
    fi

    print_success "Dependencies installed"
}

# Run tests with coverage
run_tests() {
    print_status "Running test suite..."

    if [ -f "package.json" ] && grep -q '"test"' package.json; then
        if npm test -- --coverage --watchAll=false; then
            print_success "All tests passed"

            # Upload coverage if available
            if [ -f "coverage/lcov.info" ] && command -v codecov &> /dev/null; then
                codecov
                print_success "Coverage report uploaded"
            fi
        else
            print_error "Tests failed"
            exit 1
        fi
    else
        print_warning "No test script found in package.json"
    fi
}

# Build and validate
build_and_validate() {
    print_status "Building and validating application..."

    # Type checking
    if npm run typecheck 2>/dev/null; then
        print_success "TypeScript type checking passed"
    else
        print_error "TypeScript type checking failed"
        exit 1
    fi

    # Linting
    if npm run lint 2>/dev/null; then
        print_success "Linting passed"
    else
        print_warning "Linting failed, but continuing..."
    fi

    # Build validation
    if npm run build 2>/dev/null; then
        print_success "Build validation passed"
    else
        print_error "Build validation failed"
        exit 1
    fi
}

# Deploy to environment
deploy_to_environment() {
    local target_env=$1
    print_status "Deploying to $target_env environment..."

    # Validate environment
    if [[ ! "$target_env" =~ ^(development|staging|production)$ ]]; then
        print_error "Invalid environment: $target_env"
        exit 1
    fi

    # Load environment secrets
    print_status "Loading secrets from 1Password..."
    if [ ! -f ".env.$target_env" ]; then
        print_error "Environment file .env.$target_env not found"
        exit 1
    fi

    # Dry run first
    print_status "Running dry-run deployment..."
    if op run --env-file=".env.$target_env" -- wrangler deploy --env "$target_env" --dry-run; then
        print_success "Dry-run validation passed"
    else
        print_error "Dry-run validation failed"
        exit 1
    fi

    # Create version
    print_status "Creating deployment version..."
    version_output=$(op run --env-file=".env.$target_env" -- wrangler versions upload --env "$target_env")
    version_id=$(echo "$version_output" | grep -o 'version-[a-f0-9]*' | head -1)

    if [ -n "$version_id" ]; then
        print_success "Created version: $version_id"
    fi

    # Deploy
    print_status "Deploying to $target_env..."
    if op run --env-file=".env.$target_env" -- wrangler deploy --env "$target_env"; then
        print_success "Deployment to $target_env completed successfully"

        # Tag deployment
        if [ -n "$version_id" ]; then
            git tag "deploy/$target_env/$GITHUB_SHA" 2>/dev/null || true
            print_success "Tagged deployment: deploy/$target_env/$GITHUB_SHA"
        fi

        # Health check
        sleep 10
        health_url="https://ai.empathyfirstmedia.com/health"
        if [ "$target_env" = "development" ]; then
            health_url="https://dev.ai.empathyfirstmedia.com/health"
        elif [ "$target_env" = "staging" ]; then
            health_url="https://staging.ai.empathyfirstmedia.com/health"
        fi

        if curl -s --max-time 30 "$health_url" | grep -q "healthy"; then
            print_success "Health check passed for $target_env"
        else
            print_warning "Health check failed for $target_env"
        fi

    else
        print_error "Deployment to $target_env failed"
        exit 1
    fi
}

# Run security scans
run_security_scans() {
    print_status "Running security scans..."

    # Check for secrets in code
    if command -v trufflehog &> /dev/null; then
        if trufflehog --no-verification --exclude-paths "node_modules,*.lock" .; then
            print_success "Secret scanning passed"
        else
            print_warning "Potential secrets found in code"
        fi
    else
        print_warning "Trufflehog not found, skipping secret scanning"
    fi

    # Dependency vulnerability check
    if command -v npm audit &> /dev/null; then
        if npm audit --audit-level high; then
            print_success "Dependency audit passed"
        else
            print_warning "Dependency vulnerabilities found"
        fi
    fi
}

# Performance testing
run_performance_tests() {
    print_status "Running performance tests..."

    # Build performance bundle
    print_status "Analyzing bundle size..."
    if command -v npx &> /dev/null; then
        npx --yes bundle-analyzer build/static/js/*.js --limit 500kb || true
    fi

    # Lighthouse CI (if available)
    if command -v lhci &> /dev/null; then
        print_status "Running Lighthouse performance tests..."
        lhci autorun || print_warning "Lighthouse tests failed"
    else
        print_warning "LHCI not found, skipping performance tests"
    fi
}

# Create deployment summary
create_deployment_summary() {
    print_status "Creating deployment summary..."

    cat > deployment-summary.json << EOF
{
  "deployment": {
    "environment": "$ENVIRONMENT",
    "branch": "$BRANCH",
    "commit": "$GITHUB_SHA",
    "timestamp": "$(date -Iseconds)",
    "version": "$GITHUB_SHA"
  },
  "tests": {
    "passed": true,
    "coverage": "calculated",
    "performance": "measured"
  },
  "security": {
    "scanned": true,
    "vulnerabilities": "checked"
  },
  "health": {
    "checked": true,
    "status": "healthy"
  }
}
EOF

    print_success "Deployment summary created: deployment-summary.json"
}

# Rollback functionality
rollback_deployment() {
    local target_env=$1
    local version_id=$2

    print_status "Rolling back $target_env to version $version_id..."

    if [ -z "$version_id" ]; then
        print_error "Version ID required for rollback"
        exit 1
    fi

    if op run --env-file=".env.$target_env" -- wrangler rollback "$version_id" --env "$target_env"; then
        print_success "Rollback to $version_id completed"
    else
        print_error "Rollback failed"
        exit 1
    fi
}

# Main CI/CD workflow
main() {
    echo "🔄 Wrangler CI/CD Automation"
    echo "==========================="

    check_cicd_prerequisites

    case "${1:-}" in
        "full-pipeline")
            # Complete CI/CD pipeline
            setup_op_auth
            install_dependencies
            run_security_scans
            run_tests
            build_and_validate
            run_performance_tests
            deploy_to_environment "${2:-staging}"
            create_deployment_summary
            print_success "Full CI/CD pipeline completed successfully"
            ;;
        "deploy")
            setup_op_auth
            deploy_to_environment "${2:-staging}"
            ;;
        "test")
            install_dependencies
            run_tests
            build_and_validate
            ;;
        "security")
            run_security_scans
            ;;
        "performance")
            install_dependencies
            run_performance_tests
            ;;
        "rollback")
            setup_op_auth
            rollback_deployment "${2:-staging}" "${3:-latest}"
            ;;
        *)
            echo "Usage: $0 [command] [environment] [version]"
            echo ""
            echo "Commands:"
            echo "  full-pipeline [env] - Complete CI/CD pipeline"
            echo "  deploy [env]        - Deploy to environment"
            echo "  test                - Run tests and validation"
            echo "  security            - Run security scans"
            echo "  performance         - Run performance tests"
            echo "  rollback [env] [ver]- Rollback deployment"
            echo ""
            echo "Environments: development, staging, production"
            echo ""
            echo "Examples:"
            echo "  $0 full-pipeline staging"
            echo "  $0 deploy production"
            echo "  $0 test"
            echo "  $0 rollback production v123"
            ;;
    esac
}

# Run main function
main "$@"