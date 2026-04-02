#!/usr/bin/env bash
set -euo pipefail

# Modern encryption configuration
readonly BACKUP_DIR="${BACKUP_DIR:-${HOME}/gpg-backup}"
readonly PASS_STORE="${HOME}/.password-store"
readonly GIT_REMOTE_URL="git@github.com:adamrocha/pass-store-backup.git"
readonly BRANCH="main"
readonly GPG_TIMEOUT=3600 # 1 hour cache timeout
readonly CIPHER_ALGO="AES256"
readonly DIGEST_ALGO="SHA512"
readonly S2K_MODE="3"         # Iterated and salted
readonly S2K_DIGEST="SHA512"  # Modern digest for key derivation
readonly S2K_COUNT="65011712" # Maximum iteration count (2^26)

mkdir -p "${BACKUP_DIR}"

# === Enhanced error handling ===
error_exit() {
	echo "ERROR: $1" >&2
	exit 1
}

# === Verify GPG version supports modern algorithms ===
check_gpg_version() {
	local gpg_version
	gpg_version=$(gpg --version | head -n1 | awk '{print $3}')
	local required_version="2.1.0"

	if ! printf '%s\n%s\n' "${required_version}" "${gpg_version}" | sort -V -C; then
		error_exit "GPG version ${gpg_version} is too old. Minimum required: ${required_version}"
	fi
	echo "GPG version ${gpg_version} verified"
}

# === Configure GPG agent for security ===
configure_gpg_agent() {
	local agent_conf="${HOME}/.gnupg/gpg-agent.conf"
	mkdir -p "${HOME}/.gnupg"
	chmod 700 "${HOME}/.gnupg"

	# Modern agent configuration
	# Prefer pinentry-mac on macOS for better GUI experience and avoid terminal display issues
	cat >"${agent_conf}" <<EOF
# Modern GPG agent configuration
default-cache-ttl ${GPG_TIMEOUT}
max-cache-ttl ${GPG_TIMEOUT}
pinentry-program $(which pinentry-mac || which pinentry-tty || which pinentry || echo /usr/bin/pinentry)
EOF
	chmod 600 "${agent_conf}"
	gpgconf --kill gpg-agent 2>/dev/null || true
	gpgconf --launch gpg-agent
}

# === Set ultimate trust on a GPG key ===
set_key_trust() {
	local key_fingerprint="$1"
	echo "Setting ultimate trust on key ${key_fingerprint}..."
	
	# Set trust level to 5 (ultimate)
	echo -e "trust\n5\ny\nquit" | gpg --command-fd 0 --edit-key "${key_fingerprint}" 2>/dev/null || true
	
	# Verify trust was set
	local trust_level
	trust_level=$(gpg --list-keys --with-colons "${key_fingerprint}" 2>/dev/null | awk -F: '/^uid/{print $2}' | head -n1)
	
	if [[ "${trust_level}" == "u" ]]; then
		echo "✓ Key trusted successfully"
		return 0
	else
		echo "WARNING: Could not verify trust level was set"
		return 1
	fi
}

