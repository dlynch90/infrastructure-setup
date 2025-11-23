#!/bin/bash
# SSH Key Rotation Script for Development Environment
# Run this monthly to rotate SSH keys

set -e

echo "🔄 Rotating SSH keys for Development environment"

# Check if 1Password is authenticated
if ! op whoami &> /dev/null; then
    echo "❌ Not authenticated with 1Password. Run: op signin"
    exit 1
fi

# Generate new SSH key pair
echo "Generating new SSH key pair..."
TEMP_DIR=$(mktemp -d)
ssh-keygen -t ed25519 -C "cloudflare-access-development-$(date +%Y%m%d)" -f "$TEMP_DIR/id_ed25519" -N "" -q

# Store in 1Password
echo "Storing new key pair in 1Password..."
NEW_ITEM_ID=$(op item create \
    --category="SSH Key" \
    --title="SSH Key - ssh-ca-development-$(date +%Y%m%d)" \
    --vault="Development" \
    --tags="ssh,cloudflare,development,ai-agency,rotated" \
    --format=json | jq -r '.id')

# This would normally upload the key files, but for demo purposes we'll just show the commands
echo "📋 Manual 1Password steps:"
echo "1. Create new 'SSH Key' item in Development vault"
echo "2. Title: SSH Key - ssh-ca-development-$(date +%Y%m%d)"
echo "3. Upload private key: $TEMP_DIR/id_ed25519"
echo "4. Add public key text: $(cat $TEMP_DIR/id_ed25519.pub)"
echo "5. Add tags: ssh, cloudflare, development, rotated"
echo ""

echo "📋 Cloudflare Zero Trust Dashboard steps:"
echo "1. Go to Access > Service Auth"
echo "2. Update the Development SSH certificate"
echo "3. Replace public key with: $(cat $TEMP_DIR/id_ed25519.pub)"
echo ""

echo "📋 Server update steps:"
echo "1. Update /etc/ssh/cloudflare-ca-development.pub on all servers"
echo "2. Replace with: $(cat $TEMP_DIR/id_ed25519.pub)"
echo "3. Restart SSH service: sudo systemctl restart sshd"
echo ""

# Cleanup
rm -rf "$TEMP_DIR"

echo "✅ Key rotation preparation complete"
echo "   Complete the manual steps above to finish rotation"