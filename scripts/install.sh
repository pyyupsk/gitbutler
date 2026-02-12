#!/usr/bin/env bash
#
# GitButler CLI Installer for Linux
#
# A simple Bash script to install, update, or uninstall the GitButler CLI on Linux.
# This script automatically detects the environment (architecture) to download
# and install the appropriate CLI binary. It handles new installations and
# upgrades, is idempotent, and prioritizes security and robustness.
#
# Usage:
#   Install/Update: curl -fsSL <url> | bash
#   Force mode:     curl -fsSL <url> | bash -s -- --force
#   Quiet mode:     curl -fsSL <url> | bash -s -- --quiet
#   Uninstall:      curl -fsSL <url> | bash -s -- --uninstall
#   Help:           curl -fsSL <url> | bash -s -- --help
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

# Flags
FORCE_MODE=false
QUIET_MODE=false
UNINSTALL_MODE=false

# --- Terminal Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- Helper Functions ---
info() {
  [ "$QUIET_MODE" = true ] || echo -e "${BLUE}[+]${NC} $1"
}

warn() {
  [ "$QUIET_MODE" = true ] || echo -e "${YELLOW}[!]${NC} $1"
}

error() {
  echo -e "${RED}[-]${NC} $1" >&2
  exit 1
}

success() {
  [ "$QUIET_MODE" = true ] || echo -e "${GREEN}[✓]${NC} $1"
}

prompt_confirm() {
  if [ "$FORCE_MODE" = true ]; then
    return 0
  fi

  local message="$1"
  echo -e "${BLUE}[?]${NC} $message (y/N): "
  read -r response
  case "$response" in
  [yY][eE][sS] | [yY])
    return 0
    ;;
  *)
    return 1
    ;;
  esac
}

cleanup() {
  if [ -n "${TMP_DIR:-}" ] && [ -d "$TMP_DIR" ]; then
    rm -rf "$TMP_DIR"
  fi
}
trap cleanup EXIT

show_help() {
  cat <<EOF
GitButler CLI Installer

Usage: $0 [OPTIONS]

Options:
  --force       Skip confirmation prompts
  --quiet       Minimal output (errors only)
  --uninstall   Uninstall GitButler CLI
  --help        Show this help message

Examples:
  # Basic installation
  curl -fsSL <url> | bash

  # Force installation without prompts
  curl -fsSL <url> | bash -s -- --force

  # Quiet installation
  curl -fsSL <url> | bash -s -- --quiet

  # Uninstall
  curl -fsSL <url> | bash -s -- --uninstall

EOF
  exit 0
}

parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
    --force)
      FORCE_MODE=true
      shift
      ;;
    --quiet)
      QUIET_MODE=true
      shift
      ;;
    --uninstall)
      UNINSTALL_MODE=true
      shift
      ;;
    --help)
      show_help
      ;;
    *)
      error "Unknown option: $1. Use --help for usage information."
      ;;
    esac
  done
}

check_dependencies() {
  info "Checking for required tools..."
  local missing_deps=0
  for cmd in curl jq sudo; do
    if ! command -v "$cmd" &>/dev/null; then
      echo -e "${RED}[-]${NC} Missing required command: $cmd" >&2
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
  BUILD_INFO=$(echo "$RELEASE_DATA" | jq -r --arg arch "$ARCH_NAME" '.builds[] | select(.arch == $arch and .file == "but")')
  [ -n "$BUILD_INFO" ] || error "No CLI binary found for architecture '$ARCH_NAME'."

  DOWNLOAD_URL=$(echo "$BUILD_INFO" | jq -r '.url')
  [ -n "$DOWNLOAD_URL" ] && [ "$DOWNLOAD_URL" != "null" ] || error "Could not find downloadable CLI binary for your system."

  if [[ ! "$DOWNLOAD_URL" =~ ^$ALLOWED_DOMAIN/ ]]; then
    error "Download URL '$DOWNLOAD_URL' is from an untrusted domain."
  fi
}

