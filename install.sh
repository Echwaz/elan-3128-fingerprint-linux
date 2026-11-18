#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="${REPO_DIR}/build-src"

echo "=== ELAN7001 / eFSA80SC (04f3:3128) Linux Fingerprint Driver Installer ==="

if command -v pacman >/dev/null 2>&1; then
    echo "[1/5] Installing build dependencies (Arch / CachyOS)..."
    sudo pacman -S --needed --noconfirm \
        git meson ninja base-devel pkgconf \
        glib2 glib2-devel libgusb libgudev pixman nss polkit systemd \
        opencv doctest fprintd
elif command -v apt-get >/dev/null 2>&1; then
    echo "[1/5] Installing build dependencies (Debian / Ubuntu)..."
    sudo apt-get update
    sudo apt-get install -y \
        git meson ninja-build build-essential pkg-config \
        libglib2.0-dev libgusb-dev libgudev-1.0-dev libpixman-1-dev \
        libnss3-dev libpolkit-gobject-1-dev libsystemd-dev \
        libopencv-dev libdoctest-dev fprintd libpam-fprintd
elif command -v dnf >/dev/null 2>&1; then
    echo "[1/5] Installing build dependencies (Fedora)..."
    sudo dnf install -y \
        git meson ninja-build gcc gcc-c++ pkgconf-pkg-config \
        glib2-devel libgusb-devel libgudev-devel pixman-devel \
        nss-devel polkit-devel systemd-devel \
        opencv-devel doctest-devel fprintd fprintd-pam
else
    echo "Warning: Unknown package manager. Ensure libfprint + opencv + doctest build deps are installed."
fi

echo "[2/5] Preparing patched libfprint source..."
if [[ ! -d "${WORK_DIR}/libfprint" ]]; then
    mkdir -p "${WORK_DIR}"
    git clone https://github.com/goodix-fp-linux-dev/libfprint.git "${WORK_DIR}/libfprint"
fi

cd "${WORK_DIR}/libfprint"
git fetch --all
git checkout -f 07306bbc9256942595e31fb0f407b364ffa24d07
git clean -fd
git apply "${REPO_DIR}/patches/elanspi-3128-hybrid-sigfm.patch"

echo "[3/5] Building libfprint (elanspi + Hybrid Rotated-ZNCC/SIFT-RANSAC)..."
meson setup build --reconfigure --prefix=/usr/local -Ddrivers=elanspi -Dudev_rules=disabled -Ddoc=false -Dgtk-examples=false
ninja -C build

echo "[4/5] Installing library and system configuration..."
sudo systemctl stop fprintd.service || true
sudo ninja -C build install
echo "/usr/local/lib" | sudo tee /etc/ld.so.conf.d/00-libfprint-elan3128.conf >/dev/null
echo "/usr/local/lib64" | sudo tee -a /etc/ld.so.conf.d/00-libfprint-elan3128.conf >/dev/null
sudo ldconfig

sudo cp "${REPO_DIR}/system/spidev.conf" /etc/modprobe.d/spidev.conf
sudo cp "${REPO_DIR}/system/70-libfprint-elan7001.rules" /etc/udev/rules.d/70-libfprint-elan7001.rules
sudo modprobe spidev || true
sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=spi || true

echo "[5/5] Starting fprintd..."
sudo systemctl start fprintd.service

echo ""
echo "=== Installation Complete! ==="
ldconfig -p | grep libfprint-2.so.2 || true
echo ""
echo "Next steps:"
echo "  1. fprintd-delete \"\$USER\""
echo "  2. fprintd-enroll -f right-index-finger"
echo "  3. fprintd-verify"
