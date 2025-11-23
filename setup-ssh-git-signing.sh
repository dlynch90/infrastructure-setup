#!/bin/bash

# SSH Git Commit Signing Setup with 1Password
# Follows 1Password documentation for SSH-based Git commit signing

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check Git version
    if ! command -v git &> /dev/null; then
        log_error "Git is not installed. Please install Git 2.34.0 or later."
        exit 1
    fi

    GIT_VERSION=$(git --version | awk '{print $3}')
    log_info "Git version: $GIT_VERSION"

    # Check if Git version supports SSH signing (Git 2.34+)
    GIT_MAJOR=$(echo $GIT_VERSION | cut -d. -f1)
    GIT_MINOR=$(echo $GIT_VERSION | cut -d. -f2)

    if [[ $GIT_MAJOR -lt 2 ]] || [[ $GIT_MAJOR -eq 2 && $GIT_MINOR -lt 34 ]]; then
        log_error "Your Git version $GIT_VERSION does not support SSH commit signing. Please upgrade to Git 2.34.0 or later."
        exit 1
    fi

    # Check 1Password CLI
    if ! command -v op &> /dev/null; then
        log_error "1Password CLI is not installed. Please install it first."
        exit 1
    fi

    # Check 1Password authentication
    if ! op whoami &> /dev/null; then
        log_error "Not signed in to 1Password. Please run 'op signin' first."
        exit 1
    fi

    log_success "Prerequisites check passed"
}

