#!/bin/bash

# Wrangler Tunnel Integration Script
# Integrates Cloudflare Tunnels with wrangler workflows

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
ENVIRONMENT="${ENVIRONMENT:-development}"
TUNNEL_NAME="${TUNNEL_NAME:-empathy-agency-tunnel}"

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
    print_status "Checking tunnel integration prerequisites..."

    if ! command -v wrangler &> /dev/null; then
        print_error "Wrangler CLI not found"
        exit 1
    fi

    if ! command -v cloudflared &> /dev/null; then
        print_error "cloudflared not found. Install from: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/tunnel-guide/"
        exit 1
    fi

    if ! command -v op &> /dev/null; then
        print_error "1Password CLI not found"
        exit 1
    fi

    print_success "Prerequisites check passed"
}

# Setup tunnel authentication
setup_tunnel_auth() {
    print_status "Setting up tunnel authentication..."

    # Check if tunnel credentials exist in 1Password
    if op item get "TUNNEL_CREDENTIALS" --vault "$ENVIRONMENT" &>/dev/null; then
        print_success "Tunnel credentials found in 1Password"
        return 0
    else
        print_warning "Tunnel credentials not found in 1Password"
        print_status "Creating tunnel credentials..."

        # Generate new tunnel credentials
        if cloudflared tunnel login; then
            # Get the tunnel token
            tunnel_token=$(cloudflared tunnel token "$TUNNEL_NAME" 2>/dev/null || echo "")

            if [ -n "$tunnel_token" ]; then
                print_status "Storing tunnel credentials in 1Password..."
                # Note: In a real implementation, you'd want to securely store this
                print_warning "Please manually store tunnel credentials in 1Password"
                print_status "Item name: TUNNEL_CREDENTIALS"
                print_status "Vault: $ENVIRONMENT"
                print_status "Fields: token, tunnel_name"
            else
                print_warning "Could not retrieve tunnel token"
            fi
        else
            print_error "Tunnel login failed"
            return 1
        fi
    fi
}

# Create environment-specific tunnels
create_environment_tunnels() {
    print_status "Creating environment-specific tunnels..."

    environments=("development" "staging" "production")
    base_domain="empathyfirstmedia.com"

    for env in "${environments[@]}"; do
        tunnel_name="${TUNNEL_NAME}-${env}"
        config_file="cloudflared-${env}.yaml"

        print_status "Setting up tunnel for $env environment..."

        # Create tunnel if it doesn't exist
        if ! cloudflared tunnel list | grep -q "$tunnel_name"; then
            if cloudflared tunnel create "$tunnel_name"; then
                print_success "Created tunnel: $tunnel_name"
            else
                print_error "Failed to create tunnel: $tunnel_name"
                continue
            fi
        else
            print_warning "Tunnel $tunnel_name already exists"
        fi

        # Generate tunnel configuration
        cat > "$config_file" << EOF
tunnel: $tunnel_name
credentials-file: /etc/cloudflared/tunnel-${env}.json

warp-routing:
  enabled: true

ingress:
  # Worker access
  - hostname: ${env}.ai.${base_domain}
    service: https://localhost:8787
    originRequest:
      noTLSVerify: true

  # Database access (development/staging only)
EOF

        if [[ "$env" != "production" ]]; then
            cat >> "$config_file" << EOF
  - hostname: db.${env}.${base_domain}
    service: tcp://localhost:5432
    originRequest:
      connectTimeout: 30s

  # SSH access (development/staging only)
  - hostname: ssh.${env}.${base_domain}
    service: ssh://localhost:22
    originRequest:
      connectTimeout: 30s
      tlsTimeout: 30s
      tcpKeepAlive: 30s
      keepAliveTimeout: 90s
      keepAliveConnections: 100
EOF
        fi

        # Add health check and catch-all
        cat >> "$config_file" << EOF

  # Health check
  - hostname: health.${env}.${base_domain}
    service: http://localhost:8787/health

  # Catch-all
  - service: http_status:404

log:
  level: info
  file: /var/log/cloudflared/tunnel-${env}.log

metrics: 127.0.0.1:808${env: -1}  # 8081, 8082, 8083

protocol: quic
pool-size: 100
compression-quality: 6
autoupdate-freq: 24h0m0s
edge-ip-version: auto
EOF

        print_success "Created tunnel configuration: $config_file"
    done
}

# Integrate tunnels with wrangler
integrate_wrangler_tunnels() {
    print_status "Integrating tunnels with wrangler workflows..."

    # Update wrangler.toml with tunnel configurations
    if [ -f "wrangler.toml" ]; then
        print_status "Updating wrangler.toml with tunnel integration..."

        # Add tunnel configuration to wrangler.toml
        cat >> wrangler.toml << EOF

# Tunnel integration for development
[dev]
port = 8787
local_protocol = "https"
upstream_protocol = "https"
host = "localhost"

# Environment-specific tunnel configurations
[env.development.tunnel]
name = "${TUNNEL_NAME}-development"
hostname = "dev.ai.empathyfirstmedia.com"

[env.staging.tunnel]
name = "${TUNNEL_NAME}-staging"
hostname = "staging.ai.empathyfirstmedia.com"

[env.production.tunnel]
name = "${TUNNEL_NAME}-production"
hostname = "ai.empathyfirstmedia.com"
EOF

        print_success "Updated wrangler.toml with tunnel integration"
    else
        print_warning "wrangler.toml not found"
    fi
}

