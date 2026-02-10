#!/bin/bash

# Configuration
SOURCE_CONFIG_DIR="$HOME/zsh_config_export"
OH_MY_ZSH_DIR="$HOME/.oh-my-zsh"
OUTPUT_TAR="shell_sync_pack.tar.gz"
STAGING_DIR="staging_shell_sync"

# 1. Prepare Staging Area
echo "Cleaning up old staging area..."
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

# 2. Copy Configurations
echo "Copying configuration files..."
if [ -d "$SOURCE_CONFIG_DIR" ]; then
    cp "$SOURCE_CONFIG_DIR/.zshrc" "$STAGING_DIR/"
    cp "$SOURCE_CONFIG_DIR/.p10k.zsh" "$STAGING_DIR/"
else
    echo "Error: Source config directory $SOURCE_CONFIG_DIR not found!"
    exit 1
fi

# 3. Copy Oh My Zsh (excluding .git to save space)
echo "Copying Oh My Zsh (plugins & themes)..."
# We use rsync to exclude .git directories for a cleaner, smaller pack
rsync -av --exclude='.git' "$OH_MY_ZSH_DIR" "$STAGING_DIR/"

# 4. Create Install Script for Remote Server
echo "Generating install.sh..."
cat > "$STAGING_DIR/install.sh" << 'EOF'
#!/bin/bash
set -e

BACKUP_SUFFIX="_backup_$(date +%Y%m%d_%H%M%S)"

echo ">>> Starting Shell Configuration Installation"

# Function to backup if exists
backup_file() {
    if [ -e "$1" ]; then
        echo "Backing up $1 to $1$BACKUP_SUFFIX"
        mv "$1" "$1$BACKUP_SUFFIX"
    fi
}

# 1. Install Oh My Zsh
echo "Installing Oh My Zsh..."
if [ -d "$HOME/.oh-my-zsh" ]; then
    backup_file "$HOME/.oh-my-zsh"
fi
mv .oh-my-zsh "$HOME/"

# 2. Install Config Files
echo "Installing config files..."
backup_file "$HOME/.zshrc"
mv .zshrc "$HOME/"

backup_file "$HOME/.p10k.zsh"
mv .p10k.zsh "$HOME/"

# 3. Final steps
echo ">>> Installation complete!"
echo "If zsh is not your default shell, run: chsh -s $(which zsh)"
echo "Then restart your session or run 'zsh' to see changes."
EOF

chmod +x "$STAGING_DIR/install.sh"

# 5. Compress
echo "Creating archive $OUTPUT_TAR..."
tar -czf "$OUTPUT_TAR" -C "$STAGING_DIR" .

# 6. Cleanup
rm -rf "$STAGING_DIR"

echo ""
echo "Package created: $OUTPUT_TAR"
echo "To upload and deploy:"
echo "1. Upload: echo 'put $OUTPUT_TAR' | sftp user@host"
echo "2. Install: ssh user@host 'mkdir -p tmp_shell && tar -xzf $OUTPUT_TAR -C tmp_shell && cd tmp_shell && ./install.sh'"
