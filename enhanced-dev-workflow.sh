#!/bin/bash

# Enhanced 1Password Development Workflow
# Complete development environment with biometric authentication

echo "🚀 Enhanced 1Password Development Workflow"
echo "=========================================="

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

# Check 1Password CLI and authentication
check_auth() {
    print_status "Checking 1Password authentication..."

    if ! command -v op &> /dev/null; then
        print_error "1Password CLI not installed. Install from: https://developer.1password.com/docs/cli/"
        exit 1
    fi

    if ! op whoami &> /dev/null; then
        print_error "Not signed into 1Password. Run: op signin"
        exit 1
    fi

    print_success "Authenticated with 1Password"
}

# Setup shell plugins for common tools
setup_plugins() {
    print_status "Setting up shell plugins..."

    local plugins=("gh" "gcloud" "wrangler" "aws")
    local configured_plugins=()

    for plugin in "${plugins[@]}"; do
        if command -v "$plugin" &> /dev/null && op plugin inspect "$plugin" &> /dev/null; then
            configured_plugins+=("$plugin")
        fi
    done

    if [ ${#configured_plugins[@]} -gt 0 ]; then
        print_success "Configured plugins: ${configured_plugins[*]}"
    else
        print_warning "No shell plugins configured. Run: ./setup-1password-plugins.sh"
    fi
}

# Start development environment with secrets
start_dev() {
    print_status "Starting development environment with secrets..."

    local env_file=".env.$ENVIRONMENT"

    if [ ! -f "$env_file" ]; then
        print_warning "Environment file $env_file not found. Creating from template..."
        if [ -f ".env.example" ]; then
            cp ".env.example" "$env_file"
            print_success "Created $env_file from template"
        else
            print_error "No environment template found"
            exit 1
        fi
    fi

    print_status "Loading secrets from 1Password..."

    # Test secret loading
    if op run --env-file="$env_file" -- printenv DATABASE_URL &> /dev/null; then
        print_success "Secrets loaded successfully"
    else
        print_error "Failed to load secrets. Check your 1Password vault and items."
        exit 1
    fi

    # Start development server
    print_status "Starting Next.js development server..."
    op run --env-file="$env_file" -- npm run dev
}

# Database operations
db_operations() {
    local operation=$1
    local env_file=".env.$ENVIRONMENT"

    case $operation in
        "generate")
            print_status "Generating database migrations..."
            op run --env-file="$env_file" -- npm run db:generate
            ;;
        "migrate")
            print_status "Running database migrations..."
            op run --env-file="$env_file" -- npm run db:migrate
            ;;
        "studio")
            print_status "Opening Drizzle Studio..."
            op run --env-file="$env_file" -- npx drizzle-kit studio
            ;;
        *)
            print_error "Unknown database operation: $operation"
            echo "Available: generate, migrate, studio"
            exit 1
            ;;
    esac
}

# Deployment operations
deploy_app() {
    local target="${1:-staging}"

    case $target in
        "staging")
            print_status "Deploying to staging..."
            ENVIRONMENT=staging VAULT=Development ./deploy-with-1password.sh
            ;;
        "production")
            print_status "Deploying to production..."
            ENVIRONMENT=production VAULT=Production ./deploy-with-1password.sh
            ;;
        *)
            print_error "Unknown deployment target: $target"
            echo "Available: staging, production"
            exit 1
            ;;
    esac
}

# Test with secrets
run_tests() {
    print_status "Running tests with secrets..."

    local env_file=".env.$ENVIRONMENT"

    if [ -f "package.json" ] && grep -q '"test"' package.json; then
        op run --env-file="$env_file" -- npm test
        print_success "Tests completed"
    else
        print_warning "No test script found in package.json"
    fi
}

# Show available secrets
show_secrets() {
    print_status "Available secrets in $VAULT vault:"

    op item list --vault "$VAULT" --format json | jq -r '.[] | "✅ \(.title) (\(.category))"' | head -20

    echo ""
    print_status "Total items: $(op item list --vault "$VAULT" --format json | jq length)"
}

