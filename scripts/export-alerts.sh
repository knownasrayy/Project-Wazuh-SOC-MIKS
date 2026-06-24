#!/bin/bash
# =============================================================
# Script  : export-alerts.sh
# Deskripsi: Export semua alert Wazuh dari alerts.json ke CSV
#            untuk keperluan dataset labeling (A4 - Ryy)
# Penggunaan: bash export-alerts.sh
# Jalankan di: VM1 (Wazuh Manager) — 4.194.10.103
# =============================================================

set -e

ALERTS_JSON="/var/ossec/logs/alerts/alerts.json"
OUTPUT_CSV="$HOME/dataset_raw.csv"

echo "=============================================="
echo "   Wazuh Alert Exporter — A4 Dataset Tool"
echo "=============================================="
echo ""

# Cek apakah file alerts.json ada
if [ ! -f "$ALERTS_JSON" ]; then
    echo "[-] ERROR: File $ALERTS_JSON tidak ditemukan."
    echo "    Pastikan kamu sudah SSH ke VM1 dan Wazuh Manager sudah menerima alert."
    exit 1
fi

TOTAL_LINES=$(sudo wc -l < "$ALERTS_JSON")
echo "[i] File ditemukan: $ALERTS_JSON"
echo "[i] Total baris   : $TOTAL_LINES"
echo ""

if [ "$TOTAL_LINES" -eq 0 ]; then
    echo "[-] WARNING: File alerts.json kosong. Pastikan serangan sudah dijalankan oleh A2 dan A3."
    exit 1
fi

echo "[1/2] Mengekstrak field dari alerts.json..."

# Tulis header CSV
echo "timestamp,rule_id,rule_level,rule_description,rule_groups,agent_name,agent_id,src_ip,dst_ip,dst_port,label" > "$OUTPUT_CSV"

# Parse JSON per baris menggunakan python3 (tersedia default di Ubuntu 22.04)
sudo python3 - <<'PYEOF' >> "$OUTPUT_CSV"
import json, sys

ALERTS_JSON = "/var/ossec/logs/alerts/alerts.json"
exported = 0
skipped  = 0

with open(ALERTS_JSON, "r", encoding="utf-8", errors="replace") as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            a = json.loads(line)
            ts    = a.get("timestamp", "")
            rid   = a.get("rule", {}).get("id", "")
            rlvl  = a.get("rule", {}).get("level", "")
            rdesc = a.get("rule", {}).get("description", "").replace(",", ";")
            rgrp  = "|".join(a.get("rule", {}).get("groups", []))
            aname = a.get("agent", {}).get("name", "")
            aid   = a.get("agent", {}).get("id", "")
            sip   = a.get("data", {}).get("srcip", "")
            dip   = a.get("data", {}).get("dstip", "")
            dport = a.get("data", {}).get("dstport", "")
            print(f"{ts},{rid},{rlvl},{rdesc},{rgrp},{aname},{aid},{sip},{dip},{dport},")
            exported += 1
        except Exception:
            skipped += 1

print(f"# Exported: {exported} | Skipped: {skipped}", file=__import__("sys").stderr)
PYEOF

EXPORTED=$(grep -c "^[^#]" "$OUTPUT_CSV" || true)
echo "[2/2] Export selesai."
echo ""
echo "=============================================="
echo "✅ Hasil Export"
echo "   Output file : $OUTPUT_CSV"
echo "   Total alert : $((EXPORTED - 1)) baris"
echo "=============================================="
echo ""
echo "[>] Langkah selanjutnya — jalankan di laptop kamu:"
echo "    scp -i \"miks-key.pem\" azureuser@4.194.10.103:~/dataset_raw.csv ./"
echo ""
