<div align="center">
    <img src="https://upload.wikimedia.org/wikipedia/commons/3/35/Tux.svg" alt="Linux Logo" width="100"/>
    <img src="https://upload.wikimedia.org/wikipedia/commons/1/13/Arch_Linux_%22Crystal%22_icon.svg" alt="Arch Linux Logo" width="100"/>
</div>

# Arch Linux System Configuration

This repository contains personal system configuration files (dotfiles) for Arch Linux. The configurations are designed to optimize terminal workflow, improve visibility, and integrate modern command-line utilities.

## Core Components

The repository tracks the full desktop environment, system daemons, and developer workflow:

*   **Shell Configuration (`.bashrc`):** Aliases, modern CLI tools (`eza`, `bat`, `zoxide`, `fzf`), and carmine red prompt with Git status tracking.
*   **Window Management (`.config/hypr`):** Complete Hyprland setup including display configurations, workspace bindings, and floating rules for utilities like `wifi-manager` and `blueman-manager`.
*   **Desktop Status Bar (`.config/quickshell`):** Custom status bar featuring liquid glass styling, dynamic workspaces, media controls, and reactive widgets for battery, audio, and network.
*   **Notification Engine (`.config/mako`):** Notification rules and dark obsidian glass theming with sound integration.
*   **System Daemons (`.config/systemd/user`):** Background services for battery alerts (`hypr-battery-alert.service`), calendar reminders, and audio jack auto-switching.
*   **Developer CLI Tools (`.local/bin`):** Custom utilities for battery monitoring (`hypr-battery-alert`), cheatsheets (`cmds`), dev databases (`dev-db`), port management (`killport`, `ports`), and system diagnostics (`laptop-report`).

## System Requirements

To utilize these configurations optimally, the following packages must be installed on your Arch Linux system:

*   `git` (Version control and prompt integration)
*   `eza` (Modern `ls` replacement)
*   `bat` (Modern `cat` replacement)
*   `zoxide` (Intelligent `cd` command)
*   `fzf` (Command-line fuzzy finder)
*   `hyprland`, `quickshell`, `mako` (Desktop environment & notification daemon)

### Installation of Dependencies

You can install the required dependencies using `pacman`:

```bash
sudo pacman -S git eza bat zoxide fzf mako kitty
```

If you are using AUR helpers for specific developer tools (like `quickshell`, `lazydocker` or `dust`), ensure they are installed via your preferred AUR helper (e.g., `yay` or `paru`).

## Installation Instructions

The provided `install.sh` script automates the deployment of these configurations by creating symbolic links from this repository to your home directory. Existing files will be backed up automatically to `~/.dotfiles_backup/`.

1. Clone this repository into your personal directory:

```bash
git clone https://github.com/dferram/arch-config.git ~/Personal/dotfiles
```

2. Navigate into the repository:

```bash
cd ~/Personal/dotfiles
```

3. Make the installation script executable:

```bash
chmod +x install.sh
```

4. Execute the installation script:

```bash
./install.sh
```

5. Apply the changes to your current session:

```bash
source ~/.bashrc
```

## Structure

```text
.
├── .bashrc              # Shell configuration, aliases, and custom prompt
├── .gitignore           # Git tracking exclusions
├── install.sh           # Deployment and symlink generation script
├── README.md            # Technical documentation
├── .config/
│   ├── fastfetch/       # System info configuration
│   ├── hypr/            # Hyprland window manager & display configuration
│   ├── kitty/           # Terminal emulator settings
│   ├── mako/            # Notification daemon styling
│   ├── quickshell/      # Modern top bar widgets and liquid glass theme
│   └── systemd/user/    # Background services (battery alert, reminders)
└── .local/
    └── bin/             # Custom developer scripts and monitoring daemons
```