# Setup tunnel-based development
setup_tunnel_development() {
    print_status "Setting up tunnel-based development environment..."

    # Create development script with tunnel integration
    cat > dev-with-tunnel.sh << 'EOF'
#!/bin/bash

# Development with tunnel integration
ENVIRONMENT="${ENVIRONMENT:-development}"

echo "🚀 Starting development with tunnel integration..."
echo "Environment: $ENVIRONMENT"

# Start tunnel in background
echo "Starting Cloudflare tunnel..."
cloudflared tunnel run "${TUNNEL_NAME}-${ENVIRONMENT}" &
TUNNEL_PID=$!

# Wait for tunnel to establish
sleep 5

# Start wrangler dev with tunnel
echo "Starting wrangler development server..."
op run --env-file=".env.${ENVIRONMENT}" -- \
  wrangler dev \
  --port 8787 \
  --env "$ENVIRONMENT" \
  --local-protocol https \
  --upstream-protocol https

# Cleanup tunnel on exit
kill $TUNNEL_PID 2>/dev/null || true

echo "Development session ended"
EOF

    chmod +x dev-with-tunnel.sh
    print_success "Created tunnel-based development script"
}

# Setup SSH tunnel integration
setup_ssh_integration() {
    print_status "Setting up SSH tunnel integration..."

    # Create SSH config for tunnel access
    cat > ~/.ssh/cloudflare-tunnels << EOF
# Cloudflare Tunnel SSH Configurations

# Development environment
Host dev-ssh
    HostName ssh.dev.empathyfirstmedia.com
    User developer
    ProxyCommand cloudflared access ssh --hostname %h
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

# Staging environment
Host staging-ssh
    HostName ssh.staging.empathyfirstmedia.com
    User developer
    ProxyCommand cloudflared access ssh --hostname %h
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

# Production environment (read-only access)
Host prod-ssh
    HostName ssh.empathyfirstmedia.com
    User readonly
    ProxyCommand cloudflared access ssh --hostname %h
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
EOF

    # Update global SSH config
    if ! grep -q "Include ~/.ssh/cloudflare-tunnels" ~/.ssh/config 2>/dev/null; then
        echo "Include ~/.ssh/cloudflare-tunnels" >> ~/.ssh/config
        print_success "Updated SSH config with tunnel integration"
    else
        print_warning "SSH tunnel config already included"
    fi
}

# Setup monitoring for tunnels
setup_tunnel_monitoring() {
    print_status "Setting up tunnel monitoring..."

    # Create monitoring script
    cat > monitor-tunnels.sh << 'EOF'
#!/bin/bash

# Tunnel monitoring script
echo "🔍 Monitoring Cloudflare Tunnels"
echo "==============================="

# Check tunnel status
echo "Tunnel Status:"
cloudflared tunnel list

echo ""
echo "Active Connections:"
for env in development staging production; do
    echo "📊 $env environment:"
    curl -s "https://health.${env}.empathyfirstmedia.com" || echo "  ❌ Health check failed"
done

echo ""
echo "Resource Usage:"
ps aux | grep cloudflared | grep -v grep | while read line; do
    pid=$(echo $line | awk '{print $2}')
    cpu=$(echo $line | awk '{print $3}')
    mem=$(echo $line | awk '{print $4}')
    echo "  PID $pid: CPU ${cpu}%, MEM ${mem}%"
done
EOF

    chmod +x monitor-tunnels.sh
    print_success "Created tunnel monitoring script"
}

# Test tunnel connectivity
test_tunnel_connectivity() {
    print_status "Testing tunnel connectivity..."

    environments=("development" "staging" "production")

    for env in "${environments[@]}"; do
        print_status "Testing $env tunnel..."

        # Test health endpoint
        if curl -s --max-time 10 "https://health.${env}.empathyfirstmedia.com" | grep -q "healthy"; then
            print_success "$env tunnel: ✅ Health check passed"
        else
            print_warning "$env tunnel: ❌ Health check failed"
        fi

        # Test worker endpoint (development/staging only)
        if [[ "$env" != "production" ]]; then
            if curl -s --max-time 10 "https://${env}.ai.empathyfirstmedia.com/health" | grep -q "healthy"; then
                print_success "$env worker: ✅ Worker accessible via tunnel"
            else
                print_warning "$env worker: ❌ Worker not accessible via tunnel"
            fi
        fi
    done
}

# Main tunnel integration workflow
main() {
    echo "🌐 Wrangler Tunnel Integration"
    echo "============================="

    check_prerequisites

    case "${1:-}" in
        "setup")
            setup_tunnel_auth
            create_environment_tunnels
            integrate_wrangler_tunnels
            setup_tunnel_development
            setup_ssh_integration
            setup_tunnel_monitoring
            print_success "Tunnel integration setup completed"
            ;;
        "test")
            test_tunnel_connectivity
            ;;
        "monitor")
            ./monitor-tunnels.sh
            ;;
        "dev")
            ./dev-with-tunnel.sh
            ;;
        *)
            echo "Usage: $0 [command]"
            echo ""
            echo "Commands:"
            echo "  setup   - Complete tunnel integration setup"
            echo "  test    - Test tunnel connectivity"
            echo "  monitor - Monitor tunnel status and performance"
            echo "  dev     - Start development with tunnel integration"
            echo ""
            echo "Examples:"
            echo "  $0 setup"
            echo "  ENVIRONMENT=staging $0 test"
            echo "  $0 monitor"
            ;;
    esac
}

# Run main function
main "$@"