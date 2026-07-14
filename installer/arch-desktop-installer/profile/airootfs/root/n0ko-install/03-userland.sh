#!/bin/bash
set -euo pipefail

# ── 03-userland.sh ────────────────────────────────────────────────────────────
# Post-first-boot userland setup.
# Must be run as a NON-ROOT user (the primary user created during install).
# Usage:
#   Normal run (on the new system):
#     bash ~/n0ko-install/03-userland.sh
#   Print instructions only (called by install.sh during live session):
#     bash /root/n0ko-install/03-userland.sh --print-instructions

LOG_FILE="${HOME:-/tmp}/.n0ko-userland-$(date +%Y%m%d-%H%M%S).log"

log() {
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[${ts}] $*" | tee -a "${LOG_FILE}"
}

die() {
    log "FATAL: $*"
    exit 1
}

# ── Print-instructions mode ───────────────────────────────────────────────────
if [[ "${1:-}" == "--print-instructions" ]]; then
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  POST-BOOT USERLAND SETUP"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "  After rebooting into the new system:"
    echo ""
    echo "  1. Log in as your new user"
    echo "  2. Copy the installer to your home directory:"
    echo "       sudo cp -r /root/n0ko-install ~/n0ko-install"
    echo "       sudo chown -R \$USER:\$USER ~/n0ko-install"
    echo "  3. Run the userland script:"
    echo "       bash ~/n0ko-install/03-userland.sh"
    echo ""
    echo "  The script will:"
    echo "    - Bootstrap yay (AUR helper)"
    echo "    - Install AUR packages from pkgs-aur.curated.txt"
    echo "    - Clone your git repos from git_repo_list"
    echo ""
    exit 0
fi

# ── Root check ────────────────────────────────────────────────────────────────
[[ "${EUID}" -ne 0 ]] || die "This script must NOT be run as root. Log in as your normal user first."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUR_PKG_LIST="${SCRIPT_DIR}/pkgs-aur.curated.txt"
GIT_REPO_LIST="${SCRIPT_DIR}/git_repo_list"

log "Starting userland setup as user: $(id -un)"

# ── Bootstrap yay ─────────────────────────────────────────────────────────────
if command -v yay &>/dev/null; then
    log "yay is already installed at $(command -v yay). Skipping bootstrap."
else
    log "Bootstrapping yay from AUR..."
    YAY_BUILD_DIR="$(mktemp -d /tmp/yay-XXXXXX)"
    git clone https://aur.archlinux.org/yay.git "${YAY_BUILD_DIR}"
    pushd "${YAY_BUILD_DIR}"
    makepkg -si --noconfirm
    popd
    rm -rf "${YAY_BUILD_DIR}"
    log "yay installed: $(yay --version)"
fi

# ── Install AUR packages ──────────────────────────────────────────────────────
if [[ -f "${AUR_PKG_LIST}" ]]; then
    mapfile -t AUR_PKGS < <(grep -v '^[[:space:]]*$' "${AUR_PKG_LIST}" | grep -v '^#')
    log "Installing ${#AUR_PKGS[@]} AUR packages..."
    yay -S --noconfirm --needed "${AUR_PKGS[@]}" 2>&1 | tee -a "${LOG_FILE}"
    log "AUR packages installed."
else
    log "WARNING: AUR package list not found at ${AUR_PKG_LIST}. Skipping AUR installs."
fi

# ── Clone git repos ───────────────────────────────────────────────────────────
if [[ -f "${GIT_REPO_LIST}" ]]; then
    REPOS_DIR="${HOME}/repos"
    mkdir -p "${REPOS_DIR}"
    log "Cloning repos into ${REPOS_DIR}..."

    while IFS= read -r line; do
        # Strip leading/trailing whitespace and surrounding quotes
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"
        url="${line//\"/}"

        [[ -n "${url}" ]] || continue
        [[ "${url}" == \#* ]] && continue

        # Derive repo dir name from URL (last path component, strip .git)
        repo_name="$(basename "${url}" .git)"
        dest="${REPOS_DIR}/${repo_name}"

        if [[ -d "${dest}/.git" ]]; then
            log "  SKIP (already exists): ${dest}"
        else
            log "  Cloning: ${url} -> ${dest}"
            # Note: space between 'git clone' and the URL is required
            git clone "${url}" "${dest}" 2>&1 | tee -a "${LOG_FILE}" || \
                log "  WARNING: Failed to clone ${url} — skipping."
        fi
    done < "${GIT_REPO_LIST}"

    log "Git repo cloning complete. Repos in: ${REPOS_DIR}"
else
    log "WARNING: git_repo_list not found at ${GIT_REPO_LIST}. Skipping repo clones."
fi

# ── Enable user services ──────────────────────────────────────────────────────
log "Enabling user PipeWire services..."
for svc in pipewire pipewire-pulse wireplumber; do
    if systemctl --user list-unit-files "${svc}.service" &>/dev/null; then
        systemctl --user enable --now "${svc}.service"
        log "  Enabled --user: ${svc}"
    else
        log "  SKIP (not found): ${svc}"
    fi
done

log "Userland setup complete. Log: ${LOG_FILE}"
echo ""
echo "Done. You may want to:"
echo "  - Set up SSH keys: ssh-keygen -t ed25519"
echo "  - Configure ~/.zshrc / dotfiles from your cloned repos"
echo "  - Install additional ROCm tools via: yay -S rocm-hip-sdk"
echo ""
