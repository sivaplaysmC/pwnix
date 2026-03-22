#!/usr/bin/env bash
set -euo pipefail

ROOTFS="$(pwd)/rootfs"
ROOT_HOME="$ROOTFS/root"
STOW_DIR="$ROOT_HOME/stow"
DOTFILES_DIR="$STOW_DIR/dotfiles"
ZSH="$ROOT_HOME/.oh-my-zsh"

log() { echo "[*] $*"; }
die() { echo "[!] $*" >&2; exit 1; }

log "Preparing rootfs..."
mkdir -p "$ROOT_HOME" "$STOW_DIR"

# --- etc files (static) ---
log "Writing /etc files..."
mkdir -p "$ROOTFS/etc"

cat > "$ROOTFS/etc/passwd" <<'EOF'
root:x:0:0:root:/root:/bin/zsh
user:x:1000:1000:user:/home/user:/bin/zsh
EOF

cat > "$ROOTFS/etc/group" <<'EOF'
root:x:0:
user:x:1000:
EOF

cat > "$ROOTFS/etc/nsswitch.conf" <<'EOF'
passwd: files
group:  files
EOF

# zprofile is NOT written here — it contains nix store paths and is
# generated at runtime by bwrap into the tmpfs overlay layer.

# --- dotfiles ---
if [ ! -d "$DOTFILES_DIR" ]; then
    log "Cloning dotfiles..."
    git clone --depth=1 https://github.com/sivaplaysmc/dotfiles "$DOTFILES_DIR"
else
    log "Updating dotfiles..."
    git -C "$DOTFILES_DIR" pull --ff-only
fi

# --- stow ---
log "Stowing packages..."
for pkg in nvim zsh tmux pwntools; do
    log "  -> $pkg"
    stow --restow --dir="$DOTFILES_DIR" --target="$ROOT_HOME" "$pkg"
done

# --- Oh My Zsh ---
log "Installing Oh My Zsh..."
if [ ! -d "$ZSH" ]; then
    git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh "$ZSH"
else
    log "Oh My Zsh already present, skipping."
fi

# Bootstrap zsh fzf tab
if [ ! -d "$ZSH/custom/plugins/fzf-tab" ]; then
    git clone --depth=1 https://github.com/Aloxaf/fzf-tab "$ZSH/custom/plugins/fzf-tab"
else
    log "fzf-tab already present, skipping."
fi

# --- neovim plugin bootstrap ---
log "Bootstrapping neovim plugins..."
mkdir -p "$ROOT_HOME/.local/share" "$ROOT_HOME/.local/state"

XDG_CONFIG_HOME="$ROOT_HOME/.config" \
XDG_DATA_HOME="$ROOT_HOME/.local/share" \
XDG_STATE_HOME="$ROOT_HOME/.local/state" \
HOME="$ROOT_HOME" \
    nvim --headless "+qa" \
    && log "neovim bootstrap ok." \
    || die "neovim bootstrap failed — check your config."

log "Done."
