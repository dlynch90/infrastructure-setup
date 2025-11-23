#!/bin/bash

# Wrangler Workflow Automation Script
# Implements advanced wrangler workflows for Cloudflare Workers deployment

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
ENVIRONMENT="${ENVIRONMENT:-development}"
VAULT="${VAULT:-Development}"

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
    print_status "Checking wrangler workflow prerequisites..."

    if ! command -v wrangler &> /dev/null; then
        print_error "Wrangler CLI not found. Install with: npm install -g wrangler"
        exit 1
    fi

    if ! command -v op &> /dev/null; then
        print_error "1Password CLI not found"
        exit 1
    fi

    # Check if authenticated with Cloudflare
    if ! wrangler whoami &> /dev/null; then
        print_warning "Not authenticated with Cloudflare. Run: wrangler auth login"
    fi

    print_success "Prerequisites check passed"
}

# Setup wrangler environments
setup_environments() {
    print_status "Setting up wrangler environments..."

    environments=("development" "staging" "production")

    for env in "${environments[@]}"; do
        if wrangler environments list | grep -q "$env"; then
            print_warning "Environment '$env' already exists"
        else
            wrangler environments create "$env"
            print_success "Created environment: $env"
        fi
    done
}

# Setup version management
setup_versioning() {
    print_status "Setting up version management..."

    # Create initial version for development
    if wrangler versions list --env development | grep -q "No versions"; then
        wrangler versions upload --env development
        print_success "Created initial development version"
    else
        print_warning "Versions already exist for development"
    fi
}

# Setup resource dependencies
setup_resources() {
    print_status "Setting up Cloudflare resource dependencies..."

    # D1 Database
    if ! wrangler d1 list | grep -q "agency-ai-sessions"; then
        wrangler d1 create agency-ai-sessions
        print_success "Created D1 database: agency-ai-sessions"
    fi

    # Vectorize Index
    if ! wrangler vectorize list | grep -q "agency-knowledge-base"; then
        wrangler vectorize create agency-knowledge-base --dimensions 1024 --metric cosine
        print_success "Created Vectorize index: agency-knowledge-base"
    fi

    # R2 Bucket
    if ! wrangler r2 bucket list | grep -q "agency-generated-content"; then
        wrangler r2 bucket create agency-generated-content
        print_success "Created R2 bucket: agency-generated-content"
    fi

    # KV Namespace
    if ! wrangler kv:namespace list | grep -q "agency-cache"; then
        wrangler kv:namespace create agency-cache
        print_success "Created KV namespace: agency-cache"
    fi

    # Queue
    if ! wrangler queues list | grep -q "agency-ai-jobs"; then
        wrangler queues create agency-ai-jobs
        print_success "Created queue: agency-ai-jobs"
    fi
}

# Deploy with advanced workflow
deploy_advanced() {
    local target_env=$1
    print_status "Starting advanced deployment to $target_env..."

    # Validate environment
    if [[ ! "$target_env" =~ ^(development|staging|production)$ ]]; then
        print_error "Invalid environment: $target_env"
        echo "Valid environments: development, staging, production"
        exit 1
    fi

    # Dry run first
    print_status "Running dry-run validation..."
    if wrangler deploy --env "$target_env" --dry-run; then
        print_success "Dry-run validation passed"
    else
        print_error "Dry-run validation failed"
        exit 1
    fi

    # Create version
    print_status "Creating new version..."
    version_output=$(wrangler versions upload --env "$target_env")
    version_id=$(echo "$version_output" | grep -o 'version-[a-f0-9]*' | head -1)

    if [ -n "$version_id" ]; then
        print_success "Created version: $version_id"
    else
        print_warning "Could not extract version ID, proceeding with direct deploy"
    fi

    # Deploy
    print_status "Deploying to $target_env..."
    if wrangler deploy --env "$target_env"; then
        print_success "Deployment to $target_env completed successfully"

        # Start monitoring
        print_status "Starting log monitoring..."
        wrangler tail --env "$target_env" --format json > "${target_env}-logs.json" &
        tail_pid=$!
        print_success "Log monitoring started (PID: $tail_pid)"

        # Health check
        sleep 5
        if curl -s "https://ai.empathyfirstmedia.com/health" | grep -q "healthy"; then
            print_success "Health check passed"
        else
            print_warning "Health check failed - check logs"
        fi

        # Stop monitoring after 30 seconds
        sleep 30
        kill $tail_pid 2>/dev/null || true
        print_success "Monitoring session completed"

    else
        print_error "Deployment to $target_env failed"
        exit 1
    fi
}

