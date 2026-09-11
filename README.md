<div align="center">
    <img src="https://upload.wikimedia.org/wikipedia/commons/3/35/Tux.svg" alt="Linux Logo" width="100"/>
    <img src="https://upload.wikimedia.org/wikipedia/commons/1/13/Arch_Linux_%22Crystal%22_icon.svg" alt="Arch Linux Logo" width="100"/>
</div>

# Arch Linux System Configuration

This repository contains personal system configuration files (dotfiles) for Arch Linux. The configurations are designed to optimize terminal workflow, improve visibility, and integrate modern command-line utilities.

## Core Components

The primary component currently tracked is the `.bashrc` configuration, which provides:

*   **Modern Core Utilities Integration:** Aliases to replace standard GNU coreutils with modern Rust-based alternatives (`eza` for `ls`, `bat` for `cat`).
*   **Directory Navigation:** Integration with `zoxide` for intelligent, fast directory switching.
*   **Fuzzy Searching:** Integration with `fzf` for interactive command history search and file finding, featuring syntax-highlighted previews.
*   **Custom Prompt (PS1):** A custom, high-contrast shell prompt featuring a dark theme, carmine red accents (`#e22b31` / `#ff787d`), and dynamic Git repository status tracking.
*   **Developer Shortcuts:** Dedicated aliases for common tasks (`lazydocker`, `laptop-report`, `dust`, `killport`, `dev-db`).

## System Requirements

To utilize these configurations optimally, the following packages must be installed on your Arch Linux system:

*   `git` (Version control and prompt integration)
*   `eza` (Modern `ls` replacement)
*   `bat` (Modern `cat` replacement)
*   `zoxide` (Intelligent `cd` command)
*   `fzf` (Command-line fuzzy finder)

### Installation of Dependencies

You can install the required dependencies using `pacman`:

```bash
sudo pacman -S git eza bat zoxide fzf
```

If you are using AUR helpers for specific developer tools (like `lazydocker` or `dust`), ensure they are installed via your preferred AUR helper (e.g., `yay` or `paru`).

## Installation Instructions

The provided `install.sh` script automates the deployment of these configurations by creating symbolic links from this repository to your home directory. Existing files will be backed up automatically to `~/.dotfiles_backup/`.

1. Clone this repository into your home directory:

```bash
git clone https://github.com/YOUR_USERNAME/dotfiles.git ~/dotfiles
```

2. Navigate into the repository:

```bash
cd ~/dotfiles
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
├── .bashrc       # Shell configuration, aliases, and custom prompt
├── .gitignore    # Git tracking exclusions
├── install.sh    # Deployment and symlink generation script
└── README.md     # Technical documentation
```
