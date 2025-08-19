#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR=${BACKUP_DIR:-"$HOME/gpg-backup"}
PASS_STORE="$HOME/.password-store"
GIT_REMOTE_URL="git@github.com:adamrocha/pass-store-backup.git"
BRANCH="main"

mkdir -p "$BACKUP_DIR"

# === Backup GPG keys ===
backup_keys() {
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

    gpg --export --armor "$KEY_ID" \
        | gpg --batch --yes --passphrase "$BACKUP_PASSPHRASE" \
          -c --cipher-algo AES256 -o "$BACKUP_DIR/public.key.gpg"

    gpg --export-secret-keys --armor "$KEY_ID" \
        | gpg --batch --yes --passphrase "$BACKUP_PASSPHRASE" \
          -c --cipher-algo AES256 -o "$BACKUP_DIR/private.key.gpg"

    gpg --list-secret-keys --with-colons "$KEY_ID" \
        | grep '^fpr' | head -n1 | cut -d: -f10 > "$BACKUP_DIR/fingerprint.txt"

    echo "Backup complete. Fingerprint saved in $BACKUP_DIR/fingerprint.txt"
}

# === Restore GPG keys ===
restore_keys() {
    echo "=== Restoring GPG keys from $BACKUP_DIR ==="
    read -s -p "Enter passphrase to decrypt backup: " BACKUP_PASSPHRASE
    echo

    gpg --batch --yes --passphrase "$BACKUP_PASSPHRASE" \
        --decrypt "$BACKUP_DIR/public.key.gpg" | gpg --import

    gpg --batch --yes --passphrase "$BACKUP_PASSPHRASE" \
        --decrypt "$BACKUP_DIR/private.key.gpg" | gpg --import

    RESTORED_FP=$(gpg --list-secret-keys --with-colons \
        | grep '^fpr' | head -n1 | cut -d: -f10)

    if [[ -f "$BACKUP_DIR/fingerprint.txt" ]]; then
        BACKUP_FP=$(cat "$BACKUP_DIR/fingerprint.txt")
        if [[ "$RESTORED_FP" == "$BACKUP_FP" ]]; then
            echo "Integrity check passed: fingerprint matches ($RESTORED_FP)"
        else
            echo "WARNING: Fingerprint mismatch!"
        fi
    fi

    KEY_ID=$(gpg --list-secret-keys --keyid-format LONG \
        | awk '/^sec/{print $2}' | cut -d'/' -f2 | head -n1)
    pass init "$KEY_ID"
    echo "GPG key restore complete."
}

# === Git repo backup/restore ===
setup_repo() {
    if [ ! -d "$PASS_STORE/.git" ]; then
        git init "$PASS_STORE"
        cd "$PASS_STORE"
        git remote add origin "$GIT_REMOTE_URL"
        git checkout -b "$BRANCH"
        git add .
        git commit -m "Initial commit" || true
        git push -u origin "$BRANCH"
    else
        cd "$PASS_STORE"
        git checkout "$BRANCH" || git checkout -b "$BRANCH"
    fi
}

auto_push_hook() {
    HOOK_FILE="$PASS_STORE/.git/hooks/post-commit"
    cat > "$HOOK_FILE" <<'EOF'
#!/usr/bin/env bash
REMOTE_NAME="origin"
REMOTE_BRANCH="main"
QUEUE_FILE="$(dirname "$0")/.push-queue"

echo "$(date '+%Y-%m-%d %H:%M:%S') commit" >> "$QUEUE_FILE"

attempt_push() {
    if ping -c 1 -W 1 8.8.8.8 >/dev/null 2>&1; then
        echo "[pass auto-push] Online — pushing queued commits..."
        git push "$REMOTE_NAME" "HEAD:$REMOTE_BRANCH" && > "$QUEUE_FILE"
    else
        echo "[pass auto-push] Offline — queued push will retry later."
    fi
}

attempt_push
EOF
    chmod +x "$HOOK_FILE"
}

# === Main ===
case "${1:-}" in
    --backup-keys) backup_keys ;;
    --restore-keys) restore_keys ;;
    --backup-repo) setup_repo; git add .; git commit -m "Backup on $(date)" || true; git push origin "$BRANCH" ;;
    --restore-repo) rm -rf "$PASS_STORE"; git clone -b "$BRANCH" "$GIT_REMOTE_URL" "$PASS_STORE" ;;
    *) echo "Usage: $0 [--backup-keys | --restore-keys | --backup-repo | --restore-repo]"; exit 1 ;;
esac

# Setup auto-push hook for automatic updates
setup_repo
auto_push_hook
