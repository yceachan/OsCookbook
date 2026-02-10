#!/bin/bash
set -e

# ==============================================================================
# CONFIGURATION
# ==============================================================================
# [IMPORTANT] REPLACE this with the Raw URL where your .zshrc and .p10k.zsh are hosted.
# If you are using GitHub Gist, click "Raw" on the file and copy the URL prefix.
# Example: https://raw.githubusercontent.com/username/my-zsh-config/main
# Or for a Gist: https://gist.githubusercontent.com/username/hash/raw
REPO_URL="https://raw.githubusercontent.com/yceachan/OsCookbook/main/CSAPP/SHELL/zsh_config_export"

# ==============================================================================
# INSTALLATION
# ==============================================================================

echo ">>> Starting Zsh Setup..."

# 1. Install Dependencies (Ubuntu/Debian)
if command -v apt-get &> /dev/null; then
    echo ">>> Installing dependencies (zsh, git, curl)..."
    sudo apt-get update && sudo apt-get install -y zsh git curl
else
    echo ">>> Warning: apt-get not found. Ensure zsh, git, and curl are installed manually."
fi

# 2. Install Oh My Zsh
if [ -d "$HOME/.oh-my-zsh" ]; then
    echo ">>> Oh My Zsh is already installed. Skipping..."
else
    echo ">>> Installing Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# 3. Install Powerlevel10k Theme
P10K_DIR=${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
if [ -d "$P10K_DIR" ]; then
    echo ">>> Powerlevel10k already installed."
else
    echo ">>> Installing Powerlevel10k..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
fi

# 4. Install Plugins
PLUGIN_DIR=${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins

# zsh-autosuggestions
if [ -d "$PLUGIN_DIR/zsh-autosuggestions" ]; then
    echo ">>> zsh-autosuggestions already installed."
else
    echo ">>> Installing zsh-autosuggestions..."
    git clone https://github.com/zsh-users/zsh-autosuggestions "$PLUGIN_DIR/zsh-autosuggestions"
fi

# zsh-syntax-highlighting
if [ -d "$PLUGIN_DIR/zsh-syntax-highlighting" ]; then
    echo ">>> zsh-syntax-highlighting already installed."
else
    echo ">>> Installing zsh-syntax-highlighting..."
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$PLUGIN_DIR/zsh-syntax-highlighting"
fi

# 5. Install Configuration Files
echo ">>> Installing configuration files..."

# Backup existing config
[ -f "$HOME/.zshrc" ] && mv "$HOME/.zshrc" "$HOME/.zshrc.backup.$(date +%s)"
[ -f "$HOME/.p10k.zsh" ] && mv "$HOME/.p10k.zsh" "$HOME/.p10k.zsh.backup.$(date +%s)"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "$SCRIPT_DIR/.zshrc" ] && [ -f "$SCRIPT_DIR/.p10k.zsh" ]; then
    echo ">>> Local configuration files found. Copying..."
    cp "$SCRIPT_DIR/.zshrc" "$HOME/.zshrc"
    cp "$SCRIPT_DIR/.p10k.zsh" "$HOME/.p10k.zsh"
else
    echo ">>> Local config not found. Attempting download from $REPO_URL..."
    if [ "$REPO_URL" == "YOUR_RAW_URL_HERE" ]; then
        echo "!!! ERROR: REPO_URL is not configured and local files are missing."
        echo "!!! Please either upload .zshrc/.p10k.zsh with this script OR set REPO_URL."
        exit 1
    fi
    curl -fsSL "$REPO_URL/.zshrc" -o "$HOME/.zshrc"
    curl -fsSL "$REPO_URL/.p10k.zsh" -o "$HOME/.p10k.zsh"
fi

echo ">>> Configuration installed."

# 6. Set Default Shell
current_shell=$(basename "$SHELL")
if [ "$current_shell" != "zsh" ]; then
    echo ">>> Changing default shell to zsh..."
    chsh -s $(which zsh)
fi

echo ">>> Setup complete! Please restart your terminal."
