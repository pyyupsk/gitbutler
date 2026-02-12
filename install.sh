#!/usr/bin/env bash
#
# The installer for the latest stable release of GitButler on Linux.
#
# This script automatically detects the environment (distribution, architecture)
# to download and install the appropriate package (DEB, RPM, or AppImage).
# It handles new installations and upgrades, is idempotent, and prioritizes
# security and robustness.
#
# Usage: curl -fsSL <url> | bash
#

set -euo pipefail

# --- Configuration & Globals ---
API_URL="https://app.gitbutler.com/api/downloads?limit=1&channel=release"
ALLOWED_DOMAIN="https://releases.gitbutler.com"
TMP_DIR=""
OS=""
ARCH_NAME=""
PKG_TYPE=""
LATEST_VERSION=""
DOWNLOAD_URL=""
FILENAME=""
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
    for cmd in curl jq sha256sum sudo tar; do
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

    # Default to AppImage, then try to detect a native package manager
    PKG_TYPE="appimage"
    if [ -f /etc/os-release ]; then
        # shellcheck source=/dev/null
        source /etc/os-release
        if [[ "${ID_LIKE:-}" == *"debian"* || "${ID:-}" == "debian" || "${ID:-}" == "ubuntu" ]]; then
            PKG_TYPE="deb"
        elif [[ "${ID_LIKE:-}" == *"fedora"* || "${ID:-}" == "fedora" || "${ID:-}" == "rhel" || "${ID:-}" == "centos" || "${ID:-}" == "rocky" || "${ID:-}" == "almalinux" ]]; then
            PKG_TYPE="rpm"
        elif [[ "${ID:-}" == "arch" ]]; then
            warn "Arch Linux detected; will use AppImage as a fallback."
        fi
    else
        warn "Could not detect distribution from /etc/os-release. Falling back to AppImage."
    fi
    info "System: $PKG_TYPE on $ARCH_NAME"
}

fetch_release_info() {
    info "Fetching latest release information..."
    local JSON_DATA
    JSON_DATA=$(curl -fsSL "$API_URL")
    [ -n "$JSON_DATA" ] || error "Failed to fetch release data from the API."

    local RELEASE_DATA
    RELEASE_DATA=$(echo "$JSON_DATA" | jq '.[0]')
    [ -n "$RELEASE_DATA" ] && [ "$RELEASE_DATA" != "null" ] || error "Could not find release object in API response."

    LATEST_VERSION=$(echo "$RELEASE_DATA" | jq -r '.version')
    [ -n "$LATEST_VERSION" ] && [ "$LATEST_VERSION" != "null" ] || error "Could not parse version from API response."

    local BUILD_INFO
    # Prioritize native packages (deb/rpm)
    BUILD_INFO=$(echo "$RELEASE_DATA" | jq -r --arg arch "$ARCH_NAME" --arg pkg_type ".$PKG_TYPE" '.builds[] | select(.arch == $arch and (.file | endswith($pkg_type)))')

            # Fallback to AppImage if no native package is found for the detected distro
            if [ -z "$BUILD_INFO" ]; then
                info "No native package found for your distro, falling back to AppImage."
                PKG_TYPE="appimage"
                # First try to find a direct .AppImage
                BUILD_INFO=$(echo "$RELEASE_DATA" | jq -r --arg arch "$ARCH_NAME" '.builds[] | select(.arch == $arch and (.file | endswith(".AppImage")))')
    
                if [ -z "$BUILD_INFO" ]; then
                    # If no direct .AppImage, try to find a .AppImage.tar.gz
                    info "No direct AppImage found, looking for AppImage.tar.gz."
                    BUILD_INFO=$(echo "$RELEASE_DATA" | jq -r --arg arch "$ARCH_NAME" '.builds[] | select(.arch == $arch and (.file | endswith(".AppImage.tar.gz")))')
                fi
            fi
    [ -n "$BUILD_INFO" ] || error "No compatible build found for architecture '$ARCH_NAME'."

    DOWNLOAD_URL=$(echo "$BUILD_INFO" | jq -r '.url')
    FILENAME=$(echo "$BUILD_INFO" | jq -r '.file')

    [ -n "$DOWNLOAD_URL" ] && [ "$DOWNLOAD_URL" != "null" ] || error "Could not find a downloadable build for your system."

    # Security: Validate that the download URL is on the allowed domain
    if [[ ! "$DOWNLOAD_URL" =~ ^$ALLOWED_DOMAIN/ ]]; then
        error "Download URL '$DOWNLOAD_URL' is from an untrusted domain."
    fi
}

get_installed_version() {
    if command -v gitbutler &>/dev/null; then
        # Example output: "GitButler version 2.2.19" or "git-butler-cli 2.2.19"
        gitbutler --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "0.0.0"
    else
        echo "0.0.0"
    fi
}

