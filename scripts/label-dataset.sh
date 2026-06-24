#!/bin/bash
# =============================================================
# Script  : label-dataset.sh
# Deskripsi: Auto-labeling dataset alert Wazuh berdasarkan
#            kriteria FP/TP yang sudah didefinisikan.
#            Label 1 = True Positive (serangan nyata)
#            Label 0 = False Positive (noise/normal)
#            Label -1 = Ambiguous (perlu review manual di Excel)
# Penggunaan: bash label-dataset.sh [input.csv] [output.csv]
# Jalankan di: Laptop (setelah download dataset_raw.csv dari VM1)
# Prasyarat: python3 + pandas  →  pip install pandas
# =============================================================

INPUT_CSV="${1:-dataset_raw.csv}"
OUTPUT_LABELED="${2:-dataset_labeled.csv}"
OUTPUT_AMBIGUOUS="dataset_ambiguous.csv"
OUTPUT_FINAL="dataset_final.csv"

echo "=============================================="
echo "   Wazuh Dataset Labeler — A4 Dataset Tool"
echo "=============================================="
echo ""

# Cek python3
if ! command -v python3 &> /dev/null; then
    echo "[-] python3 tidak ditemukan. Install dulu:"
    echo "    https://www.python.org/downloads/"
    exit 1
fi

# Cek pandas
python3 -c "import pandas" 2>/dev/null || {
    echo "[i] pandas belum terinstall. Installing..."
    pip install pandas
}

# Cek file input
if [ ! -f "$INPUT_CSV" ]; then
    echo "[-] ERROR: File '$INPUT_CSV' tidak ditemukan."
    echo "    Pastikan kamu sudah download dataset_raw.csv dari VM1:"
    echo "    scp -i miks-key.pem azureuser@4.194.10.103:~/dataset_raw.csv ./"
    exit 1
fi

echo "[i] Input file  : $INPUT_CSV"
echo "[i] Output file : $OUTPUT_LABELED"
echo ""

echo "[1/3] Menghitung hit_count_60s dan hour_of_day..."
echo "[2/3] Menjalankan auto-labeling..."

python3 - "$INPUT_CSV" "$OUTPUT_LABELED" "$OUTPUT_AMBIGUOUS" <<'PYEOF'
import pandas as pd
import sys

input_csv      = sys.argv[1]
output_labeled = sys.argv[2]
output_ambig   = sys.argv[3]

df = pd.read_csv(input_csv)
print(f"    Loaded {len(df)} baris dari {input_csv}")

# ── FEATURE ENGINEERING ──────────────────────────────────────
df["timestamp"] = pd.to_datetime(df["timestamp"], errors="coerce")
df = df.dropna(subset=["timestamp"]).sort_values("timestamp").reset_index(drop=True)

# hit_count_60s: berapa kali src_ip yang sama muncul dalam 60 detik terakhir
window = pd.Timedelta(seconds=60)
hit_counts = []
for idx, row in df.iterrows():
    if pd.isna(row.get("src_ip")) or str(row["src_ip"]).strip() == "":
        hit_counts.append(0)
        continue
    mask = (
        (df["src_ip"] == row["src_ip"]) &
        (df["timestamp"] >= row["timestamp"] - window) &
        (df["timestamp"] <= row["timestamp"])
    )
    hit_counts.append(mask.sum())

df["hit_count_60s"] = hit_counts
df["hour_of_day"]   = df["timestamp"].dt.hour

# ── AUTO-LABELING ─────────────────────────────────────────────
# Berdasarkan custom rule project MIKS:
#   100010  level 6   = deteksi awal SYN flood (bisa FP)
#   100011  level 12  = eskalasi: >20 hit/60s, same IP (pasti TP)
#
# Strategi: gunakan semua sinyal yang tersedia (rule_id, level,
# groups, hit_count, DAN teks rule_description) agar zone
# ambiguous sekecil mungkin → manual review hampir nol.

import re

# Kata kunci di rule_description yang menandakan SERANGAN
TP_DESC_KEYWORDS = [
    "flood", "syn", "ddos", "dos", "attack", "exploit",
    "brute", "scan", "injection", "malware", "trojan",
    "backdoor", "ransomware", "overflow", "intrusion",
    "critical", "kritis", "serangan", "penyerang"
]

# Kata kunci di rule_description yang menandakan EVENT NORMAL
FP_DESC_KEYWORDS = [
    "login", "logon", "logout", "authentication success",
    "session opened", "session closed", "accepted",
    "user logged", "password changed", "service started",
    "informational", "normal", "access granted",
    "file accessed", "connection established"
]

# Rule ID yang diketahui aman (SSH/auth success, syslog info, dll.)
KNOWN_FP_RULE_IDS = {
    "5715", "5716",   # SSH auth success
    "5501", "5502",   # PAM session
    "1002",           # Unknown problem somewhere in the system
    "31100",          # Web server 200 OK
    "31101",          # Web server 400
}

# Subnet private (RFC 1918) — traffic antar VM internal bukan ancaman eksternal
PRIVATE_PREFIXES = ("10.", "172.16.", "172.17.", "172.18.", "172.19.",
                    "172.20.", "172.21.", "172.22.", "172.23.", "172.24.",
                    "172.25.", "172.26.", "172.27.", "172.28.", "172.29.",
                    "172.30.", "172.31.", "192.168.")


def is_private_ip(ip: str) -> bool:
    return any(ip.startswith(p) for p in PRIVATE_PREFIXES)


