#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR=${BACKUP_DIR:-"$HOME/gpg-backup"}

usage() {
    echo "Usage: $0 [--backup-keys | --restore-keys | --backup-repo | --restore-repo]"
    exit 1
}

# === Backup GPG keys ===
backup_keys() {
    mkdir -p "$BACKUP_DIR"

    echo "=== Checking for existing GPG key ==="
    KEY_ID=$(gpg --list-secret-keys --keyid-format LONG 2>/dev/null \
        | awk '/^sec/{print $2}' | cut -d'/' -f2 || true)

    if [ -z "$KEY_ID" ]; then
        echo "No GPG key found. Generating a new one..."
        cat <<EOF | gpg --batch --generate-key
Key-Type: RSA
Key-Length: 4096
Name-Real: Pass Key
Expire-Date: 0
%no-protection
%commit
EOF
        KEY_ID=$(gpg --list-secret-keys --keyid-format LONG \
            | awk '/^sec/{print $2}' | cut -d'/' -f2)
        echo "Generated new GPG key: $KEY_ID"
    else
        echo "Found existing GPG key: $KEY_ID"
    fi

    echo "=== Backing up GPG keys to $BACKUP_DIR (encrypted) ==="
    read -s -p "Enter passphrase for encrypted backup: " BACKUP_PASSPHRASE
    echo

    # Export keys and encrypt them
    gpg --export --armor "$KEY_ID" \
        | gpg --batch --yes --passphrase "$BACKUP_PASSPHRASE" \
          -c --cipher-algo AES256 -o "$BACKUP_DIR/public.key.gpg"

    gpg --export-secret-keys --armor "$KEY_ID" \
        | gpg --batch --yes --passphrase "$BACKUP_PASSPHRASE" \
          -c --cipher-algo AES256 -o "$BACKUP_DIR/private.key.gpg"

    # Save fingerprint for integrity checks
    gpg --list-secret-keys --with-colons "$KEY_ID" \
        | grep '^fpr' | head -n1 | cut -d: -f10 > "$BACKUP_DIR/fingerprint.txt"

    echo "Backup complete. Fingerprint saved in $BACKUP_DIR/fingerprint.txt"
}

# === Restore GPG keys ===
restore_keys() {
    echo "=== Restoring GPG keys from $BACKUP_DIR ==="
    read -s -p "Enter passphrase to decrypt backup: " BACKUP_PASSPHRASE
    echo

    # Decrypt and import public key
    gpg --batch --yes --passphrase "$BACKUP_PASSPHRASE" \
        --decrypt "$BACKUP_DIR/public.key.gpg" | gpg --import

    # Decrypt and import private key
    gpg --batch --yes --passphrase "$BACKUP_PASSPHRASE" \
        --decrypt "$BACKUP_DIR/private.key.gpg" | gpg --import

    echo "=== Checking key integrity ==="
    RESTORED_FP=$(gpg --list-secret-keys --with-colons \
        | grep '^fpr' | head -n1 | cut -d: -f10)

    if [[ -f "$BACKUP_DIR/fingerprint.txt" ]]; then
        BACKUP_FP=$(cat "$BACKUP_DIR/fingerprint.txt")
        if [[ "$RESTORED_FP" == "$BACKUP_FP" ]]; then
            echo "Integrity check passed: fingerprint matches ($RESTORED_FP)"
        else
            echo "WARNING: Fingerprint mismatch!"
            echo "  Backup:   $BACKUP_FP"
            echo "  Restored: $RESTORED_FP"
        fi
    else
        echo "No fingerprint file found in backup, skipping integrity check."
    fi

    echo "=== GPG key restore complete ==="
}

# === Backup password-store repo ===
backup_repo() {
    echo "=== Backing up pass repo ==="
    cd "$HOME/.password-store"
    git add .
    git commit -m "Automated backup on $(date)" || true
    git push origin master
    echo "Password-store repo pushed to remote."
}

# === Restore password-store repo ===
restore_repo() {
    echo "=== Restoring pass store from Git repo ==="
    rm -rf "$HOME/.password-store"
    git clone <your-pass-git-remote-url> "$HOME/.password-store"
    echo "Password-store restored."
}

# === Main ===
if [[ $# -ne 1 ]]; then
    usage
fi

case "$1" in
    --backup-keys) backup_keys ;;
    --restore-keys) restore_keys ;;
    --backup-repo) backup_repo ;;
    --restore-repo) restore_repo ;;
    *) usage ;;
esac
