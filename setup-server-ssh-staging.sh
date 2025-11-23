#!/bin/bash
# Server-side SSH configuration for Cloudflare Access for Infrastructure
# Staging Environment - Run this on your SSH servers

set -e

echo "Setting up SSH server for Cloudflare Access - Staging Environment..."

# Create backup of current config
echo "Creating backup of current SSH configuration..."
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%Y%m%d_%H%M%S)

# Create the SSH configuration (this would need sudo in real deployment)
cat > sshd_config_cloudflare_staging << 'EOF'
# Cloudflare Access for Infrastructure SSH settings - Staging
PubkeyAuthentication yes
PasswordAuthentication no
ChallengeResponseAuthentication no
UsePAM yes

# Security hardening
PermitRootLogin no
PermitEmptyPasswords no
MaxAuthTries 3
LoginGraceTime 20
ClientAliveInterval 60
ClientAliveCountMax 3

# Logging
LogLevel VERBOSE

# Cloudflare CA integration (update with actual CA public key)
# Add the following line with your Cloudflare CA public key:
# TrustedUserCAKeys /etc/ssh/cloudflare-ca-staging.pub
EOF

echo "✅ SSH server configuration template created: sshd_config_cloudflare_staging"
echo ""
echo "📋 Manual steps required (run with sudo):"
echo "1. Backup current config: sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.manual"
echo "2. Update SSH config: sudo cp sshd_config_cloudflare_staging /etc/ssh/sshd_config"
echo "3. Create CA directory: sudo mkdir -p /etc/ssh/certs"
echo "4. Place CA public key at: /etc/ssh/cloudflare-ca-staging.pub"
echo "5. Update TrustedUserCAKeys path in sshd_config to point to the CA key"
echo "6. Restart SSH: sudo systemctl restart sshd"
echo ""
echo "🔑 Cloudflare CA Public Key (add this to /etc/ssh/cloudflare-ca-staging.pub):"
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN3S0JR55woUUYywTJy8/+eV5GrH45V2QCanQIyFJwqu cloudflare-access-staging"