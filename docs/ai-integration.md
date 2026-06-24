# 🤖 Panduan Integrasi AI ke Wazuh — A6 (AI Engineer)

Dokumen ini menjelaskan langkah-langkah **end-to-end** untuk mengintegrasikan model ML dari A5 ke dalam pipeline alert Wazuh secara real-time.

---

## 🎯 Konteks & Posisi A6

| Peran | Ketergantungan |
|-------|----------------|
| **A6 — AI Integration** | Menerima model `.pkl` dari A5, infrastruktur dari A1 |
| Input | `soc_model_random_forest.pkl` + `feature_names.pkl` dari A5 |
| Output | Alert Wazuh dengan field `ai_verdict` (TP/FP) + `ai_confidence` |
| Dibutuhkan oleh | A7 (SOAR hanya proses alert TP) |

---

## 📐 Arsitektur Integrasi

```
┌──────────────────────────────────────────────────────────┐
│                    VM1 — Wazuh Manager                   │
│                     (4.194.10.103)                        │
│                                                          │
│  ┌─────────────┐    Alert     ┌──────────────────────┐  │
│  │   Wazuh     │───(stdin)───>│   ai_verdict.py      │  │
│  │   Engine    │              │   (Active Response)   │  │
│  └─────────────┘              └──────────┬───────────┘  │
│         ▲                               │ HTTP POST     │
│         │                               ▼               │
│  ┌──────┴──────┐              ┌──────────────────────┐  │
│  │ Dashboard   │              │   ai_server.py       │  │
│  │ (Indexer)   │              │   (Flask :5000)      │  │
│  └─────────────┘              │                      │  │
│         ▲                     │  ┌────────────────┐  │  │
│         │                     │  │ Random Forest  │  │  │
│  ┌──────┴──────┐              │  │ (.pkl model)   │  │  │
│  │ Rules       │<──log────────│  └────────────────┘  │  │
│  │ 100021 (TP) │              └──────────────────────┘  │
│  │ 100022 (FP) │                                        │
│  └─────────────┘                                        │
│         │                                                │
│         ▼                                                │
│  ┌─────────────┐                                        │
│  │   A7 SOAR   │  ← hanya menerima Rule 100021 (TP)    │
│  └─────────────┘                                        │
└──────────────────────────────────────────────────────────┘
```

**Alur lengkap:**
1. Alert masuk ke Wazuh Engine dari Agent (VM2/VM3)
2. Wazuh Engine trigger `ai_verdict.py` via Active Response (stdin)
3. `ai_verdict.py` forward alert ke `ai_server.py` (Flask HTTP POST)
4. Flask server extract 16 fitur, jalankan model Random Forest
5. Hasil ditulis ke `ai_verdicts.log`
6. Wazuh Engine mem-parsing log → create alert baru (Rule 100021=TP, 100022=FP)
7. Alert TP diteruskan ke SOAR (A7) untuk auto-response

---

## 📋 Prasyarat

Sebelum mulai, pastikan:
- ✅ SSH access ke VM1 (`ssh -i "miks-key.pem" azureuser@4.194.10.103`)
- ✅ Wazuh Manager sudah running (`sudo systemctl status wazuh-manager`)
- ✅ File model dari A5:
  - `soc_model_random_forest.pkl`
  - `feature_names.pkl`
- ✅ Python 3.8+ sudah terinstall di VM1

---

## Langkah 1 — Install Dependencies di VM1

SSH ke VM1:
```bash
ssh -i "miks-key.pem" azureuser@4.194.10.103
```

Install Python packages:
```bash
sudo pip3 install flask joblib scikit-learn pandas numpy
```

> Jika `pip3` belum ada:
> ```bash
> sudo apt update && sudo apt install -y python3-pip
> ```

---

## Langkah 2 — Upload File ke VM1

Dari laptop (PowerShell), upload semua file yang dibutuhkan:

```powershell
# Upload model files
scp -i "miks-key.pem" soc_model_random_forest.pkl azureuser@4.194.10.103:~/
scp -i "miks-key.pem" feature_names.pkl azureuser@4.194.10.103:~/

# Upload AI server script
scp -i "miks-key.pem" scripts/ai_server.py azureuser@4.194.10.103:~/

# Upload active response script
scp -i "miks-key.pem" scripts/ai_verdict.py azureuser@4.194.10.103:~/

# Upload config files
scp -i "miks-key.pem" config/ai_verdict_rules.xml azureuser@4.194.10.103:~/
scp -i "miks-key.pem" config/ossec_ai_integration.conf azureuser@4.194.10.103:~/
```

