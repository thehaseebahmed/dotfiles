# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a chezmoi-managed dotfiles repository that unifies development workflow configurations across Windows, macOS, and Arch Linux (Manjaro). The repository uses chezmoi's templating system to conditionally apply configurations based on the operating system and hostname.

## Architecture

### Chezmoi Structure

This repository follows chezmoi's naming conventions:
- `dot_` prefix → Creates a dotfile (e.g., `dot_zshrc.tmpl` → `~/.zshrc`)
- `exact_` prefix → Directory should contain exactly the files specified
- `encrypted_` prefix → File is encrypted using age/rage
- `private_` prefix → File/directory permissions set to private (e.g., 0600 for files)
- `executable_` prefix → File is made executable
- `.tmpl` suffix → File is processed as a Go template

### OS Detection & Templating

The `.chezmoi.toml.tmpl` file detects the OS and sets the `osid` variable used throughout templates:
- `darwin` → macOS
- `linux-manjaro` → Arch Linux (Manjaro)
- `windows` → Windows

Templates use Go templating syntax: `{{ if eq .osid "darwin" }}...{{ end }}`

### Encryption

- Uses age encryption with `rage` command
- Encrypted files have `.age` extension
- Age identity: `~/rage.key`
- Pre-hook (`.install-enc-command.sh` or `.install-enc-command.ps1`) automatically installs `rage` if missing

### Directory Organization

- `.chezmoiscripts/` → Scripts that run during chezmoi apply
  - `run_once_00_install_apps.sh.tmpl` → Installs development tools (dnvm, cargo, metapac, uv, etc.)
  - `run_once_00_install_apps_homelab.sh` → Homelab-specific installations
- `.chezmoitemplates/` → Reusable template files
- `dot_config/` → User config files (`~/.config/`)
- `private_apps/` → Docker Compose configurations for homelab services
- `private_Library/` → macOS-specific configs (`~/Library/`)
- `private_AppData/` → Windows-specific configs (`%APPDATA%`)

### Homelab Configuration

The `.chezmoiignore` file contains special logic for homelab machines (identified by `homelab-` hostname prefix):
- Most configs are ignored by default
- Only specific allowlisted files are applied:
  - `.gitconfig`
  - `.ssh/authorized_keys`
  - `apps/` directory (Docker Compose configs)
  - `*_homelab.*` scripts

## Key Tools & Applications

### Package Management
- **metapac**: Cross-platform meta package manager
  - Config: `dot_config/exact_metapac/config.toml.tmpl`
  - Backends configured per OS: `brew` (macOS), `arch` (Linux), `winget` (Windows)
  - Command: `metapac s` (sync packages)

### Development Tools Installed
- **dnvm**: .NET version manager
- **cargo**: Rust package manager
- **uv**: Python package installer
- **espanso**: Text expander (Linux only)
- **tsui**: Tailscale UI (requires Tailscale)

### Homelab Services (private_apps/)
- **code-server**: VSCode in browser (port 8443)
- **vaultwarden**: Password manager
- **github-runners**: Ephemeral GitHub Actions runners
  - Systemd service-based
  - Instance count configured in `.chezmoidata.yaml`
  - Scripts: `enable`, `disable`, `status`, `logs`
- **n8n**: Workflow automation
- **glances**: System monitoring
- **babybuddy**: Baby care tracker

## Common Commands

### Chezmoi Operations
```bash
# Apply configurations
chezmoi apply

# Preview changes without applying
chezmoi diff

# Update from repository
chezmoi update

# Edit a file with automatic encryption
chezmoi edit ~/.gitconfig

# Add a new file to chezmoi
chezmoi add ~/.newfile

# Re-run install scripts
chezmoi apply --force
```

### Metapac Package Management
```bash
# Sync packages (install/update)
metapac s

# List backends
metapac backends

# List packages
metapac list
```

### GitHub Runners (Homelab)
```bash
# Enable all runners
~/apps/github-runners/enable

# Check status
~/apps/github-runners/status

# View logs
~/apps/github-runners/logs

# Disable all runners
~/apps/github-runners/disable
```

## Security

### Git Hooks

This repository includes a pre-commit hook that prevents accidental commits of secrets. The hook is installed via the `setup-git-hooks.sh` script.

**Setup** (run once after cloning):
```bash
./setup-git-hooks.sh
```

**What it detects:**
- AWS access keys and secret keys
- GitHub tokens and personal access tokens
- API keys and secrets
- Private keys (SSH, RSA, etc.)
- Slack tokens and webhooks
- OpenAI and Anthropic API keys
- JWT tokens and bearer tokens
- Passwords in URLs

**Automatic exclusions:**
- `.age` encrypted files (already protected)
- `.sample` files
- Documentation files (CLAUDE.md)
- Git metadata

**If the hook blocks a legitimate commit:**
1. Encrypt the file: `chezmoi edit <file>` (recommended)
2. Add the pattern to `SKIP_PATTERNS` in `.git/hooks/pre-commit`
3. Bypass (not recommended): `git commit --no-verify`

## Important Considerations

### Adding New Configurations

1. Use appropriate prefixes for the target location and permissions
2. Add `.tmpl` suffix if OS-specific logic needed
3. Use `encrypted_` prefix for sensitive data
4. Update `.chezmoiignore` if file should be OS or hostname-specific

### Testing Changes

After modifying templates, always test with:
```bash
chezmoi diff  # Preview changes
```

### Homelab Deployments

When adding homelab services:
1. Create Docker Compose file in `private_apps/`
2. Use `encrypted_dot_env.age` for secrets
3. Ensure `.chezmoiignore` allowlists the app directory
4. Use hostname detection: `{{ if hasPrefix "homelab-" .chezmoi.fqdnHostname }}`

### Encryption Workflow

Encrypted files must be edited through chezmoi:
```bash
chezmoi edit ~/.gitconfig  # Opens decrypted in editor
```

Direct editing of `.age` files will corrupt them.
