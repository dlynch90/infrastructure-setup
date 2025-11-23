# SSH Git Commit Signing Registration Guide

## ✅ Setup Complete!

SSH Git commit signing has been successfully configured with 1Password. Your commits will now be cryptographically signed and can be verified on Git hosting platforms.

## 🔑 Your SSH Public Key

```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO98KydUvAxpVyFarpLvx/a4mvLxyHbBU9+6HemBvrri
```

## 📋 Platform Registration Instructions

### GitHub
1. Go to: https://github.com/settings/keys
2. Click "New SSH key"
3. **Title**: "SSH Commit Signing Key"
4. **Key type**: Select "Signing key"
5. **Paste the public key above**
6. Click "Add SSH key"

### GitLab
1. Go to: https://gitlab.com/-/profile/keys
2. **Title**: "SSH Commit Signing Key"
3. **Usage type**: Select "Signing"
4. **Paste the public key above**
5. Click "Add key"

### Bitbucket
1. Go to: https://bitbucket.org/account/settings/ssh-keys/
2. Click "Add key"
3. **Label**: "SSH Commit Signing Key"
4. **Paste the public key above**
5. Click "Add key"

## 🧪 Test Your Setup

1. **Create a test commit**:
   ```bash
   git commit -m "Test SSH commit signing"
   ```

2. **Push to your repository**:
   ```bash
   git push origin main
   ```

3. **Verify on your Git platform**: Look for the "Verified" badge on your commits.

## ⚙️ Current Configuration

```bash
Git SSH signing configuration:
gpg.format: ssh
user.signingkey: ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO98KydUvAxpVyFarpLvx/a4mvLxyHbBU9+6HemBvrri
commit.gpgsign: true
gpg.ssh.program: /Applications/1Password.app/Contents/MacOS/op-ssh-sign
```

## 🔒 Security Benefits

- **Cryptographic verification**: Commits are signed with your SSH private key
- **Biometric protection**: 1Password requires Touch ID/Face ID for key access
- **No key exposure**: Private key never leaves 1Password
- **Audit trail**: All key usage is logged in 1Password
- **Platform verification**: GitHub, GitLab, and Bitbucket show "Verified" badges

## 🚨 Important Notes

- SSH keys must be stored in Personal, Private, or Employee vaults for 1Password SSH agent access
- The signing key is different from your SSH access keys (server login)
- Commits will only show as "Verified" on platforms where you've registered the public key
- Local signature verification requires additional `allowedSignersFile` configuration (optional)

## 🛠️ Troubleshooting

If commits don't show as verified:
1. Ensure the public key is registered on your Git platform
2. Check that the commit author email matches your Git platform account
3. Verify the key is in an accessible vault (Personal/Private/Employee)
4. Try `git config --global --unset gpg.ssh.allowedSignersFile` if you see local verification errors

## 📞 Support

- 1Password SSH documentation: https://developer.1password.com/docs/ssh/
- Git SSH signing docs: https://git-scm.com/docs/git-config#gpgsshprogram