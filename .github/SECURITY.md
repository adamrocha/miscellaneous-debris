# Security Features in pass_setup_fresh.sh

## Modern Encryption Standards

This script has been updated to use state-of-the-art encryption and security practices:

### GPG Key Generation

- **Algorithm**: ECC (Elliptic Curve Cryptography)
- **Signing**: ed25519 (modern, fast, secure)
- **Encryption**: cv25519 (Curve25519 for ECDH)
- **Key Expiry**: 2 years (security best practice)

### Backup Encryption

- **Cipher**: AES-256 (Advanced Encryption Standard)
- **Digest**: SHA-512 (cryptographic hash)
- **S2K Mode**: 3 (iterated and salted)
- **S2K Digest**: SHA-512
- **S2K Iterations**: 65,011,712 (2^26, maximum security)

### Integrity Verification

- **Checksums**: SHA-512 for all backup files
- **Fingerprint Verification**: GPG key fingerprints validated on restore
- **Atomic Operations**: Ensures data consistency

### Git Security

- **Signed Commits**: All commits signed with GPG for authenticity
- **Automatic Push**: Background sync with retry logic
- **Connectivity Checks**: Multiple fallback methods

### Security Best Practices

- Passphrase confirmation for all sensitive operations
- GPG agent timeout (1 hour)
- No unprotected keys
- Proper error handling and validation
- Comprehensive logging for audit trails

## Why These Changes?

1. **ECC vs RSA**: Ed25519 provides equivalent security to RSA-4096 but with:
   - Faster key generation and signing
   - Smaller key sizes (256-bit vs 4096-bit)
   - Resistance to timing attacks
   - Better performance on modern hardware

2. **S2K Iterations**: Maximum iteration count makes brute-force attacks computationally infeasible

3. **SHA-512**: Provides better security margin than SHA-256 for future-proofing

4. **Integrity Checks**: Detects corruption or tampering of backups

5. **Key Expiry**: Forces periodic key rotation, a security best practice

## Automatic Updates

The repository now includes git hooks for automatic synchronization:

- **post-commit**: Automatically pushes commits to GitHub when online
- **pre-push**: Syncs latest changes before pushing to avoid conflicts

These hooks mirror the functionality built into the script itself for the password store.

## Usage

```bash
# Backup GPG keys with modern encryption
./pass_setup_fresh.sh --backup-keys

# Restore keys with integrity verification
./pass_setup_fresh.sh --restore-keys

# Setup automatic git sync for password store
./pass_setup_fresh.sh --setup

# Manual backup of password store
./pass_setup_fresh.sh --backup-repo

# Restore password store from remote
./pass_setup_fresh.sh --restore-repo

# Check GPG compatibility
./pass_setup_fresh.sh --check-version
```

## Requirements

- GPG 2.1.0 or higher (for ECC support)
- Git (for repository management)
- Bash 4.0+ (for modern shell features)

## Migration from Old Keys

If you have existing RSA keys, the script will continue to use them. To migrate:

1. Export your existing password store
2. Backup with `--backup-keys` using old key
3. Generate new ECC key manually or remove old key and run script
4. Import password store and re-encrypt with new key

---

Last updated: April 1, 2026
