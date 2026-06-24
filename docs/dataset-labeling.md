# 🏷️ Panduan Labeling Dataset — A4 (SOC Analyst)

Dokumen ini menjelaskan langkah-langkah **end-to-end** proses pengumpulan, pemrosesan, dan pelabelan dataset alert Wazuh untuk keperluan training model Machine Learning (A5 — Hansen).

---

## 🎯 Konteks & Posisi A4

| Peran | Orang | Ketergantungan |
|-------|-------|----------------|
| **A4** | Ryy | Menerima data dari A2 (Nadkir) + A3 (CC), mengirim ke A5 (Hansen) |
| Input | Alert Wazuh dari serangan A2 & A3 | Harus tunggu A2+A3 selesai |
| Output | `dataset_final.csv` + dokumen kriteria | Dikirim ke Hansen untuk training |

> ⚠️ **A4 adalah bottleneck**: Hansen (A5) tidak bisa mulai training sebelum dataset selesai dilabeli.

---

## 📋 Prasyarat

Sebelum mulai, pastikan sudah menerima dari A1 (Rais):
- ✅ File SSH key `miks-key.pem`
- ✅ Konfirmasi VM1 sudah **Running** (`4.194.10.103`)
- ✅ A2 (Nadkir) dan A3 (CC) sudah selesai menjalankan semua skenario serangan

---

## Langkah 1 — SSH ke VM1 & Cek Alert

Buka **PowerShell** di laptop:

```powershell
# SSH ke VM1 (Wazuh Manager)
ssh -i "miks-key.pem" azureuser@4.194.10.103
```

Setelah masuk ke VM1, cek apakah alert sudah ada:

```bash
sudo wc -l /var/ossec/logs/alerts/alerts.json
```

> Angka di atas nol berarti data siap diekspor. Kalau masih 0, serangan A2/A3 belum ke-log — minta mereka cek ulang.

Cek contoh isi alert (opsional, untuk memastikan format):

```bash
sudo tail -n 5 /var/ossec/logs/alerts/alerts.json | python3 -m json.tool
```

---

## Langkah 2 — Upload & Jalankan Script Export (di VM1)

Upload script dari laptop ke VM1:

```powershell
# Jalankan di PowerShell laptop
scp -i "miks-key.pem" scripts/export-alerts.sh azureuser@4.194.10.103:~/
```

Masuk ke VM1 dan jalankan:

```bash
chmod +x export-alerts.sh
bash export-alerts.sh
```

Output yang diharapkan:
```
==============================================
✅ Hasil Export
   Output file : /home/azureuser/dataset_raw.csv
   Total alert : 850 baris
==============================================
```

---

## Langkah 3 — Download CSV ke Laptop

Kembali ke PowerShell di laptop:

```powershell
scp -i "miks-key.pem" azureuser@4.194.10.103:~/dataset_raw.csv ./
```

Verifikasi file berhasil didownload:

```powershell
Get-Item dataset_raw.csv
```

---

## Langkah 4 — Jalankan Auto-Labeling (di Laptop)

```bash
# Jalankan di terminal laptop (WSL/Git Bash/PowerShell)
bash scripts/label-dataset.sh
```

Script ini otomatis:
1. Menghitung kolom `hit_count_60s` (feature engineering)
2. Menambahkan kolom `hour_of_day`
3. Memberi label `1`, `0`, atau `-1` berdasarkan kriteria FP/TP

Output yang diharapkan:
```
    Loaded 850 baris dari dataset_raw.csv
    True Positive  (label=1) : 412
    False Positive (label=0) : 380
    Ambiguous      (label=-1): 58  ← perlu review manual
```

File yang dihasilkan:
- `dataset_labeled.csv` — semua baris dengan label otomatis
- `dataset_ambiguous.csv` — hanya baris yang perlu review manual

---

## Langkah 5 — Review Manual (di Excel)

> **Mengapa ada review manual?**
> Script sudah menggunakan **6 layer analisis otomatis** — rule ID, level, groups, IP heuristics, frekuensi, dan analisis teks deskripsi. Baris yang sampai ke tahap ini adalah kasus yang benar-benar memerlukan konteks manusia: misalnya `rule_level = 7`, `hit_count_60s = 8`, deskripsi netral — tidak ada sinyal yang cukup kuat ke salah satu arah. Jika dipaksakan otomatis, risiko salah label yang merusak training model.
>
> **Dalam praktiknya ini sangat sedikit** — biasanya < 5% dari total data.

Jika `dataset_ambiguous.csv` **kosong atau tidak ada**, kamu bisa skip langkah ini langsung ke Langkah 6.

Jika ada isinya:
1. Buka `dataset_ambiguous.csv` di **Excel** atau **Google Sheets**
2. Untuk setiap baris, cek dua kolom ini:
   - `hit_count_60s` — nilai ≥ 10 cenderung TP, < 5 cenderung FP
   - `rule_description` — ada kata "flood/syn/attack" → TP; ada "success/session/accepted" → FP
3. Isi kolom `label` dengan `1` (TP) atau `0` (FP)
4. **Simpan kembali** sebagai `dataset_ambiguous.csv` (format CSV, bukan Excel .xlsx)

