#!/bin/bash

# Cloudflare Access for Infrastructure SSH Setup
# This script sets up secure SSH access using short-lived certificates

set -e

echo "Setting up Cloudflare Access for Infrastructure SSH..."

# Install cloudflared if not present
if ! command -v cloudflared &> /dev/null; then
    echo "Installing cloudflared..."
    # Download and install cloudflared for your platform
    curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
    sudo dpkg -i cloudflared.deb
    rm cloudflared.deb
fi

# Generate SSH certificate (run this after setting up in Cloudflare dashboard)
echo "SSH Certificate Setup Instructions:"
echo "1. Go to Cloudflare Zero Trust Dashboard > Access > Service Auth"
echo "2. Create SSH certificate for your application"
echo "3. Copy the public key and save to /etc/ssh/ca.pub"
echo "4. Update /etc/ssh/sshd_config with:"
echo "   PubkeyAuthentication yes"
echo "   TrustedUserCAKeys /etc/ssh/ca.pub"
echo "5. Restart SSH service: sudo systemctl restart sshd"

# Create tunnel configuration
cat > tunnel-config.yaml << EOF
tunnel: your-ssh-tunnel
credentials-file: /etc/cloudflared/your-tunnel.json

ingress:
  - hostname: ssh.yourdomain.com
    service: ssh://localhost:22
  - service: http_status:404
EOF

echo "Tunnel configuration created. Update with your actual tunnel name and credentials."

# Install WARP client (for end users)
echo "For end users, install Cloudflare WARP client:"
echo "curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | sudo gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg"
echo "echo 'deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ jammy main' | sudo tee /etc/apt/sources.list.d/cloudflare-client.list"
echo "sudo apt update && sudo apt install cloudflare-warp"

echo "SSH Infrastructure setup script completed."
echo "Complete the dashboard configuration steps above."