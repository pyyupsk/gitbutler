# 🎩 GitButler CLI Installer

A simple Bash script to **install**, **update**, or **uninstall** the **GitButler CLI** on Linux.

![GitButler](https://gitbutler.com/og-image.png)

## ✨ Features

- 🚀 Install or update the **latest version** of GitButler CLI
- 🔐 Validates downloads from trusted domains
- 🎯 Supports both **x86_64** and **aarch64** architectures
- 🔄 Automatic version detection and smart upgrades
- 🧹 Clean uninstallation with a single command
- 📋 Clean and informative logs with symbols

## 🔧 Requirements

Make sure the following tools are installed before running the script:

- `curl` - For downloading files
- `jq` - For parsing JSON
- `sudo` - For system-wide installation

## 💻 Usage

### Basic Installation

Install GitButler CLI:

```bash
curl -fsSL https://raw.githubusercontent.com/pyyupsk/gitbutler/main/scripts/install.sh | bash
```

### Advanced Options

Force installation without confirmation prompts:

```bash
curl -fsSL https://raw.githubusercontent.com/pyyupsk/gitbutler/main/scripts/install.sh | bash -s -- --force
```

Quiet installation with minimal output:

```bash
curl -fsSL https://raw.githubusercontent.com/pyyupsk/gitbutler/main/scripts/install.sh | bash -s -- --quiet
```

Combined force and quiet installation:

```bash
curl -fsSL https://raw.githubusercontent.com/pyyupsk/gitbutler/main/scripts/install.sh | bash -s -- --force --quiet
```

View help information:

```bash
curl -fsSL https://raw.githubusercontent.com/pyyupsk/gitbutler/main/scripts/install.sh | bash -s -- --help
```

## 🔄 Installation Flow

1. Validates required dependencies (`curl`, `jq`, `sudo`)
2. Detects system architecture (x86_64 or aarch64)
3. Fetches the latest GitButler CLI version from the official API
4. Checks for existing installation and compares versions
5. Downloads the appropriate binary from trusted source
6. Installs to `/usr/local/bin/but`
7. Provides shell completion setup instructions

## 🎯 Post-Installation

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

## 🚀 Usage Examples

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

# Push changes
but push

# And more...
```

For full documentation, visit: <https://docs.gitbutler.com/cli-overview>

## 🧹 Uninstallation

To completely remove GitButler CLI:

```bash
curl -fsSL https://raw.githubusercontent.com/pyyupsk/gitbutler/main/scripts/install.sh | bash -s -- --uninstall
```

Force uninstallation without confirmation:

```bash
curl -fsSL https://raw.githubusercontent.com/pyyupsk/gitbutler/main/scripts/install.sh | bash -s -- --uninstall --force
```

This will remove:

- `/usr/local/bin/but`

> **Note:** Configuration files in your home directory (if any) are preserved.

## 🔒 Security

- All downloads are validated to come from `https://releases.gitbutler.com`
- The script uses secure temporary directories with automatic cleanup
- However, note that GitButler does not provide checksums for Linux CLI builds, so file integrity cannot be cryptographically verified

## 🛠️ Troubleshooting

| Issue                        | Solution                                                                                       |
| ---------------------------- | ---------------------------------------------------------------------------------------------- |
| **Missing dependencies**     | Install required tools: `curl`, `jq`, `sudo` using your package manager                        |
| **Command not found**        | Ensure `/usr/local/bin` is in your PATH: `echo $PATH \| grep "/usr/local/bin"`                 |
| **Permission denied**        | The script requires sudo privileges. You'll be prompted for your password during installation. |
| **Architecture unsupported** | Only x86_64 and aarch64 are supported. Check your architecture with `uname -m`                 |

### Install Missing Dependencies

```bash
# Debian/Ubuntu
sudo apt install curl jq

# Fedora/RHEL/CentOS
sudo dnf install curl jq

# Arch Linux
sudo pacman -S curl jq

# Alpine Linux
sudo apk add curl jq

# openSUSE
sudo zypper install curl jq
```

## 🤝 Contributing

We welcome contributions!

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Commit your changes (`git commit -m 'feat: add amazing feature'`)
5. Push to the branch (`git push origin feature/amazing-feature`)
6. Open a Pull Request

> Please follow existing code style and keep your changes focused.

## 💖 Credits

- **GitButler CLI** is developed by [**GitButler**](https://gitbutler.com)
- This installer is **unofficial** and created by [**@pyyupsk**](https://github.com/pyyupsk) to streamline Linux installation and management

## 📚 Resources

- [GitButler Website](https://gitbutler.com)
- [GitButler Documentation](https://docs.gitbutler.com)
- [GitButler CLI Overview](https://docs.gitbutler.com/cli-overview)
- [GitButler GitHub](https://github.com/gitbutlerapp/gitbutler)

## ⚠️ Disclaimer

**This installation script for GitButler CLI is not officially associated with, endorsed by, or affiliated with GitButler (<https://gitbutler.com>), the original developers of GitButler.** This script is provided as an independent, third-party tool to facilitate installation of the software.

The script is provided **"as is" without warranty of any kind**, either expressed or implied, including, but not limited to, the implied warranties of merchantability and fitness for a particular purpose. **The entire risk as to the quality and performance of the script is with you.**

By using this installation script, you acknowledge that you are using an **unofficial installation method** and accept all associated risks. Please visit <https://gitbutler.com> for official downloads and installation methods.

## 📝 License

This installation script is provided as-is for convenience. GitButler itself is licensed by its respective owners.

---

Made with ❤️ by [@pyyupsk](https://github.com/pyyupsk)
