#!/bin/bash
# =============================================================
# Script  : finalize-dataset.sh
# Deskripsi: Menggabungkan hasil auto-labeling dengan hasil
#            review manual, validasi dataset, dan simpan
#            dataset_final.csv siap kirim ke A5 (Hansen).
# Penggunaan: bash finalize-dataset.sh
# Jalankan di: Laptop (setelah review manual selesai)
# Prasyarat: python3 + pandas
# =============================================================

LABELED_CSV="dataset_labeled.csv"
AMBIGUOUS_CSV="dataset_ambiguous.csv"
FINAL_CSV="dataset_final.csv"

echo "=============================================="
echo "   Dataset Finalizer — A4 Dataset Tool"
echo "=============================================="
echo ""

if [ ! -f "$LABELED_CSV" ]; then
    echo "[-] ERROR: '$LABELED_CSV' tidak ditemukan."
    echo "    Jalankan label-dataset.sh terlebih dahulu."
    exit 1
fi

if [ ! -f "$AMBIGUOUS_CSV" ]; then
    echo "[i] Tidak ada file ambiguous — langsung finalize."
fi

python3 - "$LABELED_CSV" "$AMBIGUOUS_CSV" "$FINAL_CSV" <<'PYEOF'
import pandas as pd
import sys
import os

labeled_csv  = sys.argv[1]
ambiguous_csv = sys.argv[2]
final_csv    = sys.argv[3]

df = pd.read_csv(labeled_csv)

# Merge hasil review manual jika ada
if os.path.exists(ambiguous_csv):
    df_amb = pd.read_csv(ambiguous_csv)
    still_neg = (df_amb["label"] == -1).sum()
    if still_neg > 0:
        print(f"[-] ERROR: Masih ada {still_neg} baris berlabel -1 di {ambiguous_csv}.")
        print("    Buka file itu di Excel, isi kolom 'label' dengan 0 atau 1, lalu simpan.")
        sys.exit(1)

    # Update label di dataset utama mencocokkan timestamp dan fitur lain
    for _, row in df_amb.iterrows():
        mask = (df["timestamp"] == row["timestamp"]) & (df["rule_id"] == row["rule_id"]) & (df["hit_count_60s"] == row["hit_count_60s"])
        df.loc[mask, "label"] = row["label"]
    print(f"    Merged {len(df_amb)} baris dari review manual.")

# Validasi tidak ada label yang tersisa -1
remaining = (df["label"] == -1).sum()
if remaining > 0:
    print(f"[-] ERROR: Masih ada {remaining} baris berlabel -1. Cek ulang dataset.")
    sys.exit(1)

# Pilih kolom final
final_cols = [c for c in [
    "timestamp","rule_id","rule_level","rule_description","rule_groups",
    "agent_name","src_ip","dst_ip","dst_port","hit_count_60s","hour_of_day","label"
] if c in df.columns]

df_final = df[final_cols]

tp = (df_final["label"] == 1).sum()
fp = (df_final["label"] == 0).sum()
total = len(df_final)
ratio = tp/fp if fp > 0 else float("inf")

print("")
print("=== Statistik Dataset Final ===")
print(f"  True Positive  (serangan nyata) : {tp} baris ({tp/total*100:.1f}%)")
print(f"  False Positive (noise/normal)   : {fp} baris ({fp/total*100:.1f}%)")
print(f"  Total                           : {total} baris")
print(f"  Rasio TP:FP                     : {ratio:.2f}x")

if ratio > 3 or ratio < 0.33:
    print("  [!] Dataset tidak seimbang. Beritahu Hansen agar pakai SMOTE.")

df_final.to_csv(final_csv, index=False)
PYEOF

echo ""
echo "=============================================="
echo "✅ Dataset final tersimpan: $FINAL_CSV"
echo "=============================================="
echo ""
echo "[>] Kirim ke Hansen (A5):"
echo "    1. $FINAL_CSV"
echo "    2. docs/dataset-labeling.md  (dokumen kriteria FP/TP)"
echo ""