---

## Langkah 3 — Deploy Model & AI Server

Di VM1, pindahkan file ke lokasi yang tepat:

```bash
# 3a. Pindahkan model files ke direktori Wazuh
sudo mkdir -p /var/ossec/ai_model
sudo cp ~/soc_model_random_forest.pkl /var/ossec/ai_model/
sudo cp ~/feature_names.pkl /var/ossec/ai_model/

# 3b. Pindahkan AI server script
sudo cp ~/ai_server.py /var/ossec/ai_model/
sudo chmod 750 /var/ossec/ai_model/ai_server.py
```

---

## Langkah 4 — Deploy Active Response Script

```bash
# 4a. Copy ke Wazuh active-response directory
sudo cp ~/ai_verdict.py /var/ossec/active-response/bin/
sudo chmod 750 /var/ossec/active-response/bin/ai_verdict.py
sudo chown root:wazuh /var/ossec/active-response/bin/ai_verdict.py

# 4b. Buat file log yang dibutuhkan
sudo touch /var/ossec/logs/ai_verdicts.log
sudo chown wazuh:wazuh /var/ossec/logs/ai_verdicts.log
sudo chmod 660 /var/ossec/logs/ai_verdicts.log
```

---

## Langkah 5 — Konfigurasi Wazuh Rules

Tambahkan rules AI ke `local_rules.xml`:

```bash
# Backup dulu
sudo cp /var/ossec/etc/rules/local_rules.xml /var/ossec/etc/rules/local_rules.xml.bak

# Sisipkan rules baru (JANGAN hapus rules DDoS 100010/100011!)
# Buka editor:
sudo nano /var/ossec/etc/rules/local_rules.xml

# Tambahkan isi dari file ai_verdict_rules.xml
# SEBELUM tag </group> terakhir atau sebagai group baru.
```

Atau otomatis dengan command:
```bash
# Append AI verdict rules ke local_rules.xml
# (hanya isi <group>...</group>, tanpa komentar XML di atas)
sudo python3 -c "
rules = open('/home/azureuser/ai_verdict_rules.xml').read()
# Extract only the <group> block
import re
group = re.search(r'(<group name=\"ai_verdict.*?</group>)', rules, re.DOTALL).group(1)
with open('/var/ossec/etc/rules/local_rules.xml', 'r') as f:
    content = f.read()
# Append before the last line
with open('/var/ossec/etc/rules/local_rules.xml', 'a') as f:
    f.write('\n' + group + '\n')
print('✅ AI verdict rules ditambahkan')
"
```

---

## Langkah 6 — Konfigurasi ossec.conf

Tambahkan konfigurasi integrasi AI ke `ossec.conf`:

```bash
sudo nano /var/ossec/etc/ossec.conf
```

Sisipkan blok berikut di dalam `<ossec_config>` (sebelum tag penutup `</ossec_config>`):

```xml
<!-- ====== A6: AI Integration ====== -->

<command>
  <name>ai-verdict</name>
  <executable>ai_verdict.py</executable>
  <timeout_allowed>no</timeout_allowed>
</command>

<active-response>
  <command>ai-verdict</command>
  <location>server</location>
  <level>3</level>
</active-response>

<localfile>
  <log_format>syslog</log_format>
  <location>/var/ossec/logs/ai_verdicts.log</location>
</localfile>
```

---

## Langkah 7 — Jalankan AI Server

Start Flask AI server sebagai background process:

```bash
# Set environment variables
export SOC_MODEL_PATH="/var/ossec/ai_model/soc_model_random_forest.pkl"
export SOC_FEATURES_PATH="/var/ossec/ai_model/feature_names.pkl"

# Jalankan di background dengan nohup
sudo nohup python3 /var/ossec/ai_model/ai_server.py > /var/ossec/logs/ai_server.log 2>&1 &

# Simpan PID untuk management
echo $! | sudo tee /var/ossec/ai_model/ai_server.pid
```

Verifikasi server berjalan:
```bash
curl http://localhost:5000/health
```

Output yang diharapkan:
```json
{
  "status": "healthy",
  "model_loaded": true,
  "model_type": "RandomForestClassifier",
  "feature_count": 16
}
```

---

## Langkah 8 — Restart Wazuh Manager

```bash
sudo systemctl restart wazuh-manager
```

Verifikasi tidak ada error:
```bash
sudo tail -n 20 /var/ossec/logs/ossec.log
```

---

## Langkah 9 — Testing End-to-End

