#!/bin/sh
# POSIX-compliant uninstaller for mouseMoveUtility daemon
# Run as a normal user

set -eu

SERVICE="/etc/systemd/system/mouseMoveUtility.service"
UDEV_RULE="/etc/udev/rules.d/99-mouseMoveUtility.rules"
BINARY="/usr/local/bin/mouseMoveUtility"
GROUP="mouseMoveUtility"

echo "[+] mouseMoveUtility uninstall utility"
echo

# -----------------------------------------------------------------------------
# 1. Stop + disable systemd service
# -----------------------------------------------------------------------------
echo "[+] Disabling systemd service..."

if systemctl is-active --quiet mouseMoveUtility.service; then
    sudo systemctl stop mouseMoveUtility.service || true
fi

if systemctl is-enabled --quiet mouseMoveUtility.service; then
    sudo systemctl disable mouseMoveUtility.service || true
fi

# -----------------------------------------------------------------------------
# 2. Remove systemd unit
# -----------------------------------------------------------------------------
if [ -f "$SERVICE" ]; then
    echo "[+] Removing $SERVICE"
    sudo rm -f "$SERVICE"
else
    echo "    Service file not found."
fi

# Reload systemd units
sudo systemctl daemon-reload
echo "    Systemd reloaded."

# -----------------------------------------------------------------------------
# 3. Remove installed binary
# -----------------------------------------------------------------------------
if [ -x "$BINARY" ]; then
    echo "[+] Removing $BINARY"
    sudo rm -f "$BINARY"
else
    echo "    Binary not found."
fi

# -----------------------------------------------------------------------------
# 4. Remove udev rule
# -----------------------------------------------------------------------------
if [ -f "$UDEV_RULE" ]; then
    echo "[+] Removing $UDEV_RULE"
    sudo rm -f "$UDEV_RULE"
    sudo udevadm control --reload-rules
    sudo udevadm trigger
    echo "    Udev rules reloaded."
else
    echo "    Udev rule not found."
fi

# -----------------------------------------------------------------------------
# 5. Optionally remove group
# -----------------------------------------------------------------------------
if getent group "$GROUP" >/dev/null 2>&1; then
    echo
    printf "Do you want to remove the system group '%s'? [y/N] " "$GROUP"
    read ans
    case "$ans" in
        y|Y|yes|YES)
            sudo groupdel "$GROUP" || true
            echo "    Group removed."
            ;;
        *)
            echo "    Group kept."
            ;;
    esac
else
    echo "    Group not found."
fi

# -----------------------------------------------------------------------------
# 6. Clean leftover runtime directory (if present)
# -----------------------------------------------------------------------------
if [ -d /run/user/1000/mouseMoveUtility ]; then
    echo "[+] Cleaning leftover /run/user/1000/mouseMoveUtility"
    sudo rm -rf /run/user/1000/mouseMoveUtility || true
fi

echo
echo "=============================================================="
echo "[+] Uninstallation complete!"
echo
echo "NOTE: You may need to log out and back in to refresh groups."
echo "=============================================================="