# Setup monitoring and alerting
setup_monitoring() {
    print_status "Setting up advanced monitoring..."

    # Create analytics dataset
    if ! wrangler analytics datasets | grep -q "ai-platform-analytics"; then
        wrangler analytics dataset create ai-platform-analytics
        print_success "Created analytics dataset: ai-platform-analytics"
    fi

    # Setup log filtering
    print_status "Setting up log filtering rules..."
    cat > log-filters.json << 'EOF'
{
  "error_filter": "level:error",
  "performance_filter": "duration>1000",
  "ai_requests": "url:*ai*"
}
EOF
    print_success "Created log filtering configuration"
}

# Performance testing
performance_test() {
    print_status "Running performance tests..."

    # Load testing
    print_status "Running load test..."
    for i in {1..10}; do
        curl -s -w "%{time_total}\n" "https://ai.empathyfirstmedia.com/health" >> response_times.txt &
    done
    wait

    # Analyze results
    avg_time=$(awk '{sum+=$1} END {print sum/NR}' response_times.txt)
    max_time=$(sort -n response_times.txt | tail -1)
    min_time=$(sort -n response_times.txt | head -1)

    print_success "Performance test results:"
    echo "  Average response time: ${avg_time}s"
    echo "  Max response time: ${max_time}s"
    echo "  Min response time: ${min_time}s"

    # Cleanup
    rm response_times.txt
}

# Backup and recovery testing
backup_recovery_test() {
    print_status "Testing backup and recovery..."

    # D1 backup test
    print_status "Testing D1 backup..."
    backup_id=$(wrangler d1 backup create agency-ai-sessions --json | jq -r '.result.backup_id')

    if [ -n "$backup_id" ] && [ "$backup_id" != "null" ]; then
        print_success "D1 backup created: $backup_id"

        # Test restoration (to temporary database)
        temp_db="agency-ai-test-$(date +%s)"
        wrangler d1 create "$temp_db"
        wrangler d1 backup restore "$temp_db" --backup-id "$backup_id"
        print_success "Backup restoration test passed"

        # Cleanup
        wrangler d1 delete "$temp_db"
        print_success "Test cleanup completed"
    else
        print_warning "D1 backup test failed or returned empty result"
    fi
}

# Cost monitoring
cost_monitoring() {
    print_status "Setting up cost monitoring..."

    # Get usage data
    print_status "Retrieving usage data..."
    usage_data=$(wrangler usage --period 30d --json 2>/dev/null || echo "{}")

    if [ "$usage_data" != "{}" ]; then
        # Parse and display cost information
        requests=$(echo "$usage_data" | jq -r '.requests // 0')
        bandwidth=$(echo "$usage_data" | jq -r '.bandwidth_gb // 0')
        storage=$(echo "$usage_data" | jq -r '.storage_gb // 0')

        print_success "Usage summary (last 30 days):"
        echo "  Requests: $requests"
        echo "  Bandwidth: ${bandwidth}GB"
        echo "  Storage: ${storage}GB"

        # Cost estimation (rough)
        estimated_cost=$(echo "scale=2; ($requests * 0.000001) + ($bandwidth * 0.10) + ($storage * 0.05)" | bc 2>/dev/null || echo "0")
        print_success "Estimated cost: $${estimated_cost}"

    else
        print_warning "Could not retrieve usage data"
        print_status "Make sure you have the necessary permissions"
    fi
}

# Main workflow orchestration
main() {
    echo "🚀 Wrangler Workflow Automation"
    echo "==============================="

    check_prerequisites

    case "${1:-}" in
        "setup")
            setup_environments
            setup_versioning
            setup_resources
            setup_monitoring
            print_success "Setup completed successfully"
            ;;
        "deploy")
            deploy_advanced "${2:-development}"
            ;;
        "test")
            performance_test
            backup_recovery_test
            print_success "Testing completed"
            ;;
        "monitor")
            cost_monitoring
            ;;
        "resources")
            setup_resources
            ;;
        *)
            echo "Usage: $0 [command]"
            echo ""
            echo "Commands:"
            echo "  setup     - Initial setup (environments, resources, monitoring)"
            echo "  deploy    - Advanced deployment workflow"
            echo "  test      - Performance and backup testing"
            echo "  monitor   - Cost monitoring and usage analysis"
            echo "  resources - Setup Cloudflare resources"
            echo ""
            echo "Examples:"
            echo "  $0 setup"
            echo "  $0 deploy production"
            echo "  $0 test"
            echo "  ENVIRONMENT=staging $0 deploy"
            ;;
    esac
}

# Run main function
main "$@"