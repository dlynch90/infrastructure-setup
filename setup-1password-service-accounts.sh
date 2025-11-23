#!/bin/bash

# 1Password Service Accounts Setup Script
# Configure automated access for CI/CD pipelines

echo "🤖 1Password Service Accounts Setup"
echo "==================================="

# Check prerequisites
if ! command -v op &> /dev/null; then
    echo "❌ 1Password CLI not found"
    exit 1
fi

echo "✅ 1Password CLI found: $(op --version)"

# Function to create and configure service account
create_service_account() {
    local name=$1
    local vault=$2
    local description=$3

    echo -e "\n🔧 Creating service account: $name"

    # Create service account
    echo "Creating service account..."
    local token=$(op service-account create "$name" --description "$description" 2>/dev/null)

    if [ $? -ne 0 ]; then
        echo "⚠️  Service account '$name' may already exist or creation failed"
        return 1
    fi

    # Extract token from output
    local sa_token=$(echo "$token" | grep -o 'op_service_[^"]*')

    if [ -z "$sa_token" ]; then
        echo "❌ Failed to extract service account token"
        return 1
    fi

    echo "✅ Service account created: $name"

    # Provision vault access
    echo "Provisioning vault access..."
    op service-account provision "$name" --vault "$vault" 2>/dev/null || true

    # Save token securely (you might want to store this in CI/CD secrets)
    echo ""
    echo "🔑 Service Account Token (save this securely):"
    echo "$sa_token"
    echo ""
    echo "💡 Store this token in your CI/CD platform as:"
    echo "   GitHub Actions: OP_SERVICE_ACCOUNT_TOKEN"
    echo "   GitLab CI: OP_SERVICE_ACCOUNT_TOKEN"
    echo "   Jenkins: OP_SERVICE_ACCOUNT_TOKEN"
    echo ""
    echo "🔒 Never commit this token to version control!"

    return 0
}

# Create service accounts for different environments
echo "Creating service accounts for automated deployments..."

# Development CI/CD
create_service_account "ci-development" "Development" "CI/CD pipeline for development environment"

# Staging CI/CD
create_service_account "ci-staging" "Development" "CI/CD pipeline for staging environment"

# Production CI/CD
create_service_account "ci-production" "Production" "CI/CD pipeline for production environment"

# Monitoring and analytics
create_service_account "monitoring" "Production" "Automated monitoring and analytics"

echo -e "\n✅ Service accounts setup complete!"
echo ""
echo "📋 Next steps:"
echo "1. Store the generated tokens securely in your CI/CD platform"
echo "2. Update your CI/CD pipelines to use these tokens"
echo "3. Test automated deployments"
echo ""
echo "🔧 Example CI/CD configuration:"
echo ""
echo "# GitHub Actions example"
echo "env:"
echo "  OP_SERVICE_ACCOUNT_TOKEN: \${{ secrets.OP_SERVICE_ACCOUNT_TOKEN }}"
echo ""
echo "steps:"
echo "- name: Setup 1Password CLI"
echo "  run: |"
echo "    curl -sSfL https://downloads.1password.com/linux/tar/stable/1password-cli.tar.gz | tar -xz"
echo "    sudo mv 1password /usr/local/bin/op"
echo "    op --version"
echo ""
echo "- name: Authenticate with 1Password"
echo "  run: |"
echo "    echo \$OP_SERVICE_ACCOUNT_TOKEN | op signin --account \${{ secrets.OP_ACCOUNT }} --service-account-token-stdin"
echo ""
echo "- name: Deploy with secrets"
echo "  run: |"
echo "    op run --env-file=.env.production -- ./deploy.sh"