### Test 1: API langsung (tanpa Wazuh)

```bash
# Test dengan alert DDoS (expected: TP)
curl -s -X POST http://localhost:5000/predict \
  -H "Content-Type: application/json" \
  -d '{
    "timestamp": "2026-06-24T14:32:00+00:00",
    "rule": {
      "id": "100011",
      "level": 12,
      "description": "CRITICAL: Kemungkinan Serangan SYN Flood DDoS Sedang Berlangsung!",
      "groups": ["syslog", "iptables", "ddos", "attack"]
    },
    "agent": {"name": "agent-vm2", "id": "002"},
    "data": {"srcip": "10.0.0.6", "dstip": "10.0.0.5", "dstport": "80"}
  }' | python3 -m json.tool
```

Expected output:
```json
{
  "ai_verdict": "TP",
  "ai_confidence": 0.9250
}
```

```bash
# Test dengan alert normal SSH (expected: FP)
curl -s -X POST http://localhost:5000/predict \
  -H "Content-Type: application/json" \
  -d '{
    "timestamp": "2026-06-24T14:32:00+00:00",
    "rule": {
      "id": "5710",
      "level": 5,
      "description": "sshd: Attempt to login using a non-existent user",
      "groups": ["syslog", "sshd", "authentication_failed", "invalid_login"]
    },
    "agent": {"name": "agent-vm2", "id": "002"},
    "data": {"srcip": "78.186.54.65"}
  }' | python3 -m json.tool
```

Expected output:
```json
{
  "ai_verdict": "FP",
  "ai_confidence": 0.15
}
```

### Test 2: Simulasi serangan nyata

Dari VM3 (Attacker), jalankan serangan singkat:
```bash
sudo hping3 -S -p 80 -i u10000 10.0.0.5
# Tunggu 10 detik, lalu Ctrl+C
```

Di VM1, cek AI verdict log:
```bash
sudo tail -f /var/ossec/logs/ai_verdicts.log
```

Cek stats:
```bash
curl http://localhost:5000/stats | python3 -m json.tool
```

### Test 3: Verifikasi di Dashboard

Buka Wazuh Dashboard → Security events → filter rule.id = 100021

Anda seharusnya melihat alert baru dengan deskripsi:
```
🔴 AI Verdict: TRUE POSITIVE — Serangan terdeteksi dan dikonfirmasi oleh AI
```

---

## 🔧 Troubleshooting

| Masalah | Kemungkinan Penyebab | Solusi |
|---------|---------------------|--------|
| `curl: (7) Connection refused` | Flask server tidak jalan | Cek: `ps aux \| grep ai_server` lalu restart |
| `Model not loaded` di /health | Path `.pkl` salah | Cek environment variable `SOC_MODEL_PATH` |
| `sklearn version warning` | A5 train di v1.8, VM1 punya v1.9 | Ini warning saja, bisa diabaikan |
| AI verdict tidak muncul di Dashboard | Rules belum di-load | `sudo systemctl restart wazuh-manager` |
| `Permission denied` saat menulis log | File permission salah | `sudo chown wazuh:wazuh /var/ossec/logs/ai_verdicts.log` |
| Active response tidak trigger | ossec.conf belum benar | Cek `sudo cat /var/ossec/etc/ossec.conf` |

---

## 📊 Monitoring

Cek status AI server kapan saja:
```bash
# Health check
curl http://localhost:5000/health

# Statistik prediksi
curl http://localhost:5000/stats

# Log terbaru
sudo tail -20 /var/ossec/logs/ai_verdicts.log

# Log Flask server
sudo tail -20 /var/ossec/logs/ai_server.log
```

---

## 📦 Deliverables A6

| File | Lokasi di VM1 | Keterangan |
|------|--------------|------------|
| `ai_server.py` | `/var/ossec/ai_model/ai_server.py` | Flask REST API inference server |
| `ai_verdict.py` | `/var/ossec/active-response/bin/ai_verdict.py` | Wazuh Active Response script |
| `ossec_ai_integration.conf` | Dimasukkan ke `/var/ossec/etc/ossec.conf` | Konfigurasi command & active-response |
| `ai_verdict_rules.xml` | Dimasukkan ke `/var/ossec/etc/rules/local_rules.xml` | Custom rules untuk AI verdict |
| `soc_model_random_forest.pkl` | `/var/ossec/ai_model/` | Model ML dari A5 |
| `feature_names.pkl` | `/var/ossec/ai_model/` | Urutan fitur untuk inferensi |

---

*A6 — Final Project MIKS SOC 2026*
