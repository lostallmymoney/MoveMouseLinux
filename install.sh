#!/bin/sh
# POSIX-compliant installer for mouseMoveUtility daemon
# Run as a normal user (not root)

set -eu

# Abort if run as root
if [ "$(id -u)" -eq 0 ]; then
    echo "Do NOT run this script as root. Run it as your normal user."
    exit 1
fi

INSTALL_USER="${USER:-$(id -un)}"

echo "[+] Installing mouseMoveUtility utility (as $INSTALL_USER)"

echo "[+] Stopping and disabling any existing mouseMoveUtility service..."
sudo systemctl stop mouseMoveUtility.service || true
sudo systemctl disable mouseMoveUtility.service || true
# -----------------------------------------------------------------------------
# 1. Ensure g++ exists (Debian/Ubuntu)
# -----------------------------------------------------------------------------
echo "[+] Ensuring g++ is installed..."
if ! command -v g++ >/dev/null 2>&1; then
    if command -v apt-get >/dev/null 2>&1; then
        echo "    Installing g++ (sudo required)..."
        sudo apt-get update -y
        sudo apt-get install -y g++
    else
        echo "ERROR: g++ not found; please install manually."
        exit 1
    fi
fi

# -----------------------------------------------------------------------------
# 2. Build daemon
# -----------------------------------------------------------------------------
echo "[+] Building mouseMoveUtility..."
if [ ! -f mouseMoveUtility.cpp ]; then
    echo "ERROR: mouseMoveUtility.cpp not found in $(pwd)"
    exit 1
fi

g++ -Ofast -march=native -flto -DNDEBUG -Wall -pipe -o mouseMoveUtility mouseMoveUtility.cpp
echo "    Build complete: ./mouseMoveUtility"

# -----------------------------------------------------------------------------
# 3. Install binary to /usr/local/bin
# -----------------------------------------------------------------------------
echo "[+] Installing binary to /usr/local/bin..."
sudo mv -f mouseMoveUtility /usr/local/bin/mouseMoveUtility
sudo chmod 755 /usr/local/bin/mouseMoveUtility

# -----------------------------------------------------------------------------
# 4. Create group mouseMoveUtility
# -----------------------------------------------------------------------------
echo "[+] Creating mouseMoveUtility group (if missing)..."
if ! getent group mouseMoveUtility >/dev/null 2>&1; then
    sudo groupadd mouseMoveUtility
else
    echo "    Group already exists."
fi

# -----------------------------------------------------------------------------
# 5. Udev rule for /dev/uinput access
# -----------------------------------------------------------------------------
echo "[+] Installing udev rule for /dev/uinput..."
sudo sh -c 'cat >/etc/udev/rules.d/99-mouseMoveUtility.rules <<EOF
KERNEL=="uinput", GROUP="mouseMoveUtility", MODE="0660"
EOF'

sudo udevadm control --reload-rules
sudo udevadm trigger

# -----------------------------------------------------------------------------
# 6. Systemd service (FIFO creation MOVED HERE)
# -----------------------------------------------------------------------------
SERVICE="/etc/systemd/system/mouseMoveUtility.service"
echo "[+] Installing systemd service $SERVICE..."

sudo sh -c "cat >$SERVICE <<EOF
[Unit]
Description=Mouse Center Absolute Pointer Daemon
After=systemd-udevd.service
Wants=systemd-udevd.service

[Service]
Type=simple

ExecStartPre=/bin/mkdir -p /run/mouseMoveUtility
ExecStartPre=/bin/rm -f /run/mouseMoveUtility/mc.pipe
ExecStartPre=/usr/bin/mkfifo -m 660 /run/mouseMoveUtility/mc.pipe
ExecStartPre=/bin/chgrp mouseMoveUtility /run/mouseMoveUtility/mc.pipe

ExecStart=/usr/local/bin/mouseMoveUtility /run/mouseMoveUtility/mc.pipe

User=$INSTALL_USER
Group=mouseMoveUtility
Restart=always
RestartSec=1

RuntimeDirectory=mouseMoveUtility
RuntimeDirectoryMode=0770

[Install]
WantedBy=multi-user.target
EOF"

# -----------------------------------------------------------------------------
# 7. Enable + start service
# -----------------------------------------------------------------------------
echo "[+] Reloading systemd..."
sudo systemctl daemon-reload
sudo systemctl enable --now mouseMoveUtility.service

# -----------------------------------------------------------------------------
# 8. Adjust /dev/uinput permissions if present
# -----------------------------------------------------------------------------
if [ -e /dev/uinput ]; then
    echo "[+] Setting /dev/uinput group to mouseMoveUtility"
    sudo chgrp mouseMoveUtility /dev/uinput || true
    sudo chmod 660 /dev/uinput || true
else
    echo "NOTE: /dev/uinput not currently present. Rule will apply when it appears."
fi

# -----------------------------------------------------------------------------
# 9. Add user to group
# -----------------------------------------------------------------------------
echo "[+] Adding $INSTALL_USER to mouseMoveUtility group..."
sudo usermod -aG mouseMoveUtility "$INSTALL_USER"

# -----------------------------------------------------------------------------
# Finished
# -----------------------------------------------------------------------------
echo
echo "=============================================================="
echo "[+] Installation complete!"
echo
echo "You MUST log out and log back in for group membership to apply."
echo
echo "After re-login, test WITHOUT sudo:"
echo "    echo \"movetocenter\" > /run/mouseMoveUtility/mc.pipe"
echo "    echo \"moveto 0.5 0.5\" > /run/mouseMoveUtility/mc.pipe"
echo
echo "To check service status:"
echo "    systemctl status mouseMoveUtility.service"
echo
echo "=============================================================="
exit 0
