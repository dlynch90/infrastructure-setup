# 🔐 SSH + 1Password Integration for Cloudflare Access

Complete SSH infrastructure access setup with secure key management through 1Password and biometric authentication.

## 🎯 Overview

This integration provides **enterprise-grade SSH access** to your infrastructure using:
- **Cloudflare Access for Infrastructure** - Short-lived certificates instead of long-lived keys
- **1Password secure storage** - Biometric-protected SSH key management
- **Automated key rotation** - Security best practices with zero manual work
- **CI/CD integration** - Service accounts for automated deployments

## 🚀 Quick Start

### 1. Run the Integration Setup
```bash
# Make executable and run
chmod +x setup-ssh-1password-integration.sh
./setup-ssh-1password-integration.sh
```

### 2. Complete Cloudflare Dashboard Setup
The script generates configuration files and provides exact instructions for:
- SSH certificate creation in Cloudflare Zero Trust
- Public key deployment steps
- Service token configuration

### 3. Configure Your Servers
```bash
# Run on each SSH server
./setup-server-ssh-development.sh    # For development
./setup-server-ssh-staging.sh        # For staging
./setup-server-ssh-production.sh     # For production
```

## 📁 Generated Files

The setup script creates environment-specific configurations:

### SSH Key Storage
- `ssh-ca-development.pub` - Development CA public key
- `ssh-ca-staging.pub` - Staging CA public key
- `ssh-ca-production.pub` - Production CA public key

### Cloudflare Tunnel Configs
- `cloudflared-ssh-config-development.yaml`
- `cloudflared-ssh-config-staging.yaml`
- `cloudflared-ssh-config-production.yaml`

### Server Setup Scripts
- `setup-server-ssh-development.sh`
- `setup-server-ssh-staging.sh`
- `setup-server-ssh-production.sh`

### Key Rotation Automation
- `rotate-ssh-keys-development.sh`
- `rotate-ssh-keys-staging.sh`
- `rotate-ssh-keys-production.sh`

## 🔑 1Password Storage Structure

SSH keys are stored securely with comprehensive metadata:

```
Vault: Development (or Production)
├── SSH Key - ssh-ca-development-20241123
│   ├── Private Key (file attachment)
│   ├── Public Key (text field)
│   ├── Environment: development
│   ├── Description: SSH Certificate Authority for development infrastructure
│   ├── Created: 2024-11-23T10:30:00Z
│   └── Tags: ssh, cloudflare, development, ai-agency
```

### Key Features
- **Biometric access** - Touch ID/Face ID required for key access
- **Audit trails** - Complete access logging in 1Password
- **Environment isolation** - Separate vaults for dev/staging/prod
- **Automated rotation** - Old keys retained for compliance

## 🖥️ Server Configuration

### Automatic Setup
Each environment has a dedicated setup script that configures:

```bash
# Security hardening
PubkeyAuthentication yes
PasswordAuthentication no
PermitRootLogin no
MaxAuthTries 3

# Cloudflare CA integration
TrustedUserCAKeys /etc/ssh/cloudflare-ca.pub

# Connection settings
ClientAliveInterval 60
ClientAliveCountMax 3
```

### Manual Steps Required
1. **Place CA public key** on servers: `/etc/ssh/cloudflare-ca.pub`
2. **Update SSH config** with the CA key path
3. **Restart SSH service**: `sudo systemctl restart sshd`
4. **Test authentication**: SSH connections now require Cloudflare login

## 🔄 Automated Key Rotation

### Monthly Rotation Schedule
```bash
# Rotate development keys
./rotate-ssh-keys-development.sh

# Rotate staging keys
./rotate-ssh-keys-staging.sh

# Rotate production keys
./rotate-ssh-keys-production.sh
```

### CI/CD Integration
```yaml
# GitHub Actions example
name: SSH Key Rotation
on:
  schedule:
    - cron: '0 2 1 * *'  # Monthly on the 1st at 2 AM
  workflow_dispatch:

jobs:
  rotate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Authenticate 1Password
        run: echo ${{ secrets.OP_SERVICE_ACCOUNT_TOKEN }} | op signin --service-account-token-stdin

      - name: Rotate SSH Keys
        run: ./rotate-ssh-keys-production.sh
```