get_installed_version() {
  if command -v but &>/dev/null; then
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
  if [ "$QUIET_MODE" = true ]; then
    curl --fail --show-error -sL -o "$DOWNLOAD_PATH" "$DOWNLOAD_URL" || error "Download failed."
  else
    curl --fail --show-error -# -L -o "$DOWNLOAD_PATH" "$DOWNLOAD_URL" || error "Download failed."
  fi

  [ -s "$DOWNLOAD_PATH" ] || error "Downloaded file is empty."

  warn "Checksum verification is not possible as the provider does not supply checksums."
}

install_package() {
  info "Installing GitButler CLI..."

  local INSTALL_PATH="$INSTALL_DIR/$FILENAME"

  if [ -f "$INSTALL_PATH" ] && [ "$FORCE_MODE" = false ]; then
    if ! prompt_confirm "GitButler CLI is already installed. Do you want to reinstall?"; then
      info "Installation cancelled."
      exit 0
    fi
  fi

  info "Root privileges may be required. You may be prompted for your password."

  chmod +x "$DOWNLOAD_PATH" || error "Failed to make binary executable."
  sudo mv "$DOWNLOAD_PATH" "$INSTALL_PATH" || error "Failed to install binary to $INSTALL_PATH."

  success "GitButler CLI installed to $INSTALL_PATH"
}

uninstall_gitbutler() {
  info "Uninstalling GitButler CLI..."

  local INSTALL_PATH="$INSTALL_DIR/$FILENAME"

  if [ ! -f "$INSTALL_PATH" ]; then
    warn "GitButler CLI is not installed at $INSTALL_PATH"
    exit 0
  fi

  if [ "$FORCE_MODE" = false ]; then
    if ! prompt_confirm "Are you sure you want to uninstall GitButler CLI?"; then
      info "Uninstallation cancelled."
      exit 0
    fi
  fi

  info "Root privileges may be required. You may be prompted for your password."
  sudo rm -f "$INSTALL_PATH" || error "Failed to remove $INSTALL_PATH"

  success "GitButler CLI has been successfully uninstalled."
  info "Configuration files (if any) in your home directory were not removed."
}

show_completion_instructions() {
  [ "$QUIET_MODE" = true ] && return

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
}

# --- Main Execution ---
main() {
  parse_arguments "$@"

  if [ "$UNINSTALL_MODE" = true ]; then
    uninstall_gitbutler
    exit 0
  fi

  check_dependencies
  detect_environment
  fetch_release_info

  local INSTALLED_VERSION
  INSTALLED_VERSION=$(get_installed_version)

  local HIGHEST_VERSION
  HIGHEST_VERSION=$(printf '%s\n' "$LATEST_VERSION" "$INSTALLED_VERSION" | sort -V | tail -n1)

  if [ "$INSTALLED_VERSION" == "$LATEST_VERSION" ] || [ "$INSTALLED_VERSION" == "$HIGHEST_VERSION" ]; then
    success "GitButler CLI is already up to date (Version: $INSTALLED_VERSION)."
    exit 0
  fi

  if [ "$INSTALLED_VERSION" != "0.0.0" ]; then
    info "Found installed version $INSTALLED_VERSION. Upgrading to $LATEST_VERSION."
  else
    info "GitButler CLI not found. Installing version $LATEST_VERSION."
  fi

  download_and_verify
  install_package

  local FINAL_VERSION
  local INSTALL_PATH
  FINAL_VERSION=$(get_installed_version)
  INSTALL_PATH=$(command -v but)

  if [ "$INSTALL_PATH" ]; then
    success "Successfully installed GitButler CLI version $FINAL_VERSION"
    info "Path: $INSTALL_PATH"
    show_completion_instructions
  else
    error "Installation finished, but the 'but' command could not be found in the system's PATH."
  fi
}

main "$@"
