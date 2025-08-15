#!/usr/bin/env bash
set -euo pipefail

# CONFIG
PASS_DIR="$HOME/.password-store"
GPG_BACKUP_DIR="$HOME/gpg-backup"
REPO_URL="git@github.com:youruser/pass-store-backup.git"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Detecting OS ==="
OS="$(uname -s)"
case "$OS" in
    Linux)
        PACKAGE_INSTALL="sudo apt-get update && sudo apt-get install -y pass gnupg git || sudo dnf install -y pass gnupg git"
        ;;
    Darwin)
        PACKAGE_INSTALL="brew install pass gnupg git"
        ;;
    *)
        echo "Unsupported OS: $OS"
        exit 1
        ;;
esac

echo "=== Installing dependencies ==="
eval "$PACKAGE_INSTALL"

# Determine if this is a fresh recovery or first-time setup
if [ ! -d "$PASS_DIR" ] || [ -z "$(ls -A "$PASS_DIR" 2>/dev/null)" ]; then
    MODE="RECOVERY"
else
    MODE="SETUP"
fi

echo "=== Mode detected: $MODE ==="

if [ "$MODE" = "SETUP" ]; then
    echo "=== Checking for existing GPG key ==="
    GPG_KEY_ID=$(gpg --list-secret-keys --keyid-format LONG 2>/dev/null | grep sec | awk '{print $2}' | cut -d/ -f2 | head -n1 || true)
    if [ -z "$GPG_KEY_ID" ]; then
        echo "No GPG key found. Generating..."
        gpg --batch --generate-key <<EOF
Key-Type: RSA
Key-Length: 4096
Name-Real: PassStore
Expire-Date: 0
%commit
EOF
        GPG_KEY_ID=$(gpg --list-secret-keys --keyid-format LONG | grep sec | awk '{print $2}' | cut -d/ -f2 | head -n1)
    fi
    echo "Found GPG key: $GPG_KEY_ID"

    echo "=== Initializing pass ==="
    if [ ! -d "$PASS_DIR" ]; then
        pass init "$GPG_KEY_ID"
    else
        echo "Pass is already initialized."
    fi

    echo "=== Backing up GPG keys locally ==="
    mkdir -p "$GPG_BACKUP_DIR"
    read -sp "Enter passphrase for local encrypted backup: " BACKUP_PASS
    echo
    gpg --export "$GPG_KEY_ID" | gpg --symmetric --cipher-algo AES256 --passphrase "$BACKUP_PASS" -o "$GPG_BACKUP_DIR/public.key.gpg"
    gpg --export-secret-keys "$GPG_KEY_ID" | gpg --symmetric --cipher-algo AES256 --passphrase "$BACKUP_PASS" -o "$GPG_BACKUP_DIR/private.key.gpg"
    unset BACKUP_PASS
    echo "Local backup complete."

    echo "=== Backing up encrypted GPG keys into repo ==="
    read -sp "Enter recovery passphrase (store safely OFF this machine): " RECOVERY_PASS
    echo
    cd "$PASS_DIR"
    gpg --export "$GPG_KEY_ID" | gpg --symmetric --cipher-algo AES256 --passphrase "$RECOVERY_PASS" -o gpg-public.key.gpg
    gpg --export-secret-keys "$GPG_KEY_ID" | gpg --symmetric --cipher-algo AES256 --passphrase "$RECOVERY_PASS" -o gpg-private.key.gpg
    git init || true
    git remote add origin "$REPO_URL" 2>/dev/null || true
    git add -A
    git commit -m "Initial pass store commit with encrypted GPG keys" || true
    git push -u origin main || true
    unset RECOVERY_PASS

elif [ "$MODE" = "RECOVERY" ]; then
    echo "=== Performing recovery ==="
    git clone "$REPO_URL" "$PASS_DIR"
    cd "$PASS_DIR"
    read -sp "Enter recovery passphrase: " RECOVERY_PASS
    echo
    gpg --decrypt --passphrase "$RECOVERY_PASS" gpg-public.key.gpg | gpg --import
    gpg --decrypt --passphrase "$RECOVERY_PASS" gpg-private.key.gpg | gpg --import
    unset RECOVERY_PASS
    GPG_KEY_ID=$(gpg --list-secret-keys --keyid-format LONG | grep sec | awk '{print $2}' | cut -d/ -f2 | head -n1)
    pass init "$GPG_KEY_ID"
fi

# --- Auto-push setup ---
echo "=== Creating pass-auto-push.sh ==="
cat > "$SCRIPT_DIR/pass-auto-push.sh" <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
PASS_DIR="$HOME/.password-store"
cd "$PASS_DIR"
if ! git diff --quiet || ! git diff --cached --quiet; then
    git add .
    git commit -m "[pass auto-push] $(date -u +"%Y-%m-%d %H:%M:%S UTC")" || true
fi
git push origin main || true
EOS
chmod +x "$SCRIPT_DIR/pass-auto-push.sh"

echo "=== Installing offline-safe auto-push ==="
if command -v systemctl >/dev/null 2>&1 && systemctl --user >/dev/null 2>&1; then
    mkdir -p "$HOME/.config/systemd/user"
    cat > "$HOME/.config/systemd/user/pass-auto-push.service" <<EOF
[Unit]
Description=Pass auto push
[Service]
Type=oneshot
ExecStart=$SCRIPT_DIR/pass-auto-push.sh
EOF
    cat > "$HOME/.config/systemd/user/pass-auto-push.timer" <<EOF
[Unit]
Description=Run pass auto push every minute
[Timer]
OnBootSec=1min
OnUnitActiveSec=1min
Unit=pass-auto-push.service
[Install]
WantedBy=default.target
EOF
    systemctl --user enable --now pass-auto-push.timer
elif [ "$(uname -s)" = "Darwin" ]; then
    mkdir -p "$HOME/Library/LaunchAgents"
    cat > "$HOME/Library/LaunchAgents/com.pass.auto-push.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN"
"http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.pass.auto-push</string>
    <key>ProgramArguments</key>
    <array>
        <string>$SCRIPT_DIR/pass-auto-push.sh</string>
    </array>
    <key>StartInterval</key>
    <integer>60</integer>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF
    launchctl unload "$HOME/Library/LaunchAgents/com.pass.auto-push.plist" 2>/dev/null || true
    launchctl load "$HOME/Library/LaunchAgents/com.pass.auto-push.plist"
fi

echo "=== Running sanity check ==="
TEST_PATH="test/pass-setup-check"
echo "TestEntry" | pass insert -m "$TEST_PATH"
if pass show "$TEST_PATH" | grep -q "TestEntry"; then
    echo "SANITY CHECK PASSED: Pass is working."
    pass rm -f "$TEST_PATH"
else
    echo "SANITY CHECK FAILED."
fi

echo "=== PASS SETUP & RECOVERY COMPLETE ==="