# List available SSH keys
list_ssh_keys() {
    log_info "Available SSH keys in 1Password:"
    echo

    # List SSH keys with details
    op item list | grep -i ssh | while read -r line; do
        ITEM_ID=$(echo "$line" | awk '{print $1}')
        TITLE=$(echo "$line" | awk '{print $2}')

        # Get more details about the key
        DETAILS=$(op item get "$ITEM_ID" --format json 2>/dev/null | jq -r '.fields[] | select(.label == "public key") | .value' 2>/dev/null || echo "No public key field")

        echo "ID: $ITEM_ID"
        echo "Title: $TITLE"
        if [[ "$DETAILS" != "No public key field" ]] && [[ ${#DETAILS} -gt 50 ]]; then
            echo "Public Key: ${DETAILS:0:50}..."
        else
            echo "Public Key: $DETAILS"
        fi
        echo "---"
    done
}

# Configure Git for SSH signing
configure_git_signing() {
    local key_id="$1"

    if [[ -z "$key_id" ]]; then
        log_error "No SSH key ID provided"
        return 1
    fi

    log_info "Configuring Git for SSH commit signing with key ID: $key_id"

    # Get the public key for configuration
    PUBLIC_KEY=$(op item get "$key_id" --fields public_key 2>/dev/null || op item get "$key_id" --fields "public key" 2>/dev/null)

    if [[ -z "$PUBLIC_KEY" ]]; then
        log_error "Could not retrieve public key from 1Password item $key_id"
        return 1
    fi

    # Configure Git globally
    git config --global gpg.format ssh
    git config --global user.signingkey "$PUBLIC_KEY"
    git config --global commit.gpgsign true
    git config --global gpg.ssh.program "/Applications/1Password.app/Contents/MacOS/op-ssh-sign"

    # Verify configuration
    log_info "Git configuration applied:"
    echo "gpg.format: $(git config --global gpg.format)"
    echo "user.signingkey: $(git config --global user.signingkey)"
    echo "commit.gpgsign: $(git config --global commit.gpgsign)"
    echo "gpg.ssh.program: $(git config --global gpg.ssh.program)"

    log_success "Git SSH signing configured successfully"
}

# Show platform registration instructions
show_registration_instructions() {
    local key_id="$1"

    if [[ -z "$key_id" ]]; then
        log_error "No SSH key ID provided"
        return 1
    fi

    log_info "Registering your SSH public key for commit verification"
    echo

    # Get the public key
    PUBLIC_KEY=$(op item get "$key_id" --fields public_key 2>/dev/null || op item get "$key_id" --fields "public key" 2>/dev/null)

    if [[ -z "$PUBLIC_KEY" ]]; then
        log_error "Could not retrieve public key from 1Password item $key_id"
        return 1
    fi

    echo "Your SSH Public Key for commit signing:"
    echo "$PUBLIC_KEY"
    echo

    cat << 'EOF'
📋 Copy the public key above and register it on your Git platform:

GITHUB:
1. Go to: https://github.com/settings/keys
2. Click "New SSH key"
3. Title: "SSH Commit Signing Key"
4. Key type: "Signing key"
5. Paste the public key above
6. Click "Add SSH key"

GITLAB:
1. Go to: https://gitlab.com/-/profile/keys
2. Title: "SSH Commit Signing Key"
3. Usage type: "Signing"
4. Paste the public key above
5. Click "Add key"

BITBUCKET:
1. Go to: https://bitbucket.org/account/settings/ssh-keys/
2. Click "Add key"
3. Label: "SSH Commit Signing Key"
4. Paste the public key above
5. Click "Add key"

EOF
}

# Test commit signing
test_commit_signing() {
    log_info "Testing SSH commit signing..."

    # Create a test commit
    echo "# SSH Git Commit Signing Test" > test-commit-signing.md
    git add test-commit-signing.md
    git commit -m "Test SSH commit signing with 1Password" -S

    if [[ $? -eq 0 ]]; then
        log_success "Test commit created successfully!"
        log_info "You should see a 'Verified' badge on this commit when pushed to your Git platform."

        # Show commit details
        echo
        log_info "Commit details:"
        git log --show-signature -1
    else
        log_error "Failed to create signed commit"
        return 1
    fi
}

# Main menu
show_menu() {
    echo
    echo "========================================"
    echo "🔐 SSH Git Commit Signing Setup"
    echo "========================================"
    echo
    echo "Available SSH keys in 1Password:"
    op item list | grep -i ssh | nl -v 1
    echo
    echo "Choose an option:"
    echo "1) Configure Git signing with a specific key"
    echo "2) Show registration instructions for a key"
    echo "3) Test commit signing"
    echo "4) Show current Git signing configuration"
    echo "5) Exit"
    echo
    read -p "Enter your choice (1-5): " choice
}

# Main function
main() {
    check_prerequisites

    while true; do
        show_menu

        case $choice in
            1)
                echo
                read -p "Enter the number of the SSH key to use for signing: " key_num

                # Get the key ID from the numbered list
                KEY_ID=$(op item list | grep -i ssh | sed -n "${key_num}p" | awk '{print $1}')

                if [[ -z "$KEY_ID" ]]; then
                    log_error "Invalid key number"
                    continue
                fi

                configure_git_signing "$KEY_ID"
                ;;
            2)
                echo
                read -p "Enter the number of the SSH key to show registration for: " key_num

                # Get the key ID from the numbered list
                KEY_ID=$(op item list | grep -i ssh | sed -n "${key_num}p" | awk '{print $1}')

                if [[ -z "$KEY_ID" ]]; then
                    log_error "Invalid key number"
                    continue
                fi

                show_registration_instructions "$KEY_ID"
                ;;
            3)
                test_commit_signing
                ;;
            4)
                echo
                log_info "Current Git signing configuration:"
                echo "gpg.format: $(git config gpg.format)"
                echo "user.signingkey: $(git config user.signingkey)"
                echo "commit.gpgsign: $(git config commit.gpgsign)"
                echo "gpg.ssh.program: $(git config gpg.ssh.program)"
                ;;
            5)
                log_info "Goodbye!"
                exit 0
                ;;
            *)
                log_error "Invalid choice. Please enter 1-5."
                ;;
        esac

        echo
        read -p "Press Enter to continue..."
    done
}

# Run main function
main "$@"