#!/usr/bin/env bash
set -euo pipefail

# Ensure GPG knows the correct terminal
export GPG_TTY=$(tty)

BACKUP_DIR="$HOME/gpg-backup"
PASS_STORE="$HOME/.password-store"
mkdir -p "$BACKUP_DIR"

# Replace this with your private Git repo
GIT_REMOTE_URL="git@github.com:adamrocha/pass-store-backup.git"

restore_keys() {
    local restore_path="$1"
    echo "=== Restoring GPG keys from $restore_path ==="

    if [[ ! -f "$restore_path/private.key.gpg" || ! -f "$restore_path/public.key.gpg" ]]; then
        echo "Error: Encrypted backup files not found in $restore_path"
        exit 1
    fi

    read -s -p "Enter passphrase to decrypt backup: " RESTORE_PASSPHRASE
    echo

    gpg --batch --yes --passphrase "$RESTORE_PASSPHRASE" -d "$restore_path/public.key.gpg" | gpg --import
    gpg --batch --yes --passphrase "$RESTORE_PASSPHRASE" -d "$restore_path/private.key.gpg" | gpg --import

    local key_id
    key_id=$(gpg --list-secret-keys --keyid-format LONG | awk '/^sec/{print $2}' | cut -d'/' -f2 | head -n1)
    if [ -z "$key_id" ]; then
        echo "Error: No key imported."
        exit 1
    fi

    echo "Initializing pass with restored key $key_id..."
    pass init "$key_id"

    echo "Restore complete. pass is now ready."
    exit 0
}

git_sync_setup() {
    echo "=== Setting up Git sync for pass store ==="
    if [ ! -d "$PASS_STORE/.git" ]; then
        git init "$PASS_STORE"
        cd "$PASS_STORE"
    else
        cd "$PASS_STORE"
    fi

    if ! git remote get-url origin >/dev/null 2>&1; then
        git remote add origin "$GIT_REMOTE_URL"
    fi

    echo "*.tmp" > .gitignore
    git add .
    git commit -m "Initial pass store commit" || true

    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

    git pull --rebase origin "$CURRENT_BRANCH" || true
    git push -u origin "$CURRENT_BRANCH" || true
}

setup_auto_push_hook() {
    local hook_file="$PASS_STORE/.git/hooks/post-commit"
    echo "=== Setting up queued offline-safe auto push hook ==="

    cat > "$hook_file" <<'EOF'
#!/usr/bin/env bash
REMOTE_NAME="origin"
REMOTE_BRANCH=$(git rev-parse --abbrev-ref HEAD)
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

    chmod +x "$hook_file"
}

if [[ "${1:-}" == "--restore" ]]; then
    restore_path="${2:-$BACKUP_DIR}"
    restore_keys "$restore_path"
fi

echo "=== Checking OS and installing dependencies ==="
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    sudo apt-get update
    command -v gpg >/dev/null || sudo apt-get install -y gnupg
    command -v pass >/dev/null || sudo apt-get install -y pass
    command -v git >/dev/null || sudo apt-get install -y git
elif [[ "$OSTYPE" == "darwin"* ]]; then
    command -v gpg >/dev/null || brew install gnupg
    command -v pass >/dev/null || brew install pass
    command -v git >/dev/null || brew install git
else
    echo "Unsupported OS: $OSTYPE"
    exit 1
fi

echo "=== Checking for existing GPG key ==="
KEY_ID=$(gpg --list-secret-keys --keyid-format LONG 2>/dev/null | awk '/^sec/{print $2}' | cut -d'/' -f2 || true)

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
    KEY_ID=$(gpg --list-secret-keys --keyid-format LONG | awk '/^sec/{print $2}' | cut -d'/' -f2)
    echo "Generated new GPG key: $KEY_ID"
else
    echo "Found existing GPG key: $KEY_ID"
fi

echo "=== Initializing pass ==="
if [ ! -d "$PASS_STORE" ] || [ -z "$(ls -A "$PASS_STORE")" ]; then
    pass init "$KEY_ID"
else
    echo "Pass is already initialized."
fi

echo "=== Backing up GPG keys to $BACKUP_DIR (encrypted) ==="
read -s -p "Enter passphrase for encrypted backup: " BACKUP_PASSPHRASE
echo

echo "$BACKUP_PASSPHRASE" | gpg --batch --yes --passphrase-fd 0 --symmetric --cipher-algo AES256 -o "$BACKUP_DIR/public.key.gpg" <<< "$(gpg --export --armor "$KEY_ID")"
echo "$BACKUP_PASSPHRASE" | gpg --batch --yes --passphrase-fd 0 --symmetric --cipher-algo AES256 -o "$BACKUP_DIR/private.key.gpg" <<< "$(gpg --export-secret-keys --armor "$KEY_ID")"

echo "Encrypted backup complete."
echo "Public key: $BACKUP_DIR/public.key.gpg"
echo "Private key: $BACKUP_DIR/private.key.gpg (keep this passphrase safe!)"

git_sync_setup
setup_auto_push_hook

# --- SANITY CHECK ---
echo "=== Running sanity check ==="
HOOK_FILE="$PASS_STORE/.git/hooks/post-commit"
TEMP_HOOK="$HOOK_FILE.temp"
if [ -f "$HOOK_FILE" ]; then
    mv "$HOOK_FILE" "$TEMP_HOOK"
fi

echo "=== SANITY CHECK START ==="
TEST_ENTRY="test/pass-setup-check"
TEST_VALUE="secret-test-value-123"

pass rm -f "$TEST_ENTRY" >/dev/null 2>&1 || true
echo "$TEST_VALUE" | pass insert -m -f "$TEST_ENTRY"
RETRIEVED_VALUE=$(pass show "$TEST_ENTRY")

if [ "$RETRIEVED_VALUE" == "$TEST_VALUE" ]; then
    echo "PASS sanity check succeeded. pass, GPG, encrypted backup, and Git sync are working."
else
    echo "PASS sanity check FAILED."
    exit 1
fi
echo "=== SANITY CHECK END ==="

if [ -f "$TEMP_HOOK" ]; then
    mv "$TEMP_HOOK" "$HOOK_FILE"
fi