def score_description(desc: str) -> int:
    """
    Hitung skor dari teks rule_description:
      +1 per kata kunci TP yang ditemukan
      -1 per kata kunci FP yang ditemukan
    Skor > 0  → cenderung TP
    Skor < 0  → cenderung FP
    Skor = 0  → netral
    """
    desc_lower = desc.lower()
    score = 0
    for kw in TP_DESC_KEYWORDS:
        if kw in desc_lower:
            score += 1
    for kw in FP_DESC_KEYWORDS:
        if kw in desc_lower:
            score -= 1
    return score


def label_row(row):
    rule_id    = str(row.get("rule_id", "")).strip()
    desc       = str(row.get("rule_description", ""))
    groups     = str(row.get("rule_groups", "")).lower()
    src_ip     = str(row.get("src_ip", "")).strip()
    dst_ip     = str(row.get("dst_ip", "")).strip()
    agent_name = str(row.get("agent_name", "")).lower()

    try:
        rule_level = int(row["rule_level"])
    except (ValueError, TypeError):
        rule_level = 0

    try:
        hit_count = int(row.get("hit_count_60s", 0))
    except (ValueError, TypeError):
        hit_count = 0

    desc_score = score_description(desc)

    # ══════════════════════════════════════════════════════════
    # LAYER 1: Rule ID yang pasti (deterministik, prioritas utama)
    # ══════════════════════════════════════════════════════════

    # TP pasti — rule 100011 threshold sudah terpenuhi
    if rule_id == "100011":
        return 1

    # FP pasti — rule ID yang diketahui aman
    if rule_id in KNOWN_FP_RULE_IDS:
        return 0

    # ══════════════════════════════════════════════════════════
    # LAYER 2: Rule level + groups (sinyal kekuatan serangan)
    # ══════════════════════════════════════════════════════════

    # TP — level kritis + kategori serangan
    if rule_level >= 10 and any(k in groups for k in ["attack", "ddos", "malware", "exploit"]):
        return 1

    # FP — level sangat rendah = noise informatif
    if rule_level < 4:
        return 0

    # ══════════════════════════════════════════════════════════
    # LAYER 3: IP heuristics
    # ══════════════════════════════════════════════════════════

    # FP — loopback (pengirim = penerima)
    if src_ip and dst_ip and src_ip == dst_ip:
        return 0

    # FP — traffic antar IP private internal saja (bukan dari attacker eksternal)
    # Catatan: attacker VM3 ada di 10.0.0.6 (internal), tapi rule 100011 sudah
    # handle itu di Layer 1. Di sini kita tangani traffic non-attack internal.
    if src_ip and is_private_ip(src_ip) and hit_count < 5 and rule_level < 7:
        return 0

    # ══════════════════════════════════════════════════════════
    # LAYER 4: hit_count_60s (frekuensi = indikator kuat)
    # ══════════════════════════════════════════════════════════

    # TP — frekuensi sangat tinggi, hampir pasti flooding
    if hit_count >= 20:
        return 1

    # FP — frekuensi sangat rendah, jauh dari threshold
    if rule_id == "100010" and hit_count < 5:
        return 0

    # TP — frekuensi tinggi + sedikit sinyal attack di description
    if hit_count >= 10 and desc_score > 0:
        return 1

    # FP — frekuensi rendah + description jelas event normal
    if hit_count < 5 and desc_score < 0:
        return 0

    # ══════════════════════════════════════════════════════════
    # LAYER 5: Analisis teks rule_description
    # ══════════════════════════════════════════════════════════

    # TP — deskripsi jelas menyebut serangan
    if desc_score >= 2:
        return 1

    # FP — deskripsi jelas event normal/biasa
    if desc_score <= -2:
        return 0

    # TP — level medium tapi deskripsi ada sinyal attack
    if rule_level >= 7 and desc_score > 0:
        return 1

    # FP — level medium tapi deskripsi jelas normal
    if rule_level <= 6 and desc_score < 0:
        return 0

    # ══════════════════════════════════════════════════════════
    # LAYER 6: Fallback berdasarkan level saja
    # (sudah sangat sedikit yang sampai sini)
    # ══════════════════════════════════════════════════════════

    # TP — level tinggi meski group/desc tidak jelas
    if rule_level >= 10:
        return 1

    # FP — level rendah-medium tanpa sinyal apapun
    if rule_level <= 5:
        return 0

    # Benar-benar ambiguous (level 6-9, desc netral, hit_count 5-9)
    return -1

df["label"] = df.apply(label_row, axis=1)

tp  = (df["label"] == 1).sum()
fp  = (df["label"] == 0).sum()
amb = (df["label"] == -1).sum()

print(f"    True Positive  (label=1) : {tp}")
print(f"    False Positive (label=0) : {fp}")
print(f"    Ambiguous      (label=-1): {amb}  ← perlu review manual")

# Simpan semua + yang ambiguous terpisah
df.to_csv(output_labeled, index=False)
df[df["label"] == -1].to_csv(output_ambig, index=False)

if tp < 200:
    print(f"[!] WARNING: TP hanya {tp}. Minta A2 jalankan hping3 lebih lama.")
if fp < 200:
    print(f"[!] WARNING: FP hanya {fp}. Butuh lebih banyak data baseline normal.")
PYEOF

echo ""
echo "[3/3] Done."
echo ""
echo "=============================================="
echo "✅ Hasil Labeling"
echo "   Semua baris    : $OUTPUT_LABELED"
echo "   Perlu review   : $OUTPUT_AMBIGUOUS"
echo "=============================================="
echo ""
echo "[>] Langkah selanjutnya:"
echo "    1. Buka $OUTPUT_AMBIGUOUS di Excel"
echo "    2. Isi kolom 'label' yang masih -1 dengan 0 atau 1"
echo "    3. Simpan kembali sebagai $OUTPUT_AMBIGUOUS"
echo "    4. Jalankan: bash finalize-dataset.sh"
echo ""
