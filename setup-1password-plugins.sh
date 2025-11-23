#!/bin/bash

# 1Password Shell Plugins Setup Script
# Configure biometric authentication for development CLIs

echo "🔐 1Password Shell Plugins Setup"
echo "================================"

# Check if 1Password CLI is installed
if ! command -v op &> /dev/null; then
    echo "❌ 1Password CLI not found. Please install it first:"
    echo "   https://developer.1password.com/docs/cli/get-started/"
    exit 1
fi

echo "✅ 1Password CLI found: $(op --version)"

# Function to setup a plugin
setup_plugin() {
    local plugin=$1
    local item_path=$2
    local description=$3

    echo -e "\n🔧 Setting up $plugin plugin..."

    if op plugin inspect "$plugin" &> /dev/null; then
        echo "⚠️  $plugin plugin already configured"
        return
    fi

    echo "📝 $description"
    echo "   Item path: $item_path"
    echo ""
    echo "Make sure you have created this item in 1Password with the required fields."
    echo "Then run: op plugin init $plugin"
    echo ""
    read -p "Press Enter when ready to configure $plugin plugin..."
    op plugin init "$plugin"
}

# Setup GitHub CLI plugin
setup_plugin "gh" "op://Development/GITHUB_PAT_API_KEY" "GitHub CLI authentication using Personal Access Token"

# Setup Google Cloud CLI plugin
setup_plugin "gcloud" "op://Development/GCP_AI_Agency/Main_SA_Key" "Google Cloud CLI authentication using service account key"

# Setup Cloudflare Workers CLI plugin
setup_plugin "wrangler" "op://Development/CLOUDFLARE_API_TOKEN" "Cloudflare Workers CLI authentication"

# Setup AWS CLI plugin
setup_plugin "aws" "op://Development/AWS" "AWS CLI authentication using access keys"

# Setup Vercel CLI plugin (if available)
if command -v vercel &> /dev/null; then
    setup_plugin "vercel" "op://Development/VERCEL_TOKEN" "Vercel CLI authentication"
fi

# Setup Heroku CLI plugin (if available)
if command -v heroku &> /dev/null; then
    setup_plugin "heroku" "op://Development/HEROKU_API_KEY" "Heroku CLI authentication"
fi

echo -e "\n✅ Plugin setup complete!"
echo ""
echo "🎯 Test your plugins:"
echo "   gh auth status          # Test GitHub CLI"
echo "   gcloud auth list        # Test Google Cloud CLI"
echo "   wrangler whoami         # Test Cloudflare CLI"
echo "   aws sts get-caller-identity  # Test AWS CLI"
echo ""
echo "💡 Tips:"
echo "   • Use biometric authentication (Touch ID/Face ID) when prompted"
echo "   • Plugins cache authentication for faster subsequent use"
echo "   • Run 'op plugin list' to see all configured plugins"