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

# Install .bashrc
create_symlink "$DOTFILES_DIR/.bashrc" "$HOME/.bashrc"

# Install .config directories
mkdir -p "$HOME/.config"
for dir in hypr quickshell mako kitty fastfetch; do
    if [ -d "$DOTFILES_DIR/.config/$dir" ]; then
        create_symlink "$DOTFILES_DIR/.config/$dir" "$HOME/.config/$dir"
    fi
done

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

echo "Installation complete."
echo "All system configurations and developer tools are now linked."