# === Backup GPG keys with modern encryption ===
backup_keys() {
	echo "=== Checking for existing GPG key ==="
	local key_id
	key_id=$(gpg --list-secret-keys --keyid-format LONG 2>/dev/null |
		awk '/^sec/{print $2}' | cut -d'/' -f2 | head -n1 || true)

	if [[ -z ${key_id} ]]; then
		echo "No GPG key found. Generating a new one with modern ECC (ed25519)..."

		# Read user information
		read -r -p "Enter your name: " user_name
		read -r -p "Enter your email: " user_email
		read -r -s -p "Enter passphrase for GPG key: " key_passphrase
		echo
		read -r -s -p "Confirm passphrase: " key_passphrase_confirm
		echo

		if [[ ${key_passphrase} != "${key_passphrase_confirm}" ]]; then
			error_exit "Passphrases do not match"
		fi

		# Generate modern ECC key (ed25519 for signing, cv25519 for encryption)
		cat <<EOF | gpg --batch --generate-key
%echo Generating modern ECC key pair
Key-Type: eddsa
Key-Curve: ed25519
Key-Usage: sign
Subkey-Type: ecdh
Subkey-Curve: cv25519
Subkey-Usage: encrypt
Name-Real: ${user_name}
Name-Email: ${user_email}
Expire-Date: 2y
Passphrase: ${key_passphrase}
%commit
%echo Key generation complete
EOF
		key_id=$(gpg --list-secret-keys --keyid-format LONG |
			awk '/^sec/{print $2}' | cut -d'/' -f2 | head -n1)
		echo "Generated new GPG key: ${key_id}"
		
		# Get fingerprint and set ultimate trust
		local key_fp
		key_fp=$(gpg --list-secret-keys --with-colons "${key_id}" |
			grep '^fpr' | head -n1 | cut -d: -f10)
		set_key_trust "${key_fp}"
	else
		echo "Found existing GPG key: ${key_id}"
		
		# Ensure existing key is trusted
		local key_fp
		key_fp=$(gpg --list-secret-keys --with-colons "${key_id}" |
			grep '^fpr' | head -n1 | cut -d: -f10)
		local current_trust
		current_trust=$(gpg --list-keys --with-colons "${key_fp}" 2>/dev/null | awk -F: '/^uid/{print $2}' | head -n1)
		
		if [[ "${current_trust}" != "u" ]]; then
			echo "Key is not fully trusted. Setting ultimate trust..."
			set_key_trust "${key_fp}"
		else
			echo "✓ Key is already fully trusted"
		fi
	fi

	echo "=== Backing up GPG keys to ${BACKUP_DIR} (encrypted) ==="
	read -r -s -p "Enter passphrase for encrypted backup: " backup_passphrase
	echo
	read -r -s -p "Confirm passphrase: " backup_passphrase_confirm
	echo

	if [[ ${backup_passphrase} != "${backup_passphrase_confirm}" ]]; then
		error_exit "Passphrases do not match"
	fi

	# Export with modern encryption settings
	gpg --export --armor "${key_id}" |
		gpg --batch --yes --passphrase "${backup_passphrase}" \
			--s2k-mode "${S2K_MODE}" \
			--s2k-digest-algo "${S2K_DIGEST}" \
			--s2k-count "${S2K_COUNT}" \
			--cipher-algo "${CIPHER_ALGO}" \
			--digest-algo "${DIGEST_ALGO}" \
			-c -o "${BACKUP_DIR}/public.key.gpg"

	gpg --export-secret-keys --armor "${key_id}" |
		gpg --batch --yes --passphrase "${backup_passphrase}" \
			--s2k-mode "${S2K_MODE}" \
			--s2k-digest-algo "${S2K_DIGEST}" \
			--s2k-count "${S2K_COUNT}" \
			--cipher-algo "${CIPHER_ALGO}" \
			--digest-algo "${DIGEST_ALGO}" \
			-c -o "${BACKUP_DIR}/private.key.gpg"

	# Save metadata with integrity checks
	gpg --list-secret-keys --with-colons "${key_id}" |
		grep '^fpr' | head -n1 | cut -d: -f10 >"${BACKUP_DIR}/fingerprint.txt"

	# Generate checksums for integrity verification
	(cd "${BACKUP_DIR}" && shasum -a 512 public.key.gpg private.key.gpg >checksums.sha512)

	echo "Backup complete. Fingerprint saved in ${BACKUP_DIR}/fingerprint.txt"
	echo "Integrity checksums saved in ${BACKUP_DIR}/checksums.sha512"
}

# === Restore GPG keys with integrity verification ===
restore_keys() {
	echo "=== Restoring GPG keys from ${BACKUP_DIR} ==="

	# Verify backup files exist
	[[ -f "${BACKUP_DIR}/public.key.gpg" ]] || error_exit "Public key backup not found"
	[[ -f "${BACKUP_DIR}/private.key.gpg" ]] || error_exit "Private key backup not found"
	[[ -f "${BACKUP_DIR}/fingerprint.txt" ]] || error_exit "Fingerprint file not found"

	# Verify checksums if available
	if [[ -f "${BACKUP_DIR}/checksums.sha512" ]]; then
		echo "Verifying backup integrity..."
		if ! (cd "${BACKUP_DIR}" && shasum -a 512 -c checksums.sha512 --quiet 2>/dev/null); then
			error_exit "Checksum verification failed! Backup may be corrupted."
		fi
		echo "✓ Integrity verification passed"
	else
		echo "WARNING: No checksums found, skipping integrity check"
	fi

	read -r -s -p "Enter passphrase to decrypt backup: " backup_passphrase
	echo

	# Import public key
	if ! gpg --batch --yes --passphrase "${backup_passphrase}" \
		--decrypt "${BACKUP_DIR}/public.key.gpg" | gpg --import 2>/dev/null; then
		error_exit "Failed to decrypt/import public key. Wrong passphrase?"
	fi

	# Import private key
	if ! gpg --batch --yes --passphrase "${backup_passphrase}" \
		--decrypt "${BACKUP_DIR}/private.key.gpg" | gpg --import 2>/dev/null; then
		error_exit "Failed to decrypt/import private key. Wrong passphrase?"
	fi

	# Verify fingerprint
	local restored_fp
	restored_fp=$(gpg --list-secret-keys --with-colons |
		grep '^fpr' | head -n1 | cut -d: -f10)

	local backup_fp
	backup_fp=$(cat "${BACKUP_DIR}/fingerprint.txt")

	if [[ ${restored_fp} == "${backup_fp}" ]]; then
		echo "✓ Integrity check passed: fingerprint matches (${restored_fp})"
	else
		error_exit "Fingerprint mismatch! Expected: ${backup_fp}, Got: ${restored_fp}"
	fi

	# Set ultimate trust on restored key
	echo "Setting trust on restored key..."
	set_key_trust "${restored_fp}"
	
	# Initialize pass with restored key
	local key_id
	key_id=$(gpg --list-secret-keys --keyid-format LONG |
		awk '/^sec/{print $2}' | cut -d'/' -f2 | head -n1)

	pass init "${key_id}"
	echo "GPG key restore complete. Key ID: ${key_id}"
}

