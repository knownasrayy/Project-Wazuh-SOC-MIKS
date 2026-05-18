#!/bin/bash
# =============================================================
# Script  : install-manager.sh
# Deskripsi: Instalasi Wazuh Manager all-in-one di Ubuntu
# Penggunaan: sudo bash install-manager.sh
# Orang   : Orang 2 — Wazuh Manager
# =============================================================

set -e

echo "========================================"
echo "   Wazuh Manager — Installation Script"
echo "========================================"
echo ""

# Step 1: Update system
echo "[1/4] Updating system packages..."
sudo apt update && sudo apt upgrade -y
echo "✅ System updated"
echo ""

# Step 2: Download installer
echo "[2/4] Downloading Wazuh installer..."
# Penting: gunakan -sO (huruf O besar), bukan -s0 (angka nol)
curl -sO https://packages.wazuh.com/4.7/wazuh-install.sh
echo "✅ Installer downloaded"
echo ""

# Step 3: Jalankan installer all-in-one
# -a = all-in-one (Manager + Indexer + Dashboard)
# -i = ignore OS version check
echo "[3/4] Running Wazuh installer (10-20 minutes)..."
sudo bash wazuh-install.sh -a -i
echo "✅ Installation complete"
echo ""

# Step 4: Verifikasi semua service
echo "[4/4] Verifying services..."
echo ""

MANAGER_STATUS=$(sudo systemctl is-active wazuh-manager)
INDEXER_STATUS=$(sudo systemctl is-active wazuh-indexer)
DASHBOARD_STATUS=$(sudo systemctl is-active wazuh-dashboard)

echo "  wazuh-manager   : $MANAGER_STATUS"
echo "  wazuh-indexer   : $INDEXER_STATUS"
echo "  wazuh-dashboard : $DASHBOARD_STATUS"
echo ""

# Tampilkan kredensial
echo "========================================"
echo "   Credentials"
echo "========================================"
sudo tar -O -xvf wazuh-install-files.tar wazuh-install-files/wazuh-passwords.txt \
  | grep -A1 "indexer_username: 'admin'"
echo ""
echo "Dashboard URL: https://$(curl -s ifconfig.me)"
echo "========================================"
