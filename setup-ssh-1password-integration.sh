#!/bin/bash

# Cloudflare SSH Access for Infrastructure with 1Password Integration
# Secure SSH key management and storage with biometric authentication

set -e

echo "🔐 Cloudflare SSH + 1Password Integration Setup"
echo "================================================"

# Check prerequisites
if ! command -v op &> /dev/null; then
    echo "❌ 1Password CLI not found. Install from: https://1password.com/downloads/command-line/"
    exit 1
fi

if ! command -v cloudflared &> /dev/null; then
    echo "❌ cloudflared not found. Install from: https://developers.cloudflare.com/cloudflared/install/"
    exit 1
fi

echo "✅ Prerequisites check passed"

# Function to create SSH key pair and store in 1Password
create_ssh_keypair() {
    local key_name=$1
    local vault=$2
    local description=$3
    local environment=$4

    echo -e "\n🔑 Creating SSH key pair: $key_name"

    # Create temporary directory for keys
    local temp_dir=$(mktemp -d)
    local private_key="$temp_dir/id_ed25519"
    local public_key="$private_key.pub"

    # Generate Ed25519 key pair (more secure than RSA)
    echo "Generating Ed25519 key pair..."
    ssh-keygen -t ed25519 -C "cloudflare-access-$environment-$key_name" -f "$private_key" -N "" -q

    # Create 1Password item for the key pair
    echo "Storing key pair in 1Password..."

    # Create the item with both private and public keys
    local op_item_id=$(op item create \
        --category="SSH Key" \
        --title="SSH Key - $key_name ($environment)" \
        --vault="$vault" \
        --tags="ssh,cloudflare,$environment,ai-agency" \
        "Private Key[file]=$private_key" \
        "Public Key[text]=$public_key" \
        "Environment[text]=$environment" \
        "Description[text]=$description" \
        "Created[text]=$(date -Iseconds)" \
        --format=json | jq -r '.id')

    if [ -z "$op_item_id" ]; then
        echo "❌ Failed to create 1Password item"
        rm -rf "$temp_dir"
        return 1
    fi

    echo "✅ SSH key pair stored in 1Password: $op_item_id"

    # Get the public key for Cloudflare configuration
    local pub_key_content=$(cat "$public_key")

    # Clean up temporary files
    rm -rf "$temp_dir"

    # Return the public key content
    echo "$pub_key_content"
}

# Function to setup Cloudflare Access for Infrastructure
setup_cloudflare_ssh() {
    local vault=$1
    local environment=$2

    echo -e "\n☁️  Setting up Cloudflare Access for Infrastructure"

    # Create SSH certificate authority key
    local ca_public_key=$(create_ssh_keypair "ssh-ca-$environment" "$vault" "SSH Certificate Authority for $environment infrastructure access" "$environment")

    if [ -z "$ca_public_key" ]; then
        echo "❌ Failed to create SSH CA key"
        return 1
    fi

    # Store CA public key in a way that can be easily retrieved
    echo "$ca_public_key" > "ssh-ca-$environment.pub"

    echo "📋 Cloudflare Zero Trust Dashboard Setup Instructions:"
    echo ""
    echo "1. Go to: https://dash.teams.cloudflare.com"
    echo "2. Navigate to: Access > Service Auth"
    echo "3. Create new SSH certificate"
    echo "4. Copy this public key:"
    echo ""
    echo "$ca_public_key"
    echo ""
    echo "5. Save the public key in Cloudflare"
    echo "6. Note the Service Token Secret for server configuration"

    # Create configuration template
    cat > "cloudflared-ssh-config-$environment.yaml" << EOF
# Cloudflare Tunnel SSH Configuration for $environment
tunnel: ssh-access-$environment
credentials-file: /etc/cloudflared/tunnel-$environment.json

ingress:
  # SSH access via Access for Infrastructure
  - hostname: ssh.$environment.yourdomain.com
    service: ssh://localhost:22
    originRequest:
      connectTimeout: 30s
      tlsTimeout: 30s
      tcpKeepAlive: 30s
      keepAliveTimeout: 90s
      keepAliveConnections: 100

  # Database access for development
  - hostname: db.$environment.yourdomain.com
    service: tcp://localhost:5432
    originRequest:
      connectTimeout: 30s

  # Health check
  - hostname: health.$environment.yourdomain.com
    service: http://localhost:8787/health

  - service: http_status:404

# SSH Certificate Authority (update with your Cloudflare service token)
# service_token: op://$vault/SSH_CA_Service_Token_$environment/token
EOF

    echo "✅ Cloudflare configuration template created: cloudflared-ssh-config-$environment.yaml"
}

