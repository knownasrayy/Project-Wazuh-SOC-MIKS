# Group Task #2 — SIEM Maintenance & SOAR Integration
> Wazuh + Shuffle | Automated DDoS Detection & Mitigation

---

## 📋 Overview

Task ini merupakan kelanjutan dari Group Task #1 (setup Wazuh SIEM). Pada Task #2, tim melakukan dua hal utama:
1. **Maintenance** infrastruktur Wazuh yang sudah berjalan
2. **Integrasi SOAR** (Shuffle) untuk otomasi deteksi dan mitigasi serangan DDoS secara end-to-end

**SOAR Tool yang digunakan:** [Shuffle](https://github.com/Shuffle/Shuffle)  
Alasan: open source, gratis, mudah diintegrasikan dengan Wazuh, dan mendukung visual workflow drag-and-drop.

---

## 🏗️ Arsitektur Sistem

```
VM3 (Attacker)
      │  hping3 flood
      ▼
VM2 (Target — Wazuh Agent)
      │  deteksi anomali traffic
      ▼
VM1 (Wazuh Manager + Shuffle)
      │  alert → webhook
      ▼
Shuffle (SOAR Workflow)
      │  parse → kondisi → aksi
      ▼
Active Response: auto-block IP VM3 di VM2 ✅
```

---

## 👥 Pembagian Tugas

### 🔵 Orang 1 — SIEM Maintenance

**Tanggung jawab:**
- Verifikasi Wazuh Manager tetap running di VM1
- Pastikan semua agent (VM2 & VM3) berstatus `Active`
- Review dan tuning custom rules DDoS yang sudah ada
- Pastikan Wazuh Dashboard dapat diakses

**Langkah verifikasi:**

```bash
# SSH ke VM1
ssh -i ~/miks-key.pem azureuser@4.194.10.103

# Cek status Wazuh Manager
sudo systemctl status wazuh-manager

# Cek semua agent terdaftar
sudo /var/ossec/bin/agent_control -l
```

**Output yang diharapkan:**
- Wazuh Manager: `active (running)`
- 2 agent dengan status `Active`
- Custom rules DDoS masih terpasang dan aktif

---

### 🟡 Orang 2 — SOAR Setup (Shuffle)

**Tanggung jawab:**
- Install dan konfigurasi Shuffle di VM1
- Integrasi Wazuh → Shuffle via webhook

**Install Shuffle:**

```bash
git clone https://github.com/Shuffle/Shuffle
cd Shuffle
docker-compose up -d
```

**Integrasi ke Wazuh** — tambahkan di `/var/ossec/etc/ossec.conf`:

```xml
<integration>
  <name>shuffle</name>
  <hook_url>http://localhost:3001/api/v1/hooks/YOUR_HOOK_ID</hook_url>
  <level>10</level>
  <rule_id>100100</rule_id>
  <alert_format>json</alert_format>
</integration>
```

> ⚠️ Ganti `YOUR_HOOK_ID` dengan hook ID yang didapat dari Shuffle UI setelah membuat workflow.

**Output yang diharapkan:**
- Shuffle running via Docker
- Wazuh berhasil mengirim alert ke Shuffle melalui webhook

---

### 🟠 Orang 3 — Automated Detection Workflow

**Tanggung jawab:**
- Buat workflow di Shuffle: Wazuh alert → parse → notifikasi
- Testing trigger otomatis saat DDoS berlangsung

**Alur workflow Shuffle:**

```
[Webhook Trigger]
      ↓
[Parse Alert JSON]
      ↓
[Kondisi: rule.groups == "ddos" ?]
      ↓ YES
[Send Notification] → email / Slack / log
```

**Simulasi DDoS untuk testing** (dari VM3):

```bash
sudo hping3 -S --flood -V -p 80 20.212.154.248
```

Setelah simulasi berjalan, verifikasi apakah alert dari Wazuh masuk ke Shuffle secara otomatis.

**Output yang diharapkan:**
- Workflow aktif di Shuffle
- Alert DDoS otomatis masuk ke Shuffle saat serangan terjadi

---

### 🔴 Orang 4 — Automated Mitigation

**Tanggung jawab:**
- Buat workflow lanjutan di Shuffle: DDoS terdeteksi → auto-block IP attacker
- Gunakan Active Response Wazuh untuk blokir IP
- Testing end-to-end: serang → deteksi → mitigasi otomatis

**Tambahkan Active Response di Wazuh** (`/var/ossec/etc/ossec.conf`):

```xml
<active-response>
  <command>firewall-drop</command>
  <location>local</location>
  <rules_id>100100</rules_id>
  <timeout>300</timeout>
</active-response>
```

**Alur workflow mitigasi di Shuffle:**

```
[Alert DDoS Masuk]
      ↓
[Extract Source IP Attacker]
      ↓
[Trigger Wazuh Active Response]
      ↓
[Auto-block IP via iptables di VM2]
      ↓
[Log Mitigation Result]
```

**Verifikasi block berhasil** (di VM2):

```bash
sudo iptables -L -n | grep <IP-VM3>
```

**Output yang diharapkan:**
- IP attacker otomatis terblokir saat DDoS terdeteksi
- Log mitigasi tercatat di Shuffle

---

## 🔁 End-to-End Flow

```
1. VM3 melancarkan serangan DDoS ke VM2
         ↓
2. Wazuh Agent di VM2 mendeteksi anomali traffic
         ↓
3. Alert dikirim ke Wazuh Manager (VM1)
         ↓
4. Wazuh men-trigger Shuffle via webhook
         ↓
5. Shuffle menjalankan workflow otomatis
         ↓
6. IP VM3 otomatis diblokir di VM2 ✅
```

---

## 🖥️ Informasi Infrastruktur

| VM | Peran | IP |
|----|-------|----|
| VM1 | Wazuh Manager + Shuffle | `4.194.10.103` |
| VM2 | Target / Wazuh Agent | `20.212.154.248` |
| VM3 | Attacker / Wazuh Agent | *(lihat konfigurasi lokal)* |

---

## ✅ Checklist Penyelesaian

- [ ] Wazuh Manager running & semua agent Active (Orang 1)
- [ ] Custom rules DDoS ter-review dan aktif (Orang 1)
- [ ] Shuffle berhasil di-install via Docker (Orang 2)
- [ ] Integrasi Wazuh → Shuffle via webhook berhasil (Orang 2)
- [ ] Workflow deteksi otomatis berjalan di Shuffle (Orang 3)
- [ ] Simulasi DDoS berhasil men-trigger alert di Shuffle (Orang 3)
- [ ] Active Response Wazuh terkonfigurasi (Orang 4)
- [ ] Workflow mitigasi otomatis berjalan (Orang 4)
- [ ] IP attacker berhasil diblokir end-to-end (Orang 4)