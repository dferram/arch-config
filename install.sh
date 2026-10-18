#!/usr/bin/env bash

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="${HOME}/.dotfiles_backup/$(date +%Y%m%d_%H%M%S)"

echo "Starting dotfiles installation process..."

create_symlink() {
    local source_file="$1"
    local target_file="$2"

    if [ -e "$target_file" ] || [ -L "$target_file" ]; then
        if [ "$(readlink "$target_file")" = "$source_file" ]; then
            echo "Symlink for $target_file already exists and is correct. Skipping."
            return
        fi
        
        echo "Backing up existing file: $target_file -> $BACKUP_DIR/"
        mkdir -p "$BACKUP_DIR"
        mv "$target_file" "$BACKUP_DIR/"
    fi

    echo "Creating symlink: $target_file -> $source_file"
    ln -s "$source_file" "$target_file"
}

# Install .bashrc and git configs
create_symlink "$DOTFILES_DIR/.bashrc" "$HOME/.bashrc"
create_symlink "$DOTFILES_DIR/.gitconfig" "$HOME/.gitconfig"
if [ -f "$DOTFILES_DIR/.gitconfig-local" ]; then
    create_symlink "$DOTFILES_DIR/.gitconfig-local" "$HOME/.gitconfig-local"
fi

# Install .config directories
mkdir -p "$HOME/.config"
for dir in hypr quickshell mako kitty fastfetch easyeffects cava; do
    if [ -d "$DOTFILES_DIR/.config/$dir" ]; then
        create_symlink "$DOTFILES_DIR/.config/$dir" "$HOME/.config/$dir"
    fi
done

# Install starship.toml
if [ -f "$DOTFILES_DIR/.config/starship.toml" ]; then
    create_symlink "$DOTFILES_DIR/.config/starship.toml" "$HOME/.config/starship.toml"
fi

# Install systemd user services
mkdir -p "$HOME/.config/systemd/user"
if [ -d "$DOTFILES_DIR/.config/systemd/user" ]; then
    for svc in "$DOTFILES_DIR/.config/systemd/user"/*.service; do
        [ -f "$svc" ] || continue
        svc_name="$(basename "$svc")"
        create_symlink "$svc" "$HOME/.config/systemd/user/$svc_name"
    done
fi

# Install custom scripts in .local/bin
mkdir -p "$HOME/.local/bin"
if [ -d "$DOTFILES_DIR/.local/bin" ]; then
    for script in "$DOTFILES_DIR/.local/bin"/*; do
        [ -f "$script" ] || continue
        script_name="$(basename "$script")"
        create_symlink "$script" "$HOME/.local/bin/$script_name"
    done
fi

# Install icons in .local/share/icons
mkdir -p "$HOME/.local/share/icons"
if [ -d "$DOTFILES_DIR/.local/share/icons" ]; then
    for icon in "$DOTFILES_DIR/.local/share/icons"/*; do
        [ -f "$icon" ] || continue
        create_symlink "$icon" "$HOME/.local/share/icons/$(basename "$icon")"
    done
fi
# Ensure quickshell standalone icons are also reachable in system icons path
if [ -d "$DOTFILES_DIR/.config/quickshell/icons" ]; then
    for icon in "$DOTFILES_DIR/.config/quickshell/icons"/*; do
        [ -f "$icon" ] || continue
        icon_name="$(basename "$icon")"
        target="$HOME/.local/share/icons/$icon_name"
        [ -e "$target" ] || ln -s "$icon" "$target"
    done
fi

echo "Installation complete."
echo "All system configurations and developer tools are now linked."
