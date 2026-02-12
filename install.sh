#!/usr/bin/env bash
#
# The installer for the latest stable release of GitButler CLI on Linux.
#
# This script automatically detects the environment (architecture) to download
# and install the appropriate CLI binary. It handles new installations and
# upgrades, is idempotent, and prioritizes security and robustness.
#
# Usage: curl -fsSL <url> | bash
#

set -euo pipefail

# --- Configuration & Globals ---
API_URL="https://app.gitbutler.com/api/downloads?limit=1&channel=release"
ALLOWED_DOMAIN="https://releases.gitbutler.com"
INSTALL_DIR="/usr/local/bin"
TMP_DIR=""
OS=""
ARCH_NAME=""
LATEST_VERSION=""
DOWNLOAD_URL=""
FILENAME="but"
DOWNLOAD_PATH=""

# --- Terminal Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# --- Helper Functions ---

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    exit 1
}

cleanup() {
    # This check is necessary to avoid errors if the script fails before TMP_DIR is set.
    if [ -n "${TMP_DIR:-}" ] && [ -d "$TMP_DIR" ]; then
        info "Cleaning up temporary directory..."
        rm -rf "$TMP_DIR"
    fi
}
trap cleanup EXIT

check_dependencies() {
    info "Checking for required tools..."
    local missing_deps=0
    for cmd in curl jq sudo; do
        if ! command -v "$cmd" &>/dev/null; then
            echo -e "${RED}- Missing required command: $cmd${NC}" >&2
            missing_deps=1
        fi
    done
    [ $missing_deps -eq 0 ] || error "Please install the missing tools and try again."
}

detect_environment() {
    info "Detecting system environment..."
    OS=$(uname -s)
    local ARCH
    ARCH=$(uname -m)

    [ "$OS" == "Linux" ] || error "This script is only for Linux. Detected OS: $OS"

    case "$ARCH" in
        x86_64) ARCH_NAME="x86_64" ;;
        aarch64 | arm64) ARCH_NAME="aarch64" ;;
        *) error "Unsupported architecture: $ARCH. Only x86_64 and aarch64 are supported." ;;
    esac

    info "System: Linux $ARCH_NAME"
}

fetch_release_info() {
    info "Fetching latest CLI release information..."
    local JSON_DATA
    JSON_DATA=$(curl -fsSL "$API_URL")
    [ -n "$JSON_DATA" ] || error "Failed to fetch release data from the API."

    local RELEASE_DATA
    RELEASE_DATA=$(echo "$JSON_DATA" | jq '.[0]')
    [ -n "$RELEASE_DATA" ] && [ "$RELEASE_DATA" != "null" ] || error "Could not find release object in API response."

    LATEST_VERSION=$(echo "$RELEASE_DATA" | jq -r '.version')
    [ -n "$LATEST_VERSION" ] && [ "$LATEST_VERSION" != "null" ] || error "Could not parse version from API response."

    local BUILD_INFO
    # Fetch the CLI binary (file == "but")
    BUILD_INFO=$(echo "$RELEASE_DATA" | jq -r --arg arch "$ARCH_NAME" '.builds[] | select(.arch == $arch and .file == "but")')
    [ -n "$BUILD_INFO" ] || error "No CLI binary found for architecture '$ARCH_NAME'."

    DOWNLOAD_URL=$(echo "$BUILD_INFO" | jq -r '.url')
    [ -n "$DOWNLOAD_URL" ] && [ "$DOWNLOAD_URL" != "null" ] || error "Could not find downloadable CLI binary for your system."

    # Security: Validate that the download URL is on the allowed domain
    if [[ ! "$DOWNLOAD_URL" =~ ^$ALLOWED_DOMAIN/ ]]; then
        error "Download URL '$DOWNLOAD_URL' is from an untrusted domain."
    fi
}

get_installed_version() {
    if command -v but &>/dev/null; then
        # Example output: "but 0.19.1"
        but --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "0.0.0"
    else
        echo "0.0.0"
    fi
}

download_and_verify() {
    info "Preparing to download CLI version $LATEST_VERSION..."
    TMP_DIR=$(mktemp -d)
    DOWNLOAD_PATH="$TMP_DIR/$FILENAME"

    info "Downloading from $DOWNLOAD_URL"
    curl --fail --show-error -# -L -o "$DOWNLOAD_PATH" "$DOWNLOAD_URL" || error "Download failed."

    # Verify the downloaded file is not empty
    [ -s "$DOWNLOAD_PATH" ] || error "Downloaded file is empty."

    # SECURITY WARNING: The GitButler API does not provide a per-build checksum.
    # The script cannot verify the integrity of the downloaded file. This is a
    # significant security risk that originates from the asset provider.
    warn "Checksum verification is not possible as the provider does not supply checksums."
    warn "Skipping integrity check."
}

install_package() {
    info "Installing GitButler CLI..."
    info "Root privileges are required. You may be prompted for your password."

    local INSTALL_PATH="$INSTALL_DIR/$FILENAME"

    # Make the binary executable
    chmod +x "$DOWNLOAD_PATH" || error "Failed to make binary executable."

    # Install the binary to /usr/local/bin
    sudo mv "$DOWNLOAD_PATH" "$INSTALL_PATH" || error "Failed to install binary to $INSTALL_PATH."

    info "GitButler CLI installed to $INSTALL_PATH"
}

# --- Main Execution ---
main() {
    check_dependencies
    detect_environment
    fetch_release_info

    local INSTALLED_VERSION
    INSTALLED_VERSION=$(get_installed_version)

    local HIGHEST_VERSION
    HIGHEST_VERSION=$(printf '%s
' "$LATEST_VERSION" "$INSTALLED_VERSION" | sort -V | tail -n1)

    if [ "$INSTALLED_VERSION" == "$LATEST_VERSION" ] || [ "$INSTALLED_VERSION" == "$HIGHEST_VERSION" ]; then
        info "GitButler CLI is already up to date (Version: $INSTALLED_VERSION)."
        exit 0
    fi

    if [ "$INSTALLED_VERSION" != "0.0.0" ]; then
        info "Found installed version $INSTALLED_VERSION. Upgrading to $LATEST_VERSION."
    else
        info "GitButler CLI not found. Installing version $LATEST_VERSION."
    fi

    download_and_verify
    install_package

    # Final verification to ensure installation was successful
    local FINAL_VERSION
    local INSTALL_PATH
    FINAL_VERSION=$(get_installed_version)
    INSTALL_PATH=$(command -v but)

    if [ "$INSTALL_PATH" ]; then
        info "✅ Successfully installed GitButler CLI version $FINAL_VERSION"
        info "   Path: $INSTALL_PATH"
        echo ""
        info "To enable shell completions, add the following to your shell configuration:"
        info "  Zsh:"
        info "    echo 'eval \"\$(but completions zsh)\"' >> ~/.zshrc"
        info ""
        info "  Bash:"
        info "    echo 'eval \"\$(but completions bash)\"' >> ~/.bashrc"
        info ""
        info "  Fish:"
        info "    echo 'but completions fish | source' >> ~/.config/fish/config.fish"
        echo ""
        info "Then restart your shell or source the configuration file."
    else
        error "Installation finished, but the 'but' command could not be found in the system's PATH."
    fi
}

main "$@"
