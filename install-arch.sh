#!/usr/bin/env bash
set -euo pipefail

"elipsis shell arch installer"

check_distro() {
    if ! command -v pacman &>/dev/null; then
        echo "Error: This script is for Arch Linux and its derivatives only."
        echo "No pacman package manager found."
        exit 1
    fi
}
check_distro

echo "==> Installing core dependencies..."

sudo pacman -S --needed --noconfirm \
    hyprland \
    qt6-base \
    qt6-declarative \
    qt6-5compat \
    qt6-svg \
    qt6-labs-folderlistmodel \
    breeze-icons \
    networkmanager \
    bluez \
    bluez-utils \
    pipewire \
    pipewire-audio \
    wireplumber \
    upower \
    imagemagick \
    procps-ng \
    hypridle \
    systemd \
    kitty \
    nautilus \
    brightnessctl \
    playerctl \
    grim \
    hyprpicker \
    xdg-desktop-portal-hyprland \
    hyprshutdown

echo "==> Installing AUR packages..."

if ! command -v yay &>/dev/null && ! command -v paru &>/dev/null; then
    echo "No AUR helper found (yay/paru). Install one first:"
    echo "  sudo pacman -S --needed git base-devel"
    echo "  git clone https://aur.archlinux.org/yay.git /tmp/yay && cd /tmp/yay && makepkg -si"
    exit 1
fi

AUR_HELPER=$(command -v yay || command -v paru)

$AUR_HELPER -S --needed --noconfirm \
    quickshell-git \
    gpu-screen-recorder \
    awww \
    vicinae-bin

echo "==> Enabling system services..."

sudo systemctl enable --now NetworkManager
sudo systemctl enable --now bluetooth
sudo systemctl enable --now pipewire pipewire-pulse wireplumber
sudo systemctl enable --now upower
sudo systemctl enable --now hypridle
systemctl enable --now --user vicinae

echo "==> Deploying configs..."
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_DIR="$HOME/.config.bak.$(date +%Y%m%d-%H%M%S)"

if [ -d "$HOME/.config" ]; then
    echo "  Backing up ~/.config -> $BACKUP_DIR"
    cp -r "$HOME/.config" "$BACKUP_DIR"
fi

echo "  Copying project .config/ to ~/.config/"
cp -r "$SCRIPT_DIR/.config/"* "$HOME/.config/"

sudo usermod -a -G video,input "$USER"

echo "==> Setup complete."
echo "Remember to change your display scaling in .config/hypr/hyprland/monitors.lua"
echo "  Reboot in 5 seconds."
sleep 5
reboot