# SSH operations
ssh_operations() {
    local operation=$1

    case $operation in
        "setup")
            print_status "Setting up SSH + 1Password integration..."
            if [ -f "setup-ssh-1password-integration.sh" ]; then
                ./setup-ssh-1password-integration.sh
                print_success "SSH integration setup complete"
            else
                print_error "SSH setup script not found. Run setup-ssh-1password-integration.sh first"
            fi
            ;;
        "rotate")
            print_status "Rotating SSH keys for $ENVIRONMENT..."
            local rotate_script="rotate-ssh-keys-$ENVIRONMENT.sh"
            if [ -f "$rotate_script" ]; then
                ./$rotate_script
                print_success "SSH key rotation complete"
            else
                print_error "Rotation script not found: $rotate_script"
                echo "Run SSH setup first or check if script exists"
            fi
            ;;
        "list")
            print_status "SSH keys in $VAULT vault:"
            op item list --vault "$VAULT" --categories "SSH Key" --format json | \
                jq -r '.[] | "🔑 \(.title) - \(.createdAt | strftime("%Y-%m-%d"))"' 2>/dev/null || \
                echo "No SSH keys found or jq not available"
            ;;
        "test")
            print_status "Testing SSH access through Cloudflare..."
            echo "Note: Make sure cloudflared is running and SSH server is configured"
            echo "Usage: ssh user@ssh.$ENVIRONMENT.yourdomain.com"
            echo ""
            print_warning "Replace 'yourdomain.com' with your actual domain"
            ;;
        *)
            print_error "Unknown SSH operation: $operation"
            echo "Available: setup, rotate, list, test"
            exit 1
            ;;
    esac
}

# Interactive menu
show_menu() {
    echo ""
    echo "🔧 Enhanced Development Workflow Menu:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "1. 🚀 Start development server"
    echo "2. 🗄️  Database operations"
    echo "3. 🚢 Deploy application"
    echo "4. 🧪 Run tests"
    echo "5. 🔍 Show available secrets"
    echo "6. 🔐 SSH operations"
    echo "7. 🔧 Setup shell plugins"
    echo "8. 🌍 Switch environment"
    echo "9. ❌ Exit"
    echo ""
    read -p "Choose an option (1-9): " choice

    case $choice in
        1)
            start_dev
            ;;
        2)
            echo "Database operations:"
            echo "  a) Generate migrations"
            echo "  b) Run migrations"
            echo "  c) Open Drizzle Studio"
            read -p "Choose (a-c): " db_choice
            case $db_choice in
                a) db_operations "generate" ;;
                b) db_operations "migrate" ;;
                c) db_operations "studio" ;;
                *) print_error "Invalid choice" ;;
            esac
            ;;
        3)
            echo "Deployment targets:"
            echo "  a) Staging"
            echo "  b) Production"
            read -p "Choose (a-b): " deploy_choice
            case $deploy_choice in
                a) deploy_app "staging" ;;
                b) deploy_app "production" ;;
                *) print_error "Invalid choice" ;;
            esac
            ;;
        4)
            run_tests
            ;;
        5)
            show_secrets
            ;;
        6)
            echo "SSH operations:"
            echo "  a) Setup SSH + 1Password integration"
            echo "  b) Rotate SSH keys"
            echo "  c) List SSH keys"
            echo "  d) Test SSH access"
            echo ""
            read -p "Choose SSH operation (a-d): " ssh_choice
            case $ssh_choice in
                a) ssh_operations "setup" ;;
                b) ssh_operations "rotate" ;;
                c) ssh_operations "list" ;;
                d) ssh_operations "test" ;;
                *) print_error "Invalid choice" ;;
            esac
            ;;
        7)
            ./setup-1password-plugins.sh
            ;;
        8)
            echo "Current environment: $ENVIRONMENT"
            echo "Available: development, staging, production"
            read -p "New environment: " new_env
            if [[ "$new_env" =~ ^(development|staging|production)$ ]]; then
                ENVIRONMENT="$new_env"
                print_success "Switched to $ENVIRONMENT environment"
            else
                print_error "Invalid environment"
            fi
            ;;
        9)
            print_success "Goodbye! 👋"
            exit 0
            ;;
        *)
            print_error "Invalid choice"
            ;;
    esac

    # Return to menu unless it's a long-running command or exit
    if [[ ! "$choice" =~ ^(1|2c|8)$ ]]; then
        echo ""
        read -p "Press Enter to continue..."
        show_menu
    fi
}

# Main execution
main() {
    check_auth
    setup_plugins

    echo ""
    print_success "Welcome to Enhanced 1Password Development Workflow!"
    echo "Current environment: $ENVIRONMENT"
    echo "Current vault: $VAULT"

    # Check if run with arguments or show menu
    if [ $# -gt 0 ]; then
        case $1 in
            "dev")
                start_dev
                ;;
            "db")
                db_operations "${2:-generate}"
                ;;
            "deploy")
                deploy_app "${2:-staging}"
                ;;
            "test")
                run_tests
                ;;
            "secrets")
                show_secrets
                ;;
            *)
                print_error "Unknown command: $1"
                echo "Available: dev, db, deploy, test, secrets"
                exit 1
                ;;
        esac
    else
        show_menu
    fi
}

# Run main function
main "$@"