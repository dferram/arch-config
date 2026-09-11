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

echo "Installation complete."
echo "Please restart your terminal or run: source ~/.bashrc"