# === Enhanced network connectivity check ===
check_connectivity() {
	# Try multiple methods for better reliability
	if timeout 2 bash -c "cat < /dev/null > /dev/tcp/8.8.8.8/53" 2>/dev/null; then
		return 0
	elif timeout 2 bash -c "cat < /dev/null > /dev/tcp/1.1.1.1/53" 2>/dev/null; then
		return 0
	elif command -v nc &>/dev/null && nc -z -w2 8.8.8.8 53 2>/dev/null; then
		return 0
	elif ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
		return 0
	else
		return 1
	fi
}

# === Git repository backup/restore with signed commits ===
setup_repo() {
	if [[ ! -d "${PASS_STORE}/.git" ]]; then
		echo "Initializing new git repository..."
		git init "${PASS_STORE}"
		cd "${PASS_STORE}" || error_exit "Failed to cd to ${PASS_STORE}"

		# Configure git for signed commits
		local key_id
		key_id=$(gpg --list-secret-keys --keyid-format LONG |
			awk '/^sec/{print $2}' | cut -d'/' -f2 | head -n1)

		if [[ -n ${key_id} ]]; then
			git config user.signingkey "${key_id}"
			git config commit.gpgsign true
			echo "Configured GPG signing with key: ${key_id}"
		fi

		git remote add origin "${GIT_REMOTE_URL}" || true

		# Create initial commit if files exist
		if [[ -n "$(ls -A .)" ]]; then
			git add .
			git commit -m "Initial commit - $(date -u +"%Y-%m-%d %H:%M:%S UTC")" || true
		fi

		# Try to push, but don't fail if remote doesn't exist yet
		git branch -M "${BRANCH}"
		if check_connectivity; then
			git push -u origin "${BRANCH}" 2>/dev/null || echo "Remote push failed (repo may not exist yet)"
		else
			echo "No network connectivity. Skipping initial push."
		fi
	else
		echo "Git repository already exists"
		cd "${PASS_STORE}" || error_exit "Failed to cd to ${PASS_STORE}"
		git checkout "${BRANCH}" 2>/dev/null || git checkout -b "${BRANCH}"

		# Ensure GPG signing is enabled
		local key_id
		key_id=$(gpg --list-secret-keys --keyid-format LONG |
			awk '/^sec/{print $2}' | cut -d'/' -f2 | head -n1)

		if [[ -n ${key_id} ]]; then
			git config user.signingkey "${key_id}"
			git config commit.gpgsign true
		fi
	fi
}

