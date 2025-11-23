#!/bin/bash
# SSH Key Rotation Script for Staging Environment
# Run this monthly to rotate SSH keys

set -e

echo "🔄 Rotating SSH keys for Staging environment"

# Check if 1Password is authenticated
if ! op whoami &> /dev/null; then
    echo "❌ Not authenticated with 1Password. Run: op signin"
    exit 1
fi

# Generate new SSH key pair
echo "Generating new SSH key pair..."
TEMP_DIR=$(mktemp -d)
ssh-keygen -t ed25519 -C "cloudflare-access-staging-$(date +%Y%m%d)" -f "$TEMP_DIR/id_ed25519" -N "" -q

echo "📋 Manual 1Password steps:"
echo "1. Create new 'SSH Key' item in Development vault"
echo "2. Title: SSH Key - ssh-ca-staging-$(date +%Y%m%d)"
echo "3. Upload private key: $TEMP_DIR/id_ed25519"
echo "4. Add public key text: $(cat $TEMP_DIR/id_ed25519.pub)"
echo "5. Add tags: ssh, cloudflare, staging, rotated"
echo ""

echo "📋 Cloudflare Zero Trust Dashboard steps:"
echo "1. Go to Access > Service Auth"
echo "2. Update the Staging SSH certificate"
echo "3. Replace public key with: $(cat $TEMP_DIR/id_ed25519.pub)"
echo ""

echo "📋 Server update steps:"
echo "1. Update /etc/ssh/cloudflare-ca-staging.pub on all servers"
echo "2. Replace with: $(cat $TEMP_DIR/id_ed25519.pub)"
echo "3. Restart SSH service: sudo systemctl restart sshd"
echo ""

# Cleanup
rm -rf "$TEMP_DIR"

echo "✅ Key rotation preparation complete"
echo "   Complete the manual steps above to finish rotation"