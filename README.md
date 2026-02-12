# GitButler CLI Installer

A secure, robust installation script for the [GitButler CLI](https://gitbutler.com) on Linux systems.

## Features

- **Universal Linux Support**: Works on all Linux distributions (Debian, Ubuntu, Fedora, Arch, Alpine, etc.)
- **Architecture Detection**: Automatic detection of x86_64 and aarch64 architectures
- **Version Management**: Handles new installations and upgrades intelligently
- **Idempotent**: Safe to run multiple times - won't reinstall if already up to date
- **Security First**: Validates download URLs against trusted domains
- **CLI-Only**: Installs the lightweight CLI tool, not the desktop application

## Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/pyyupsk/gitbutler/main/install.sh | bash
```

## Requirements

The script requires these tools (usually pre-installed on most Linux systems):

- `curl` - For downloading files
- `jq` - For parsing JSON
- `sudo` - For system-wide installation

## What It Does

1. Detects your system architecture (x86_64 or aarch64)
2. Fetches the latest GitButler CLI release from the official API
3. Downloads the appropriate binary for your architecture
4. Installs it to `/usr/local/bin/but`
5. Provides setup instructions for shell completions

## Post-Installation

After installation, enable shell completions by adding the following to your shell configuration:

### Zsh

```bash
echo 'eval "$(but completions zsh)"' >> ~/.zshrc
source ~/.zshrc
```

### Bash

```bash
echo 'eval "$(but completions bash)"' >> ~/.bashrc
source ~/.bashrc
```

### Fish

```bash
echo 'but completions fish | source' >> ~/.config/fish/config.fish
source ~/.config/fish/config.fish
```

## Usage

Once installed, you can use the `but` command:

```bash
# View help
but --help

# Check version
but --version

# Initialize GitButler in a repository
but setup

# View status
but status

# Create a commit
but commit

# And more...
```

For full documentation, visit: <https://docs.gitbutler.com/cli-overview>

## Security

- All downloads are validated to come from `https://releases.gitbutler.com`
- The script uses secure temporary directories with automatic cleanup
- However, note that GitButler does not provide checksums for Linux builds, so file integrity cannot be cryptographically verified

## Manual Installation

If you prefer to install manually:

1. Download the binary:

   ```bash
   # For x86_64
   curl -fsSL -o but https://releases.gitbutler.com/releases/release/latest/linux/x86_64/but

   # For aarch64
   curl -fsSL -o but https://releases.gitbutler.com/releases/release/latest/linux/aarch64/but
   ```

2. Make it executable and move to PATH:

   ```bash
   chmod +x but
   sudo mv but /usr/local/bin/
   ```

## Troubleshooting

### Command not found after installation

Ensure `/usr/local/bin` is in your PATH:

```bash
echo $PATH | grep -q "/usr/local/bin" || echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.bashrc
```

### Permission denied

The script requires sudo privileges to install to system directories. You may be prompted for your password during installation.

### Missing dependencies

Install required tools:

```bash
# Debian/Ubuntu
sudo apt install curl jq

# Fedora/RHEL
sudo dnf install curl jq

# Arch Linux
sudo pacman -S curl jq

# Alpine
sudo apk add curl jq
```

## License

This installation script is provided as-is for convenience. GitButler itself is licensed by its respective owners.

## Links

- [GitButler Website](https://gitbutler.com)
- [GitButler Documentation](https://docs.gitbutler.com)
- [GitButler CLI Overview](https://docs.gitbutler.com/cli-overview)
- [GitButler GitHub](https://github.com/gitbutlerapp/gitbutler)
