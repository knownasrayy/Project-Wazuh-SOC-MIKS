#!/bin/bash
# =============================================================
# Script  : install-agent.sh
# Deskripsi: Instalasi Wazuh Agent di Ubuntu (versi 4.7.5)
# Penggunaan: sudo bash install-agent.sh <AGENT_NAME>
# Orang   : Orang 3 — Wazuh Agent
# =============================================================

set -e

MANAGER_IP="4.194.10.103"
AGENT_NAME="${1:-agent-default}"
WAZUH_VERSION="4.7.5-1"

echo "========================================"
echo "   Wazuh Agent — Installation Script"
echo "========================================"
echo ""
echo "  Manager IP  : $MANAGER_IP"
echo "  Agent Name  : $AGENT_NAME"
echo "  Version     : $WAZUH_VERSION"
echo ""

# Step 1: Tambah repo Wazuh
echo "[1/4] Adding Wazuh repository..."
curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | sudo apt-key add -
echo "deb https://packages.wazuh.com/4.x/apt/ stable main" | sudo tee /etc/apt/sources.list.d/wazuh.list
sudo apt update
echo "✅ Repository added"
echo ""

# Step 2: Install agent dengan versi spesifik
echo "[2/4] Installing wazuh-agent=$WAZUH_VERSION..."
sudo WAZUH_MANAGER="$MANAGER_IP" WAZUH_AGENT_NAME="$AGENT_NAME" \
  apt-get install -y wazuh-agent=$WAZUH_VERSION
echo "✅ Agent installed"
echo ""

# Step 3: Start dan enable agent
echo "[3/4] Starting wazuh-agent service..."
sudo systemctl start wazuh-agent
sudo systemctl enable wazuh-agent
echo "✅ Service started and enabled"
echo ""

# Step 4: Verifikasi
echo "[4/4] Verifying connection to Manager..."
sleep 5
STATUS=$(sudo systemctl is-active wazuh-agent)
echo "  wazuh-agent status : $STATUS"

if sudo grep -q "Connected to the server" /var/ossec/logs/ossec.log; then
  echo "  Connection         : ✅ Connected to $MANAGER_IP"
else
  echo "  Connection         : ⏳ Waiting... cek log dengan:"
  echo "  sudo tail -20 /var/ossec/logs/ossec.log"
fi

echo ""
echo "========================================"
echo "  Agent '$AGENT_NAME' setup complete!"
echo "  Cek dashboard: https://$MANAGER_IP"
echo "========================================"