download_and_verify() {
    info "Preparing to download version $LATEST_VERSION..."
    TMP_DIR=$(mktemp -d)
    DOWNLOAD_PATH="$TMP_DIR/$FILENAME"

    info "Downloading from $DOWNLOAD_URL"
    curl --fail --show-error -# -L -o "$DOWNLOAD_PATH" "$DOWNLOAD_URL" || error "Download failed."

    # Handle .tar.gz archives for AppImages
    if [[ "$DOWNLOAD_PATH" == *.AppImage.tar.gz ]]; then
        info "Decompressing AppImage archive..."
        tar -xzf "$DOWNLOAD_PATH" -C "$TMP_DIR" || error "Failed to decompress AppImage archive."
        # The actual AppImage file should now be in $TMP_DIR
        local extracted_appimage
        # Search for .AppImage in the temp directory, allowing for one level of subdirectory
        extracted_appimage=$(find "$TMP_DIR" -maxdepth 2 -type f -name "*.AppImage" | head -n 1)
        [ -n "$extracted_appimage" ] || error "Could not find .AppImage file after extraction."
        DOWNLOAD_PATH="$extracted_appimage" # Update DOWNLOAD_PATH to point to the extracted AppImage
        FILENAME=$(basename "$DOWNLOAD_PATH") # Update FILENAME to reflect the extracted file
    fi

    # SECURITY WARNING: The GitButler API does not provide a per-build checksum.
    # The script cannot verify the integrity of the downloaded file. This is a
    # significant security risk that originates from the asset provider.
    warn "Checksum verification is not possible as the provider does not supply checksums for Linux builds."
    warn "Skipping integrity check."
}

install_package() {
    info "Installing GitButler..."
    info "Root privileges are required. You may be prompted for your password."

    case "$PKG_TYPE" in
        deb)
            sudo dpkg -i "$DOWNLOAD_PATH" || error "dpkg installation failed."
            ;;
        rpm)
            sudo rpm -Uvh "$DOWNLOAD_PATH" || error "rpm installation failed."
            ;;
        appimage)
            local APP_INSTALL_DIR="/opt/gitbutler"
            local BIN_DIR="/usr/local/bin"
            local APPIMAGE_NAME="GitButler-${LATEST_VERSION}-${ARCH_NAME}.AppImage"
            local APPIMAGE_PATH="$APP_INSTALL_DIR/$APPIMAGE_NAME"
            local SYMLINK_PATH="$BIN_DIR/gitbutler"

            info "Installing AppImage to $APP_INSTALL_DIR and symlinking to $SYMLINK_PATH..."
            sudo chmod +x "$DOWNLOAD_PATH"
            sudo mkdir -p "$APP_INSTALL_DIR"
            sudo mv "$DOWNLOAD_PATH" "$APPIMAGE_PATH"
            sudo ln -sf "$APPIMAGE_PATH" "$SYMLINK_PATH"
            ;;
        *)
            error "Internal error: Unknown package type '$PKG_TYPE'."
            ;;
    esac
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
        info "GitButler is already up to date (Version: $INSTALLED_VERSION)."
        exit 0
    fi

    if [ "$INSTALLED_VERSION" != "0.0.0" ]; then
        info "Found installed version $INSTALLED_VERSION. Upgrading to $LATEST_VERSION."
    else
        info "GitButler not found. Installing version $LATEST_VERSION."
    fi

    download_and_verify
    install_package

    # Final verification to ensure installation was successful
    local FINAL_VERSION
    local INSTALL_PATH
    FINAL_VERSION=$(get_installed_version)
    INSTALL_PATH=$(command -v gitbutler)

    if [ "$INSTALL_PATH" ]; then
        info "✅ Successfully installed GitButler version $FINAL_VERSION"
        info "   Path: $INSTALL_PATH"
        echo ""
        info "To enable shell completions and alias, add the following to your shell configuration:"
        info "  Zsh:"
        info "    echo 'alias but=\"gitbutler\"' >> ~/.zshrc"
        info "    echo 'eval \"\$(gitbutler completions zsh)\"' >> ~/.zshrc"
        info ""
        info "  Bash:"
        info "    echo 'alias but=\"gitbutler\"' >> ~/.bashrc"
        info "    echo 'eval \"\$(gitbutler completions bash)\"' >> ~/.bashrc"
        info ""
        info "  Fish:"
        info "    echo 'alias but=\"gitbutler\"' >> ~/.config/fish/config.fish"
        info "    echo 'gitbutler completions fish | source' >> ~/.config/fish/config.fish"
        echo ""
        info "Then restart your shell or source the configuration file."
    else
        error "Installation finished, but the 'gitbutler' command could not be found in the system's PATH."
    fi
}

main "$@"