## 🔒 Security Architecture

### Zero Trust Model
```
User Device ──(WARP)──▶ Cloudflare ──(Short-lived Cert)──▶ SSH Server
       │                      │                                │
       └─ Biometric Auth      └─ Identity Verification         └─ Certificate Validation
```

### Security Benefits
- **No long-lived credentials** - Certificates expire automatically
- **Device posture checks** - Ensure compliant devices only
- **Multi-factor authentication** - Required for all access
- **Session recording** - All SSH sessions logged
- **Geographic restrictions** - IP and location-based policies

## 🤖 Service Accounts for Automation

### Created Service Accounts
- `ssh-automation-development` - Development key rotation
- `ssh-automation-staging` - Staging key rotation
- `ssh-automation-production` - Production key rotation

### CI/CD Usage
```bash
# Store token securely in CI/CD secrets
export OP_SERVICE_ACCOUNT_TOKEN="op_service_..."

# Authenticate and rotate keys
echo $OP_SERVICE_ACCOUNT_TOKEN | op signin --service-account-token-stdin
./rotate-ssh-keys-production.sh
```

## 📊 Monitoring & Compliance

### 1Password Audit Trails
- **Access logging** - Every key access recorded
- **Geographic tracking** - Access location monitoring
- **Device information** - Authorized device verification
- **Time-based access** - Usage pattern analysis

### Cloudflare Analytics
- **Access attempts** - Failed/successful authentication
- **Geographic distribution** - Access location analytics
- **Device types** - Authorized device monitoring
- **Session duration** - Usage pattern tracking

## 🚨 Emergency Procedures

### Key Compromise Response
1. **Immediate rotation**: `./rotate-ssh-keys-environment.sh`
2. **Server key removal**: Update all servers with new CA key
3. **Access review**: Audit recent access in 1Password
4. **Policy update**: Strengthen access policies if needed

### Service Disruption
1. **Check Cloudflare status**: Verify Zero Trust service health
2. **1Password access**: Ensure biometric authentication works
3. **Backup access**: Use alternative authentication methods
4. **Communication**: Notify team of temporary access changes

## 🔧 Advanced Configuration

### Custom SSH Policies
```yaml
# In Cloudflare Zero Trust
policies:
  - name: "SSH Infrastructure Access"
    include:
      - group: "infrastructure-team"
    require:
      - authentication_method: ["saml", "device_posture"]
      - device_posture: "compliant"
```

### Multi-Region SSH Access
```yaml
# Load balanced SSH access
pools:
  - name: "global-ssh-pool"
    origins:
      - name: "us-east-ssh"
        address: "ssh-us-east.yourdomain.com"
      - name: "eu-west-ssh"
        address: "ssh-eu-west.yourdomain.com"
```

## 📈 Scaling Considerations

### Multi-Environment Support
- **Development**: Full access for development team
- **Staging**: Restricted access for QA/testing
- **Production**: Minimal access with approval workflows

### Team Growth
- **Service accounts**: Scale to unlimited CI/CD pipelines
- **Group policies**: Role-based access control
- **Audit automation**: Automated compliance reporting

## 🎯 Best Practices

### Key Management
- **Rotate monthly** - Automated rotation prevents key fatigue
- **Environment isolation** - Never share keys between environments
- **Access reviews** - Quarterly access entitlement reviews
- **Emergency procedures** - Documented compromise response

### Operational Excellence
- **Monitoring alerts** - Failed authentication notifications
- **Backup procedures** - Multiple access methods available
- **Documentation** - Keep runbooks updated
- **Training** - Team familiar with procedures

---

## 💡 Pro Tips

1. **Test regularly** - Use staging environment for testing changes
2. **Monitor logs** - Review access patterns for anomalies
3. **Automate everything** - Use CI/CD for all key operations
4. **Document procedures** - Keep runbooks current
5. **Review quarterly** - Audit access and update policies

## 📞 Support

For issues or questions:
- **1Password**: Check CLI documentation and service status
- **Cloudflare**: Review Zero Trust dashboard and logs
- **SSH**: Verify server configurations and key deployments

---

**Implementation Cost: $0** 🎉

All features use existing 1Password Business and Cloudflare subscriptions.