# === Auto-push hook with enhanced retry logic ===
auto_push_hook() {
	local hook_file="${PASS_STORE}/.git/hooks/post-commit"
	mkdir -p "${PASS_STORE}/.git/hooks"

	cat >"${hook_file}" <<'EOFHOOK'
#!/usr/bin/env bash
set -euo pipefail

readonly REMOTE_NAME="origin"
readonly REMOTE_BRANCH="main"
readonly QUEUE_FILE="$(dirname "${0}")/.push-queue"
readonly LOG_FILE="$(dirname "${0}")/.push-log"

# Log commit
echo "$(date -u '+%Y-%m-%d %H:%M:%S UTC') - commit $(git rev-parse --short HEAD)" >> "${QUEUE_FILE}"

# Enhanced connectivity check
check_connectivity() {
    if timeout 2 bash -c "cat < /dev/null > /dev/tcp/8.8.8.8/53" 2>/dev/null; then
        return 0
    elif timeout 2 bash -c "cat < /dev/null > /dev/tcp/1.1.1.1/53" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Attempt push with retry logic
attempt_push() {
    local max_retries=3
    local retry=0
    
    if ! check_connectivity; then
        echo "$(date -u '+%Y-%m-%d %H:%M:%S UTC') - Offline, queued for later" >> "${LOG_FILE}"
        echo "[pass auto-push] Offline — queued push will retry later."
        return 1
    fi
    
    while [[ ${retry} -lt ${max_retries} ]]; do
        if git push "${REMOTE_NAME}" "HEAD:${REMOTE_BRANCH}" 2>&1 | tee -a "${LOG_FILE}"; then
            echo "$(date -u '+%Y-%m-%d %H:%M:%S UTC') - Push successful" >> "${LOG_FILE}"
            > "${QUEUE_FILE}"  # Clear queue on success
            echo "[pass auto-push] ✓ Successfully pushed to ${REMOTE_NAME}/${REMOTE_BRANCH}"
            return 0
        else
            retry=$((retry + 1))
            if [[ ${retry} -lt ${max_retries} ]]; then
                echo "[pass auto-push] Push failed, retrying (${retry}/${max_retries})..."
                sleep 2
            fi
        fi
    done
    
    echo "$(date -u '+%Y-%m-%d %H:%M:%S UTC') - Push failed after ${max_retries} retries" >> "${LOG_FILE}"
    echo "[pass auto-push] Failed after ${max_retries} retries. Will try again on next commit."
    return 1
}

attempt_push &
EOFHOOK
	chmod +x "${hook_file}"
	echo "Auto-push hook installed at ${hook_file}"
}

# === Manual backup with timestamp ===
manual_backup() {
	setup_repo
	cd "${PASS_STORE}" || error_exit "Failed to cd to ${PASS_STORE}"

	if [[ -n "$(git status --porcelain)" ]]; then
		git add .
		git commit -m "Manual backup - $(date -u '+%Y-%m-%d %H:%M:%S UTC')" || true

		if check_connectivity; then
			git push origin "${BRANCH}" && echo "✓ Backup pushed to remote"
		else
			echo "No network connectivity. Backup committed locally."
		fi
	else
		echo "No changes to backup"
	fi
}

# === Restore repository from remote ===
restore_repo() {
	if [[ -d ${PASS_STORE} ]]; then
		read -r -p "Password store exists. Remove and restore from remote? [y/N]: " confirm
		if [[ ! ${confirm} =~ ^[Yy]$ ]]; then
			echo "Aborted."
			return 1
		fi
		rm -rf "${PASS_STORE}"
	fi

	if ! check_connectivity; then
		error_exit "No network connectivity. Cannot restore from remote."
	fi

	git clone -b "${BRANCH}" "${GIT_REMOTE_URL}" "${PASS_STORE}" ||
		error_exit "Failed to clone repository"

	echo "✓ Repository restored from ${GIT_REMOTE_URL}"
}

# === Display usage information ===
usage() {
	cat <<EOF
Usage: ${0} [OPTION]

Modern password store management with enhanced security and encryption.

Options:
    --backup-keys       Backup GPG keys with modern encryption (ed25519/cv25519)
    --restore-keys      Restore GPG keys with integrity verification
    --backup-repo       Manually backup password store to git
    --restore-repo      Restore password store from remote git repository
    --setup             Full setup: repo initialization and auto-push hooks
    --check-version     Check GPG version compatibility
    --help              Display this help message

Encryption details:
  - Key type: ECC (ed25519 for signing, cv25519 for encryption)
  - Backup encryption: AES256 with SHA512 digest
  - Key derivation: S2K mode 3 (iterated and salted) with 2^26 iterations
  - Commits: GPG signed for authenticity

Environment variables:
  BACKUP_DIR          Backup directory (default: ~/gpg-backup)

Examples:
  ${0} --backup-keys     # Backup GPG keys
  ${0} --setup           # Setup git repo with auto-push
  ${0} --backup-repo     # Manual backup to git

EOF
}

# === Main execution ===
main() {
	# Check GPG version before any operations
	check_gpg_version
	configure_gpg_agent

	case "${1-}" in
	--backup-keys)
		backup_keys
		;;
	--restore-keys)
		restore_keys
		;;
	--backup-repo)
		manual_backup
		;;
	--restore-repo)
		restore_repo
		;;
	--setup)
		setup_repo
		auto_push_hook
		echo "✓ Setup complete. Auto-push enabled."
		;;
	--check-version)
		check_gpg_version
		echo "✓ GPG version is compatible"
		;;
	--help | -h)
		usage
		exit 0
		;;
	*)
		echo "ERROR: Invalid option: ${1:-none}"
		echo
		usage
		exit 1
		;;
	esac
}

# Run main with all arguments
main "$@"