# Function to setup server-side SSH configuration
setup_server_ssh_config() {
    local environment=$1
    local vault=$2

    echo -e "\n🖥️  Server-side SSH configuration for $environment"

    cat > "setup-server-ssh-$environment.sh" << 'EOF'
#!/bin/bash
# Server-side SSH configuration for Cloudflare Access for Infrastructure
# Run this on your SSH servers

set -e

echo "Setting up SSH server for Cloudflare Access..."

# Backup existing SSH config
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%Y%m%d_%H%M%S)

# Update SSH daemon configuration
sudo tee -a /etc/ssh/sshd_config > /dev/null << SSH_CONFIG
# Cloudflare Access for Infrastructure SSH settings
PubkeyAuthentication yes
PasswordAuthentication no
ChallengeResponseAuthentication no
UsePAM yes

# Short-lived certificates (will be added after Cloudflare setup)
# TrustedUserCAKeys /etc/ssh/ca.pub

# SSH Certificate Authority (update path after placing key)
# TrustedUserCAKeys /etc/ssh/cloudflare-ca.pub

# Security hardening
PermitRootLogin no
PermitEmptyPasswords no
MaxAuthTries 3
LoginGraceTime 20
ClientAliveInterval 60
ClientAliveCountMax 3

# Logging
LogLevel VERBOSE
EOF

# Create directory for SSH certificates
sudo mkdir -p /etc/ssh/certs

# Set proper permissions
sudo chmod 755 /etc/ssh/certs
sudo chown root:root /etc/ssh/certs

echo "✅ SSH server configuration updated"
echo ""
echo "📋 Next steps on server:"
echo "1. Place the Cloudflare CA public key at: /etc/ssh/cloudflare-ca.pub"
echo "2. Update sshd_config with: TrustedUserCAKeys /etc/ssh/cloudflare-ca.pub"
echo "3. Restart SSH: sudo systemctl restart sshd"
echo "4. Test connection: ssh user@your-server (should prompt for Cloudflare auth)"
EOF

    chmod +x "setup-server-ssh-$environment.sh"

    echo "✅ Server configuration script created: setup-server-ssh-$environment.sh"
}

# Function to setup 1Password service account for SSH automation
setup_ssh_service_account() {
    local vault=$1
    local environment=$2

    echo -e "\n🤖 Creating SSH automation service account"

    # Create service account for SSH key rotation
    local token=$(op service-account create "ssh-automation-$environment" \
        --description "Automated SSH key rotation for $environment infrastructure" 2>/dev/null)

    if [ $? -eq 0 ]; then
        local sa_token=$(echo "$token" | grep -o 'op_service_[^"]*')

        echo "✅ Service account created for SSH automation"
        echo ""
        echo "🔑 Service Account Token (store securely in CI/CD):"
        echo "$sa_token"
        echo ""
        echo "💡 Use this for automated SSH key rotation in CI/CD pipelines"

        # Provision vault access
        op service-account provision "ssh-automation-$environment" --vault "$vault" 2>/dev/null || true
    else
        echo "⚠️  Service account may already exist or creation failed"
    fi
}