Referensi kriteria lengkap: lihat [Kriteria FP & TP](#-kriteria-false-positive--true-positive) di bawah.

---

## Langkah 6 — Finalisasi Dataset

```bash
bash scripts/finalize-dataset.sh
```

Output yang diharapkan:
```
=== Statistik Dataset Final ===
  True Positive  (serangan nyata) : 430 baris (51.2%)
  False Positive (noise/normal)   : 410 baris (48.8%)
  Total                           : 840 baris
  Rasio TP:FP                     : 1.05x
```

File output: **`dataset_final.csv`** ← ini yang dikirim ke Hansen.

---

## Langkah 7 — Serah Terima ke Hansen (A5)

Kirim dua file ke Hansen:

| File | Keterangan |
|------|------------|
| `dataset_final.csv` | Dataset berlabel, siap training |
| `docs/dataset-labeling.md` | Dokumen ini — kriteria FP/TP untuk referensi evaluasi model |

Sertakan juga statistik distribusi:
```
Dataset A4 — FP MIKS 2026
Total  : 840 baris
TP (1) : 430 (51.2%)  — dari skenario DDoS A2 + Malware A3
FP (0) : 410 (48.8%)  — dari traffic baseline + rule 100010 level rendah
Kolom  : timestamp, rule_id, rule_level, rule_description, rule_groups,
         agent_name, src_ip, dst_ip, dst_port, hit_count_60s, hour_of_day, label
```

---

## 🔴 Kriteria False Positive & True Positive

Kriteria ini dibuat berdasarkan **custom rule asli** project MIKS yang ada di `/var/ossec/etc/rules/local_rules.xml`:

```xml
<!-- Rule 100010 — Level 6: Deteksi awal, belum tentu serangan -->
<rule id="100010" level="6">
  <if_sid>4100</if_sid>
  <match>SYN-Flood-Detect:</match>
</rule>

<!-- Rule 100011 — Level 12: PASTI serangan (>20 hit/60s, same IP) -->
<rule id="100011" level="12" frequency="20" timeframe="60">
  <if_matched_sid>100010</if_matched_sid>
  <same_source_ip />
  <group>attack,ddos,</group>
</rule>
```

### False Positive (Label = 0)

| Kriteria | Kondisi | Alasan |
|----------|---------|--------|
| **FP-1** | `rule_id = 100010` AND `hit_count_60s < 5` | Rule 100010 trigger dari 1 paket saja — bisa traffic biasa. Belum eskalasi ke 100011. |
| **FP-2** | `rule_level < 4` | Level sangat rendah = noise informasional (login sukses, akses file, dsb.) |
| **FP-3** | `src_ip == dst_ip` | Loopback — pengirim dan penerima mesin yang sama, traffic internal legitimate |

### True Positive (Label = 1)

| Kriteria | Kondisi | Alasan |
|----------|---------|--------|
| **TP-1** | `rule_id = 100011` | Threshold ketat terpenuhi: >20 paket SYN/60s dari IP yang sama. Pasti serangan. |
| **TP-2** | `rule_level >= 10` AND `rule_groups` mengandung `attack` atau `ddos` | Level kritis + kategori serangan = ancaman nyata terkonfirmasi |

### Ambiguous (Label = -1, perlu review manual)

| Kondisi | Kemungkinan |
|---------|-------------|
| `rule_id = 100010` AND `hit_count_60s >= 15` | Bisa FP (spike sesaat) atau awal serangan yang terhenti |
| `rule_level` antara 4–9, tanpa keyword attack | Alert medium — cek `rule_description` untuk memutuskan |

---

## 📊 Skema Kolom Dataset Final

| Kolom | Tipe | Sumber | Keterangan |
|-------|------|--------|------------|
| `timestamp` | datetime | Wazuh | Waktu alert terjadi |
| `rule_id` | int | Wazuh | ID rule yang terpicu |
| `rule_level` | int | Wazuh | Tingkat keparahan (1–15) |
| `rule_description` | str | Wazuh | Deskripsi rule |
| `rule_groups` | str | Wazuh | Kategori (ddos, attack, syslog, dll.) |
| `agent_name` | str | Wazuh | Nama VM yang mengirim alert |
| `src_ip` | str | Wazuh | IP asal paket/koneksi |
| `dst_ip` | str | Wazuh | IP tujuan paket/koneksi |
| `dst_port` | int | Wazuh | Port tujuan |
| `hit_count_60s` | int | **A4** | Jumlah alert dari src_ip yang sama dalam 60 detik *(feature engineering)* |
| `hour_of_day` | int | **A4** | Jam kejadian 0–23 *(feature engineering)* |
| `label` | int | **A4** | **0** = FP, **1** = TP |

---

## 🔧 Troubleshooting

| Masalah | Kemungkinan Penyebab | Solusi |
|---------|---------------------|--------|
| `alerts.json` kosong (0 baris) | A2/A3 belum jalankan serangan | Koordinasi ulang dengan A2 (Nadkir) dan A3 (CC) |
| TP sangat sedikit (< 200) | Serangan terlalu singkat | Minta A2 jalankan `hping3 --flood` lebih lama (30–60 detik) |
| FP sangat sedikit (< 200) | Terlalu banyak serangan, sedikit baseline | Minta A2 ada periode non-attack agar alert normal ter-record |
| `Permission denied` di VM1 | Lupa `sudo` | Tambahkan `sudo` di depan perintah di VM1 |
| `pandas not found` | Belum install library | `pip install pandas` di laptop |
| Dataset imbalanced | Rasio TP:FP > 3x atau < 0.33x | Beritahu Hansen untuk gunakan teknik SMOTE |