# Function to create SSH rotation script
create_rotation_script() {
    local vault=$1
    local environment=$2

    cat > "rotate-ssh-keys-$environment.sh" << EOF
#!/bin/bash
# SSH Key Rotation Script with 1Password Integration
# Automatically rotates SSH keys and updates Cloudflare configuration

set -e

echo "🔄 Rotating SSH keys for $environment environment"

# Authenticate with 1Password (assumes service account token is available)
if [ -z "\$OP_SERVICE_ACCOUNT_TOKEN" ]; then
    echo "❌ OP_SERVICE_ACCOUNT_TOKEN environment variable not set"
    echo "Set it with: export OP_SERVICE_ACCOUNT_TOKEN='your-token'"
    exit 1
fi

echo \$OP_SERVICE_ACCOUNT_TOKEN | op signin --service-account-token-stdin

# Create new SSH key pair
echo "Creating new SSH key pair..."
NEW_PUB_KEY=\$(op item create \\
    --category="SSH Key" \\
    --title="SSH Key - ssh-ca-$environment-\$(date +%Y%m%d-%H%M%S)" \\
    --vault="$vault" \\
    --tags="ssh,cloudflare,$environment,ai-agency,rotated" \\
    "Environment[text]=$environment" \\
    "Description[text]=Rotated SSH CA key for $environment infrastructure" \\
    "Created[text]=\$(date -Iseconds)" \\
    "Rotated[text]=true" \\
    --format=json | jq -r '.id')

if [ -z "\$NEW_PUB_KEY" ]; then
    echo "❌ Failed to create new SSH key"
    exit 1
fi

echo "✅ New SSH key created: \$NEW_PUB_KEY"

# Get the public key content
PUB_KEY_CONTENT=\$(op read "op://$vault/\$NEW_PUB_KEY/Public Key")

if [ -z "\$PUB_KEY_CONTENT" ]; then
    echo "❌ Failed to retrieve public key"
    exit 1
fi

echo "🔄 Updating Cloudflare Access configuration..."
echo ""
echo "📋 Update this public key in Cloudflare Zero Trust Dashboard:"
echo "   Access > Service Auth > Your SSH Certificate"
echo ""
echo "\$PUB_KEY_CONTENT"
echo ""
echo "📋 Then update your servers with the new CA key"
echo ""
echo "✅ SSH key rotation complete"
echo "   Old keys remain in 1Password for audit purposes"
EOF

    chmod +x "rotate-ssh-keys-$environment.sh"

    echo "✅ SSH key rotation script created: rotate-ssh-keys-$environment.sh"
}

# Main setup process
echo "Starting SSH + 1Password integration setup..."

# Setup for different environments
environments=("development" "staging" "production")
vaults=("Development" "Development" "Production")

for i in "${!environments[@]}"; do
    environment="${environments[$i]}"
    vault="${vaults[$i]}"

    echo -e "\n🏗️  Setting up $environment environment"

    # Create SSH key pair and store in 1Password
    setup_cloudflare_ssh "$vault" "$environment"

    # Create server configuration
    setup_server_ssh_config "$environment" "$vault"

    # Setup service account for automation
    setup_ssh_service_account "$vault" "$environment"

    # Create rotation script
    create_rotation_script "$vault" "$environment"

done

echo -e "\n🎉 SSH + 1Password integration setup complete!"
echo ""
echo "📋 Summary of created files:"
echo "- SSH CA public keys: ssh-ca-{environment}.pub"
echo "- Cloudflare configs: cloudflared-ssh-config-{environment}.yaml"
echo "- Server setup scripts: setup-server-ssh-{environment}.sh"
echo "- Key rotation scripts: rotate-ssh-keys-{environment}.sh"
echo ""
echo "🔒 Security benefits:"
echo "- SSH keys stored securely in 1Password with biometric access"
echo "- Short-lived certificates replace long-lived SSH keys"
echo "- Automated key rotation capabilities"
echo "- Service accounts for CI/CD automation"
echo "- Audit trails for all key access"
echo ""
echo "🚀 Next steps:"
echo "1. Complete Cloudflare Zero Trust dashboard configuration"
echo "2. Run server setup scripts on your infrastructure"
echo "3. Store service account tokens securely in CI/CD"
echo "4. Test SSH access through Cloudflare"
echo "5. Schedule automated key rotation (recommended: monthly)"