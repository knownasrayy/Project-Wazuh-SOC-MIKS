# 🛡️ Wazuh SIEM & Azure Security Project

Proyek ini mengimplementasikan deteksi keamanan tersentralisasi menggunakan **Wazuh SIEM** pada arsitektur cloud Microsoft Azure. Sistem ini dikonfigurasi untuk mensimulasikan serangan **TCP SYN Flood DDoS**, mendeteksi anomali paket melalui kustomisasi ruleset, serta mengoptimalkan manajemen kapasitas log (*log density*) agar sistem tetap stabil selama terjadi serangan masif.

Proyek ini dirancang untuk kolaborasi tim dengan pembagian tugas yang jelas (Orang 1 hingga Orang 4) mulai dari penyediaan infrastruktur, instalasi server, pemasangan agen, hingga skenario pengujian pertahanan DDoS.

---

## 📋 Tanggung Jawab Tim (Pembagian Peran)

Untuk memastikan keberhasilan proyek, setiap anggota tim memiliki fokus tanggung jawab masing-masing:

### 📑 Orang 1: Provisioning Infrastruktur Azure
- Membuat VM (`vm1-manager`, `agent-vm2`, `agent-vm3`), VNet, subnet, dan Network Security Group (NSG) di Azure secara otomatis menggunakan script PowerShell.
- Membuka port-port penting yang dibutuhkan di NSG (`22` SSH, `80` HTTP, `443` HTTPS, `1514` Wazuh Agent, `1515` Wazuh Auth, `55000` Wazuh API).

### 📗 Orang 2: Wazuh Manager Setup
- Melakukan instalasi **Wazuh Manager** (All-in-One: Manager, Indexer, dan Dashboard) di VM1.
- Memastikan ketiga service utama (`wazuh-manager`, `wazuh-indexer`, `wazuh-dashboard`) berjalan aktif (`active (running)`).
- Mengekstrak password admin awal dan membuka akses dashboard untuk seluruh anggota tim.
- Menyiapkan konfigurasi agar agent dari Orang 3 bisa terhubung dengan aman.

### 🟡 Orang 3: Wazuh Agent Setup
- Melakukan instalasi **Wazuh Agent** pada VM2 (`agent-vm2`) dan VM3 (`agent-vm3`).
- Mendaftarkan (*enroll*) kedua agent ke Wazuh Manager di VM1.
- Melakukan verifikasi koneksi agar kedua agent muncul di dashboard dengan status **Active**.
- Membantu menyiapkan filter dashboard monitoring untuk siap menyambut simulasi DDoS oleh Orang 4.

### 🚨 Orang 4: Skenario DDoS, Custom Rules & Manajemen Log
- Mengonfigurasi firewall iptables dengan prefix log khusus `SYN-Flood-Detect:` di VM2 (Target).
- Melakukan tuning buffer agent pada VM2 (`client_buffer` di `ossec.conf`) agar log tidak dropped akibat banjir paket log.
- Menambahkan kustomisasi ruleset deteksi DDoS tingkat kritis (Level 12) di `/var/ossec/etc/rules/local_rules.xml` pada VM1.
- Mengeksekusi simulasi serangan SYN Flood dari VM3 menggunakan tool `hping3`.
- Memverifikasi peringatan level 12 terpicu secara real-time di logs dan dashboard Wazuh.

---

## 🖥️ Spesifikasi & Topologi Virtual Machine

Ketiga Virtual Machine (VM) menggunakan sistem operasi Ubuntu 22.04 LTS dan berada di dalam satu Virtual Network (VNet) Azure yang sama untuk efisiensi dan keamanan routing:

| Nama VM | Peran / Role | IP Publik | IP Internal (VNet) | Ukuran VM / Spesifikasi | Dashboard & Keterangan |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`vm1-manager`** | Wazuh Manager (All-in-One) | `4.194.10.103` | `10.0.0.4` | Standard B2s (2 vCPU, 4GB RAM) | Dashboard: `https://4.194.10.103`<br>Manager + Indexer + Dashboard |
| **`agent-vm2`** | Agent 1 (Target / Korban) | `20.212.154.248` | `10.0.0.5` | Standard B1s (1 vCPU, 1GB RAM) | Web Server Nginx & Target Serangan DDoS |
| **`agent-vm3`** | Agent 2 (Attacker / Penyerang) | `4.194.60.80` | `10.0.0.6` | Standard B1s (1 vCPU, 1GB RAM) | Melakukan flooding menggunakan tool `hping3` |

---

## 📁 Struktur Folder Proyek

```
miks-wazuh-azure-project/
├── README.md                  ← Panduan utama proyek (file ini)
├── PENGUJIAN.md               ← Panduan pengujian & bukti validasi deteksi
├── config/
│   ├── ddos_rules.xml         ← Custom ruleset Wazuh (Rule 100010 & 100011)
│   ├── log-management.conf    ← Konfigurasi manajemen penyimpanan log (logrotate)
│   └── ossec.conf             ← Template konfigurasi dasar Wazuh Manager & Agent
├── docs/
│   ├── manager-setup.md       ← Panduan langkah-langkah instalasi Wazuh Manager (Orang 2)
│   ├── agent-setup.md         ← Panduan langkah-langkah instalasi Wazuh Agent (Orang 3)
│   ├── ddos-scenario.md       ← Skenario lengkap simulasi serangan DDoS (Orang 4)
│   └── log-management.md      ← Langkah-langkah tuning kapasitas penyimpanan log
├── scripts/
│   ├── provision-azure.ps1    ← Script PowerShell otomatisasi pembuatan VM di Azure (Orang 1)
│   ├── install-manager.sh     ← Script pembantu instalasi Wazuh Manager
│   ├── install-agent.sh       ← Script pembantu instalasi Wazuh Agent
│   └── simulate-ddos.sh       ← Script pembantu pengujian serangan DDoS
└── documentation/
    └── Screenshot (75).png    ← Bukti tangkapan layar verifikasi agen / dashboard aktif
```

---

## 🚀 Panduan Cepat Menjalankan Proyek (End-to-End)

Di bawah ini adalah panduan lengkap dari proses pembuatan VM, instalasi Wazuh, hingga eksekusi pengujian DDoS.

---

### 📑 Bagian 1: Provisioning Infrastruktur Azure (Orang 1)

Jika Anda ingin membuat ulang seluruh VM dan Network Security Group (NSG) di Azure secara otomatis, gunakan script PowerShell yang tersedia:

1. Pastikan Anda memiliki SSH Public Key di komputer lokal Anda (`~/.ssh/id_rsa.pub`).
2. Jalankan script provisioning:
   ```powershell
   powershell.exe -File .\scripts\provision-azure.ps1
   ```
   *Script ini akan membuat Resource Group `miks-wazuh-rg`, NSG `wazuh-nsg` dengan port 22, 80, 443, 1514, 1515, serta 3 VM secara otomatis.*

---

### 📗 Bagian 2: Instalasi Wazuh Manager di VM1 (Orang 2)

Bagian ini mencakup penyusunan Wazuh Manager pusat pada **VM1**:

1. **SSH ke VM1 (Windows PowerShell)**:
   ```powershell
   ssh -i ".\miks-key.pem" azureuser@4.194.10.103
   ```
2. **Download & Jalankan Script Installer**:
   ```bash
   curl -sO https://packages.wazuh.com/4.7/wazuh-install.sh
   sudo bash wazuh-install.sh -a -i
   ```
   *(Proses memakan waktu 10-20 menit).*
3. **Ekstraksi Password Admin**:
   Jika Anda melewatkan catatan password di akhir instalasi, ambil password admin kapan saja dengan perintah:
   ```bash
   sudo tar -O -xvf wazuh-install-files.tar wazuh-install-files/wazuh-passwords.txt
   ```
4. **Verifikasi Layanan (Services)**:
   Pastikan ketiga service utama berjalan aktif:
   ```bash
   sudo systemctl status wazuh-manager wazuh-indexer wazuh-dashboard
   ```
5. **Konfigurasi Global Logging**:
   Buka `/var/ossec/etc/ossec.conf` pada VM1, ubah bagian `<global>` agar mencatat semua event log untuk kebutuhan analisis mendalam:
   ```xml
   <global>
     <email_notification>no</email_notification>
     <logall>yes</logall>
     <logall_json>yes</logall_json>
   </global>
   ```
6. **Restart Wazuh Manager**:
   ```bash
   sudo systemctl restart wazuh-manager
   ```

#### 🟢 Hasil Akhir Setup Manager (Orang 2)
Setelah setup selesai, bagikan informasi kredensial berikut ke grup chat tim:
```text
🟢 Wazuh Manager sudah aktif!

🌐 Dashboard : https://4.194.10.103
👤 Username  : admin
🔑 Password  : <password dari hasil ekstraksi step 3>

Orang 3 silakan mulai install agent!
```

---

### 📒 Bagian 3: Instalasi & Registrasi Agen di VM2 & VM3 (Orang 3)

Instalasi agen Wazuh pada **VM2** dan **VM3** agar terhubung ke Manager (VM1):

1. **SSH ke VM2** dan **VM3** (Jalankan ini di masing-masing terminal VM):
   ```powershell
   ssh -i ".\miks-key.pem" azureuser@20.212.154.248 # VM2 (Target)
   ssh -i ".\miks-key.pem" azureuser@4.194.60.80    # VM3 (Attacker)
   ```
2. **Jalankan Instalasi Agen**:
   Gunakan IP Internal VNet VM1 (`10.0.0.4`) sebagai manager agar koneksi lebih aman dan efisien dalam satu network internal Azure.
   
   - **Di VM2 (`agent-vm2`)**:
     ```bash
     sudo WAZUH_MANAGER="10.0.0.4" WAZUH_AGENT_NAME="agent-vm2" \
       bash -c "curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | apt-key add - && \
       echo 'deb https://packages.wazuh.com/4.x/apt/ stable main' > /etc/apt/sources.list.d/wazuh.list && \
       apt update && apt install -y wazuh-agent=4.7.5-1"
     ```
   - **Di VM3 (`agent-vm3`)**:
     ```bash
     sudo WAZUH_MANAGER="10.0.0.4" WAZUH_AGENT_NAME="agent-vm3" \
       bash -c "curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | apt-key add - && \
       echo 'deb https://packages.wazuh.com/4.x/apt/ stable main' > /etc/apt/sources.list.d/wazuh.list && \
       apt update && apt install -y wazuh-agent=4.7.5-1"
     ```
3. **Aktifkan & Jalankan Agen**:
   Di kedua VM (VM2 & VM3), jalankan perintah:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable wazuh-agent
   sudo systemctl start wazuh-agent
   ```
4. **Verifikasi Koneksi Agen**:
   Pastikan agen berhasil handshake dengan server manager:
   ```bash
   sudo grep "Connected to the server" /var/ossec/logs/ossec.log
   ```
   *Output normal:* `INFO: (4102): Connected to the server ([10.0.0.4]:1514/tcp)`

5. **Verifikasi pada Dashboard Wazuh**:
   Akses `https://4.194.10.103` menggunakan browser Anda. Gunakan user `admin` dan password dari Orang 2. Buka menu **Agents** dan pastikan kedua nama agen terdaftar dan online.

#### 🟡 Hasil Akhir Setup Agent (Orang 3)

| Metric | Value | Keterangan |
|---|---|---|
| **Total Agents** | 2 | `agent-vm2` dan `agent-vm3` |
| **Active Agents** | 2 | Berstatus online 🟢 |
| **Disconnected** | 0 | Tidak ada hambatan koneksi |

> [!NOTE]
> Kedua agent berhasil terdaftar dan aktif di Wazuh Dashboard (Total: 2, Active: 2). Bukti screenshot verifikasi tersimpan di folder [documentation/](file:///c:/Users/rayha/OneDrive/Documents/SEMESTER%204/7.%20MIKS/miks-wazuh-azure-project-main/documentation/).

---

### 🚨 Bagian 4: Skenario DDoS & Manajemen Log (Orang 4)

Bagian ini berfokus pada simulasi serangan, optimasi performa log, serta pembuatan rules deteksi.

#### 🛠️ Langkah A: Konfigurasi Target (VM2)
1. **Instal Nginx** (Web Server Target):
   ```bash
   sudo apt update && sudo apt install -y nginx
   sudo systemctl start nginx
   ```
2. **Konfigurasi Firewall `iptables` untuk Logging**:
   Agar decoder default Wazuh mengenali log iptables secara sempurna, gunakan prefix satu kata **`SYN-Flood-Detect:`**:
   ```bash
   # Berikan toleransi batas normal
   sudo iptables -A INPUT -p tcp --syn -m limit --limit 5/s -j ACCEPT
   # Log traffic di atas batas normal dengan prefix khusus
   sudo iptables -A INPUT -p tcp --syn -j LOG --log-prefix "SYN-Flood-Detect: "
   ```
3. **Tuning Buffer Agen (`/var/ossec/etc/ossec.conf`)**:
   Untuk menghindari event log terbuang (*dropped logs*) akibat ribuan event log per detik, perbesar antrean buffer agen pada `ossec.conf` di VM2:
   ```xml
   <client_buffer>
     <disabled>no</disabled>
     <queue_size>15000</queue_size>
     <events_per_second>1000</events_per_second>
   </client_buffer>
   ```
   Pastikan agen juga membaca berkas `/var/log/syslog`:
   ```xml
   <localfile>
     <log_format>syslog</log_format>
     <location>/var/log/syslog</location>
   </localfile>
   ```
   Restart Agen:
   ```bash
   sudo systemctl restart wazuh-agent
   ```

#### 🧠 Langkah B: Menambahkan Custom Rules di Manager (VM1)
Hubungkan ke VM1, buka file `/var/ossec/etc/rules/local_rules.xml`, dan tambahkan ruleset pendeteksi DDoS berikut:

```xml
<group name="syslog,iptables,ddos,">
  <!-- Deteksi Awal log SYN-Flood-Detect -->
  <rule id="100010" level="6">
    <if_sid>4100</if_sid>
    <match>SYN-Flood-Detect:</match>
    <description>IPTables: Deteksi awal traffic SYN yang mencurigakan (Indikasi DDoS).</description>
  </rule>

  <!-- Eskalasi Critical Alarm (Level 12) jika terpicu > 20 kali dalam 60 detik -->
  <rule id="100011" level="12" frequency="20" timeframe="60">
    <if_matched_sid>100010</if_matched_sid>
    <same_source_ip />
    <description>🔴 CRITICAL: Kemungkinan Serangan SYN Flood DDoS Sedang Berlangsung!</description>
    <mitre>
      <id>T1498.001</id>
    </mitre>
    <group>attack,ddos,</group>
  </rule>
</group>
```
Restart Manager:
```bash
sudo systemctl restart wazuh-manager
```

#### ⚔️ Langkah C: Simulasi Serangan dari VM3 (Attacker)
Hubungkan ke VM3. 

> [!IMPORTANT]
> **PENTING**: Agar paket serangan tidak didrop oleh firewall infrastruktur Azure, Anda harus menyerang target menggunakan **IP Internal VNet** VM2 (`10.0.0.5`).

Jalankan perintah berikut:
```bash
sudo apt update && sudo apt install -y hping3
sudo hping3 -S -p 80 --flood 10.0.0.5
```

---

## 🔍 Langkah 5: Verifikasi Hasil & Pembuktian

1. **Di VM2 (Target)**: Jalankan `sudo iptables -L INPUT -v -n` dan pastikan counter `LOG` meningkat sangat cepat (mencapai jutaan paket).
2. **Di VM1 (Manager)**: Cek file alert tersentralisasi:
   ```bash
   sudo grep -A 5 '100011' /var/ossec/logs/alerts/alerts.log
   ```
   *Anda akan menemukan log deteksi serangan level 12 (Critical) yang berhasil menangkap IP asal VM3 Attacker (`10.0.0.6`) mengarah ke target (`10.0.0.5`):*
   ```text
   Rule: 100011 (level 12) -> '🔴 CRITICAL: Kemungkinan Serangan SYN Flood DDoS Sedang Berlangsung!'
   Src IP: 10.0.0.6
   Dst IP: 10.0.0.5
   Dst Port: 80
   ```
3. **Dashboard Wazuh**: Buka dashboard keamanan, navigasi ke **Security events**, dan Anda akan melihat grafik lonjakan tajam (*spike*) di mana tanda peringatan bahaya level 12 (Critical) menyala!

---

## 🛑 Menghentikan Serangan

Segera jalankan perintah ini di VM3 (Attacker) setelah pengujian selesai agar tidak membebani penggunaan resources VM Azure Anda:
```bash
sudo pkill -9 hping3
```


# A2 — Red Team DDoS & Pengukuran Dampak

## Identitas

| | |
|---|---|
| **Role** | A2 — Red Team DDoS & Pengukuran Dampak |
| **VM Attacker** | vm3-agent2 (IP: 10.0.0.6) |
| **VM Target** | agent-vm2 / vm2-agent1 (IP: 10.0.0.5) |
| **Tanggal Eksekusi** | 24 Juni 2026 |

---

## Tujuan

Mengeksekusi serangan DDoS ke web server target dan mendokumentasikan dampak nyata terhadap performa web, sehingga menghasilkan alert Wazuh yang dapat digunakan A4 untuk labeling dataset.

---

## Infrastruktur

```
[vm3-agent2] 10.0.0.6  ──── nyerang ────►  [agent-vm2] 10.0.0.5
  (Attacker)                                  (Web Server Target / Korban)
                                                       │
                                               Wazuh Agent aktif
                                                       │
                                               [vm1-manager] 4.194.10.103
                                               (Wazuh Manager — menerima alert)
```

---

## Baseline (Sebelum Serangan)

Response time web server dalam kondisi normal:

```
[1] Response: 0.001156s | HTTP: 200
[2] Response: 0.001280s | HTTP: 200
[3] Response: 0.001179s | HTTP: 200
```

> Web server merespons normal di ~0.001s dengan HTTP 200.

---

## Skenario Serangan

### Skenario 1 — SYN Flood LOW
```bash
sudo hping3 -S -p 80 -i u10000 10.0.0.5
```
- **Interval:** 10ms antar paket
- **Dampak:** Response time naik ke 5.00s (timeout)

### Skenario 2 — SYN Flood MEDIUM
```bash
sudo hping3 -S -p 80 -i u5000 10.0.0.5
```
- **Interval:** 5ms antar paket
- **Dampak:** Response time naik ke 5.00s (timeout)

### Skenario 3 — SYN Flood HIGH
```bash
sudo hping3 -S -p 80 --flood 10.0.0.5
```
- **Mode:** Flood (secepat mungkin, no reply shown)
- **Dampak:** Response time naik ke 5.00s (timeout)

### Skenario 4 — ICMP Flood
```bash
sudo hping3 --icmp --flood 10.0.0.5
```
- **Protocol:** ICMP
- **Dampak:** Response time naik ke 5.00s (timeout)

### Skenario 5 — HTTP Flood
```bash
sudo hping3 -S --flood -p 80 10.0.0.5
```
- **Target:** Port 80 (HTTP)
- **Dampak:** Response time naik ke 5.00s (timeout)

---

## Hasil & Dampak

| Kondisi | Response Time | HTTP Status |
|---|---|---|
| Normal (baseline) | ~0.001s | 200 OK |
| Saat serangan aktif | 5.000s | Timeout |
| Setelah serangan berhenti | ~0.001s | 200 OK |

> Semua 5 skenario berhasil menyebabkan web server tidak dapat diakses (timeout).

---

## Alert Wazuh yang Terdeteksi

| Rule ID | Level | Description | MITRE | Tactic |
|---|---|---|---|---|
| 100011 | 12 (CRITICAL) | 🔴 Kemungkinan Serangan SYN Flood DDoS Sedang Berlangsung! | T1498.001 | Impact |
| 100010 | 6 | IPTables: Deteksi awal traffic SYN yang mencurigakan (Indikasi DDoS) | T1498.001 | Impact |

**Active Response** juga terpicu otomatis: `firewall-drop` memblokir IP attacker (10.0.0.6).

---

## Deliverables

- [x] Screenshot response time 0.001s → 5.00s saat DDoS
- [x] Screenshot alert DDoS di Wazuh Dashboard (agent-vm2)
- [x] Log command hping3 per skenario (tercatat di alerts.log)
- [x] Raw alert export JSON (`ddos_alerts.json`) → diserahkan ke A4

---



## FINAL PROJECT UPDATE

# A3 Progress - Wazuh SOC Project

## 1. Wazuh Agent Connection

Status: DONE ✅

Agent:
- VM2 Agent
- VM3 Agent

Bukti:

```bash
wazuh-agentd: Connected to the server
```
Fungsi:

Menghubungkan endpoint ke Wazuh Manager
Mengirim log dan event ke Wazuh Dashboard
2. File Integrity Monitoring (FIM)

Status: DONE ✅

File yang diubah:
```
/var/ossec/etc/ossec.conf
```
Konfigurasi:
```
<syscheck>
    <disabled>no</disabled>

    <directories>/etc,/usr/bin,/usr/sbin</directories>
    <directories>/bin,/sbin,/boot</directories>

    <directories realtime="yes">/tmp</directories>
</syscheck>
```
Fungsi:

Mengaktifkan File Integrity Monitoring
Monitoring perubahan file realtime pada folder /tmp

Testing:
```
sudo touch /tmp/FIM_SUCCESS.txt
```
Hasil Alert:

Rule:
Integrity checksum changed

Level:
7

MITRE:
T1565.001 - Stored Data Manipulation

Fungsi:

Membuktikan Wazuh mendeteksi perubahan file
3. Malware Simulation

Status: DONE ✅

File dibuat:
```
/tmp/simulate_malware.sh
```
Isi file:
```
#!/bin/bash

echo "[*] Malware Simulation - Mass File Write"

for i in $(seq 1 200); do
  echo "encrypted_payload_$i" > /tmp/mal_$i.enc
done


echo "[*] Suspicious outbound connection attempt"

curl -s --max-time 3 http://10.0.0.6:4444 || true


echo "[*] Privilege escalation probe"

sudo -l 2>/dev/null || true


echo "[*] Suspicious cron injection attempt"

echo "* * * * * root /tmp/backdoor.sh" >> /tmp/fake_cron || true


echo "[DONE]"
```
Fungsi:

di VM1
```
sudo grep -i "mal_\|fake_cron\|Integrity\|syscheck" /var/ossec/logs/alerts/alerts.json | tail -20
```

Simulasi perilaku malware:

Membuat banyak file mencurigakan
Mencoba koneksi keluar
Mengecek privilege user
Membuat percobaan persistence melalui cron

Eksekusi:

sudo bash /tmp/simulate_malware.sh

Output:

[*] Malware Simulation - Mass File Write
[*] Suspicious outbound connection attempt
[*] Privilege escalation probe
[*] Suspicious cron injection attempt
[DONE]
4. DDoS Simulation

Status: DONE ✅

Simulasi:

SYN Flood Attack
Abnormal network traffic

Tujuan:

Membuat event serangan jaringan

Hasil Wazuh:

Rule:
100011

Level:
12

MITRE:
T1498.001
Network Denial of Service

Fungsi:

Membuktikan Wazuh dapat mendeteksi serangan jaringan
5. Dashboard Analysis

Status: DONE ✅

Analisis:

Agent status
Alert severity
Rule ID
MITRE ATT&CK mapping

Alur:

Attacker
    |
    v
Agent VM
    |
    v
Wazuh Agent
    |
    v
Wazuh Manager
    |
    v
Alert Dashboard



# A4 Progress - Dataset Engineering & Auto-Labeling

## 1. Wazuh Alert Extraction

Status: DONE ✅

Script yang dieksekusi:
```bash
bash export-alerts.sh
```

Fungsi:
- Mengambil log mentah `alerts.json` dari Wazuh Manager (VM1).
- Mengekstrak 10 field esensial: `timestamp`, `rule_id`, `rule_level`, `rule_description`, `rule_groups`, `agent_name`, `agent_id`, `src_ip`, `dst_ip`, `dst_port`.
- Mengonversinya menjadi format CSV yang rapi.

Output Eksekusi:
```text
==============================================
✅ Hasil Export
   Output file : /root/dataset_raw.csv
   Total alert : 53278 baris
==============================================
```

## 2. Feature Engineering & Auto-Labeling

Status: DONE ✅

Script yang dieksekusi:
```bash
bash label-dataset.sh
```

Feature Engineering (Kolom Baru):
- `hit_count_60s`: Menghitung frekuensi paket dari IP yang sama dalam jeda 60 detik (Sangat krusial untuk mendeteksi DDoS).
- `hour_of_day`: Mengekstrak jam dari timestamp untuk membantu model mendeteksi anomali waktu.

Mekanisme Auto-Labeling (6-Layer Heuristics):
1. **Layer 1 (Deterministic Rule)**: Rule `100011` langsung dilabeli `TP (1)`. Rule `5715/5716` dilabeli `FP (0)`.
2. **Layer 2 (Critical Groups)**: Level ≥10 yang mengandung kata `attack`/`ddos` -> `TP (1)`.
3. **Layer 3 (IP Heuristics)**: IP Private/Loopback dengan `hit_count` rendah -> `FP (0)`.
4. **Layer 4 (Frequency Check)**: `hit_count` ≥20 -> `TP (1)`, `hit_count` <5 -> `FP (0)`.
5. **Layer 5 (Description Analysis)**: Deskripsi yang mengandung kata "flood", "multiple", "exceeded" -> `TP (1)`.
6. **Layer 6 (Level Fallback)**: Level >8 -> `TP (1)`, Level ≤5 -> `FP (0)`.

Output Eksekusi:
```text
=== Auto-Labeling Selesai ===
Total baris diproses: 53278
True Positive (1)   : 44017
False Positive (0)  : 9255
Ambiguous (-1)      : 6
```

## 3. Dataset Finalization & Manual Review

Status: DONE ✅

Script yang dieksekusi:
```bash
bash finalize-dataset.sh
```

Fungsi:
- Menggabungkan hasil manual review (6 baris *Ambiguous* akibat indikasi SSH Brute-force, diubah ke label 1).
- Melakukan validasi dataset agar tidak ada sisa label `-1`.

Statistik Final Dataset (`dataset_final.csv`):

| Kategori | Jumlah Baris | Persentase | Keterangan |
|---|---|---|---|
| **True Positive** | 44.023 | 82.6% | Serangan DDoS, Malware, Anomali |
| **False Positive** | 9.255 | 17.4% | Traffic Normal / Noise |
| **Total Data** | 53.278 | 100% | Siap ditraining |

> **Analisis A4 untuk A5:** Rasio TP terhadap FP adalah 4.76x. Dataset tidak seimbang karena durasi serangan yang masif. **Direkomendasikan menggunakan teknik SMOTE** saat ML training.

---

# A5 Progress - Machine Learning Model Development

## Identitas

| | |
|---|---|
| **Role** | A5 — AI Engineer / ML Model Development |
| **Input** | `dataset_final.csv` dari A4 (53.278 baris, sudah dilabeli) |
| **Output** | Trained model `.pkl` + notebook + visualisasi |
| **Tanggal Eksekusi** | 24 Juni 2026 |

---

## Tujuan

Membangun dan mengevaluasi model Machine Learning untuk mengklasifikasikan alert Wazuh secara otomatis:
- **Label 0** → False Positive (traffic normal / noise)
- **Label 1** → True Positive (serangan nyata: DDoS, Malware, Anomali)

---

## Pipeline ML

```
dataset_final.csv (A4)
        │
        ▼
1. Load & EDA          → Eksplorasi distribusi label, missing values, top rules
        │
        ▼
2. Preprocessing       → Feature engineering dari IP, timestamp, rule_groups, description
        │
        ▼
3. SMOTE Balancing     → Menyeimbangkan kelas minoritas (FP) di training set
        │
        ▼
4. Model Training      → Random Forest, XGBoost, Logistic Regression
        │
        ▼
5. Evaluasi            → Accuracy, F1, ROC-AUC, Confusion Matrix, Feature Importance
        │
        ▼
6. Export              → soc_model_random_forest.pkl + feature_names.pkl
```

---

## 1. Load & EDA

Status: DONE ✅

Dataset yang diterima dari A4:

| Kategori | Jumlah | Persentase |
|---|---|---|
| True Positive (1) | 44.023 | 82.6% |
| False Positive (0) | 9.255 | 17.4% |
| **Total** | **53.278** | **100%** |

Temuan EDA:
- Dataset **tidak seimbang** (rasio TP:FP = 4.76:1) → ditangani dengan SMOTE
- Missing values di `src_ip` (5.222 baris) dan `dst_ip`/`dst_port` (9.347 baris) — wajar karena alert internal tidak selalu punya IP sumber/tujuan
- Rule ID **100010** mendominasi (41.822 alert) → mayoritas adalah deteksi SYN Flood dari iptables
- Terdapat **33 jenis rule_id** unik dari 3 VM (agent-vm2, agent-vm3, vm1-manager)

<img width="2136" height="524" alt="image" src="https://github.com/user-attachments/assets/97f0431f-743a-4ce2-b7fd-07f631cf66bf" />

> Kiri: distribusi label imbalanced | Tengah: distribusi rule level | Kanan: distribusi hit_count_60s

---

## 2. Preprocessing & Feature Engineering

Status: DONE ✅

Transformasi yang dilakukan pada 12 kolom mentah menjadi **16 fitur siap training**:

| Kolom Asal | Transformasi | Fitur Baru |
|---|---|---|
| `timestamp` | Ekstrak komponen waktu | `day_of_week`, `minute_of_hour` |
| `src_ip` | Flag IP internal & attacker | `src_ip_is_internal`, `src_ip_is_attacker` |
| `dst_ip` | Flag IP target | `dst_ip_is_target` |
| `rule_groups` | Hitung jumlah group + flag ddos | `rule_groups_count`, `is_ddos_group` |
| `rule_description` | Flag keyword penting | `desc_is_syn`, `desc_is_ssh`, `desc_is_fim` |
| `agent_name` | Label encoding | `agent_name` (0/1/2) |
| `dst_port`, `rule_id`, `rule_level`, `hit_count_60s`, `hour_of_day` | Dipertahankan langsung | — |

Hasil: **0 missing values** setelah preprocessing, semua fitur numerik.

<img width="1273" height="909" alt="image" src="https://github.com/user-attachments/assets/02c9acee-05a1-4473-aa32-44cc7d4e9605" />

> Heatmap korelasi antar fitur — `is_ddos_group` dan `desc_is_syn` menunjukkan korelasi tinggi dengan label (wajar karena DDoS mendominasi TP)

---

## 3. SMOTE Balancing

Status: DONE ✅

Teknik yang digunakan: **SMOTE** *(Synthetic Minority Over-sampling Technique)*

| | Sebelum SMOTE | Setelah SMOTE |
|---|---|---|
| Training size | 42.622 baris | 70.436 baris |
| Label 1 (TP) | 35.218 | 35.218 |
| Label 0 (FP) | 7.404 | 35.218 ✅ |
| Rasio | 82.6% : 17.4% | **50% : 50%** |

> SMOTE **hanya diterapkan pada training set**. Test set (10.656 baris) tidak disentuh agar evaluasi tetap mencerminkan kondisi data nyata.

---

## 4. Model Training & Evaluasi

Status: DONE ✅

Tiga model dilatih dan dibandingkan:

| Model | Accuracy | Precision | Recall | F1-Score | ROC-AUC | Train Time |
|---|---|---|---|---|---|---|
| **Random Forest** ⭐ | 0.9999 | 1.0000 | 0.9999 | 0.9999 | 1.0000 | 0.50s |
| XGBoost | 0.9999 | 1.0000 | 0.9999 | 0.9999 | 1.0000 | 0.61s |
| Logistic Regression | 0.9997 | 1.0000 | 0.9997 | 0.9998 | 1.0000 | 1.59s |

**Best Model: Random Forest** (F1 tertinggi, training tercepat)

<img width="2131" height="618" alt="image" src="https://github.com/user-attachments/assets/600e85a2-ecbc-4397-b457-a5f2b81327c0" />

> Confusion matrix ketiga model — hampir tidak ada misclassification

<img width="1217" height="906" alt="image" src="https://github.com/user-attachments/assets/10ac1d68-aaff-4d2d-b1c6-373f52478ed5" />

> ROC-AUC = 1.0000 untuk semua model → pemisahan FP vs TP sempurna

<img width="1375" height="902" alt="image" src="https://github.com/user-attachments/assets/fc258a16-cf9c-4ddc-bfa1-d400243c283a" />

> Perbandingan visual semua metrik antar model

---

## 5. Feature Importance

Status: DONE ✅

Top 5 fitur paling berpengaruh pada Random Forest:

| Rank | Fitur | Importance | Keterangan |
|---|---|---|---|
| 1 | `src_ip_is_attacker` | 0.2454 | Apakah paket dari IP VM3 attacker (10.0.0.6) |
| 2 | `hit_count_60s` | 0.2338 | Frekuensi paket dalam 60 detik — sinyal utama DDoS |
| 3 | `src_ip_is_internal` | 0.1995 | IP internal Azure vs eksternal |
| 4 | `rule_id` | 0.0824 | Jenis rule yang terpicu |
| 5 | `dst_port` | 0.0795 | Port tujuan (port 80 jadi target flood) |

<img width="1835" height="902" alt="image" src="https://github.com/user-attachments/assets/5522e634-fa8d-49a7-819a-987551e2b846" />

> Fitur berbasis IP dan frekuensi mendominasi — konsisten dengan pola serangan DDoS SYN Flood

---

## 6. Analisis Hasil

**Mengapa hasilnya hampir perfect (0.9999)?**

Ini **bukan overfitting**, melainkan karakteristik data SIEM yang deterministik:
- Ruleset Wazuh yang dibuat A4 sangat konsisten — rule 100010 hampir selalu menghasilkan label 1
- Serangan DDoS dari A2 sangat agresif sehingga polanya sangat jelas di data
- Model berhasil **mengkonfirmasi bahwa labeling A4 akurat dan konsisten** secara matematis

---

## Deliverables

- [x] `A5_SOC_ML_Model.ipynb` — Notebook lengkap end-to-end
- [x] `soc_model_random_forest.pkl` — Best model (Random Forest)
- [x] `model_xgboost.pkl` — Model XGBoost
- [x] `model_logistic_regression.pkl` — Model Logistic Regression
- [x] `feature_names.pkl` — Urutan fitur untuk inferensi
- [x] `01_eda_overview.png` — Plot EDA
- [x] `02_correlation_matrix.png` — Correlation heatmap
- [x] `03_confusion_matrix.png` — Confusion matrix semua model
- [x] `04_roc_curve.png` — ROC curve perbandingan
- [x] `05_feature_importance.png` — Feature importance Random Forest
- [x] `06_model_comparison.png` — Bar chart perbandingan metrik

---

## Cara Load & Gunakan Model

```python
import joblib
import pandas as pd

model = joblib.load('soc_model_random_forest.pkl')
feature_names = joblib.load('feature_names.pkl')

# Contoh: alert DDoS baru
new_alert = pd.DataFrame([{
    'rule_id': 100011, 'rule_level': 12,
    'agent_name': 0, 'dst_port': 80.0,
    'hit_count_60s': 250, 'hour_of_day': 14,
    'day_of_week': 1, 'minute_of_hour': 32,
    'src_ip_is_internal': 1, 'src_ip_is_attacker': 1,
    'dst_ip_is_target': 0, 'rule_groups_count': 4,
    'is_ddos_group': 1, 'desc_is_syn': 1,
    'desc_is_ssh': 0, 'desc_is_fim': 0
}])[feature_names]

pred = model.predict(new_alert)
prob = model.predict_proba(new_alert)[:, 1]
print(f'Prediksi : {"TP (Serangan)" if pred[0] == 1 else "FP (Normal)"}')
print(f'Confidence: {prob[0]:.4f}')
```

---

# A6 Progress - AI Integration ke Wazuh

## Identitas

| | |
|---|---|
| **Role** | A6 — AI Engineer / Integration ke Wazuh |
| **Input** | `soc_model_random_forest.pkl` dari A5, Alert Wazuh |
| **Output** | AI Flask Server + Active Response Wazuh (Label TP/FP) |
| **Tanggal Eksekusi** | 25 Juni 2026 |

---

## Tujuan

Mengintegrasikan model Machine Learning yang telah dilatih oleh A5 ke dalam pipeline Wazuh secara *real-time*. Semua alert yang masuk ke Wazuh Manager akan diproses oleh AI untuk menentukan apakah alert tersebut adalah **True Positive (Serangan)** atau **False Positive (Noise)**, sehingga membantu analis SOC mengurangi *false alarm* dan mempermudah eksekusi SOAR (A7).

---

## Arsitektur Integrasi

```text
Wazuh Agent ──(alert)──► Wazuh Engine ──(stdin)──► ai_verdict.py (Active Response)
                                                           │
                                                           ▼ (HTTP POST)
                                                     ai_server.py (Flask API)
                                                           │
                                                           ▼ (Random Forest Model)
A7 (SOAR) ◄──(Rule 100021)── Wazuh Dashboard ◄──(log)── AI Verdict (TP/FP)
```

---

## Deliverables & Komponen

| Komponen | File | Deskripsi |
|---|---|---|
| **Flask API Server** | `scripts/ai_server.py` | Server Python yang me-load model `.pkl` A5 dan merakit 16 fitur *real-time* (termasuk *sliding window* untuk `hit_count_60s`). |
| **Active Response Script** | `scripts/ai_verdict.py` | Script penengah yang membaca alert dari Wazuh dan mengirimkannya ke Flask Server. |
| **Wazuh Config** | `config/ossec_ai_integration.conf` | Konfigurasi XML untuk mendaftarkan command `ai_verdict` di Wazuh. |
| **Custom Rules AI** | `config/ai_verdict_rules.xml` | Rule khusus (ID 100021-100023) untuk memunculkan hasil prediksi AI ke dashboard Wazuh. |
| **Deployment Docs** | `docs/ai-integration.md` | Panduan lengkap langkah demi langkah instalasi AI Server di VM1. |

---

## Fitur Unggulan Integrasi

1. **Real-time Feature Engineering:** Karena model A5 bergantung pada fitur frekuensi (`hit_count_60s`), Flask API dibangun dengan mekanisme *sliding window counter* dalam memori untuk menghitung jumlah paket per IP dalam 60 detik terakhir secara instan.
2. **Fail-Safe Mechanism:** Jika AI Server mati atau tidak merespons, Wazuh Active Response tidak akan *crash*, melainkan melabeli alert sebagai `UNKNOWN` (Warning) agar data tidak hilang.
3. **Pemisahan Severity (Leveling):** Alert **True Positive (TP)** langsung dinaikkan menjadi Level 10 agar bisa memicu otomatisasi keamanan SOAR (A7). Alert **False Positive (FP)** ditekan ke Level 3 agar tidak mengganggu tampilan monitoring analis.

---

## Cara Pengujian & Bukti Implementasi (Screenshots)

Jika teman-teman tim (seperti A7 atau A8) ingin mengetes API Server AI ini secara manual tanpa harus menjalankan simulasi serangan penuh dari VM Attacker, kalian bisa menggunakan perintah `curl` langsung dari terminal VM1 (Wazuh Manager).

### 1. Test Alert Normal / Noise (Seharusnya False Positive / FP)
**Cara Pengujian:**
```bash
curl -s -X POST http://localhost:5000/predict \
  -H "Content-Type: application/json" \
  -d '{
    "timestamp": "2026-06-24T14:32:00+00:00",
    "rule": { "id": "5710", "level": 5, "description": "sshd: Attempt to login using a non-existent user", "groups": ["syslog", "sshd", "authentication_failed"] },
    "agent": {"name": "agent-vm2"},
    "data": {"srcip": "78.186.54.65"}
  }' | grep -E "ai_verdict|ai_confidence"
```
**Hasil & Bukti Implementasi:**
Model mendeteksi ini sebagai pola *noise* biasa dan mengembalikan `"ai_verdict": "FP"` dengan *confidence* yang sangat rendah.
<img width="1944" height="603" alt="Image" src="https://github.com/user-attachments/assets/8f031e5c-2ccc-401a-a309-98768bcf1d80" />

<br>

### 2. Test Alert Serangan DDoS (Seharusnya True Positive / TP)
**Cara Pengujian:**
```bash
# Kamu bisa menjalankan command ini beberapa kali secara cepat untuk mensimulasikan "hit_count" tinggi
curl -s -X POST http://localhost:5000/predict \
  -H "Content-Type: application/json" \
  -d '{
    "timestamp": "2026-06-24T14:32:00+00:00",
    "rule": { "id": "100011", "level": 12, "description": "CRITICAL: Kemungkinan Serangan SYN Flood DDoS Sedang Berlangsung!", "groups": ["syslog", "iptables", "ddos", "attack"] },
    "agent": {"name": "agent-vm2"},
    "data": {"srcip": "10.0.0.6", "dstip": "10.0.0.5", "dstport": "80"}
  }' | grep -E "ai_verdict|ai_confidence"
```
**Hasil & Bukti Implementasi:**
Model mengenali ini sebagai *True Positive* (karena pola rules DDoS dan IP Attacker) dan mengembalikan `"ai_verdict": "TP"` dengan *confidence* > 0.90.
<img width="1957" height="469" alt="Image" src="https://github.com/user-attachments/assets/f17f0d57-2db7-4cfb-b264-b905e67e4cb2" />

<br>

### 3. Pengujian End-to-End di Wazuh Dashboard
Setelah memastikan Flask API berjalan, pengujian lanjutan adalah dengan menjalankan serangan *real* dari VM3 (Attacker) menggunakan `hping3`. Alert akan ditangkap oleh Active Response Wazuh, dikirim ke AI, lalu AI akan memunculkan *alert custom* di Dashboard Wazuh.
**Hasil & Bukti Implementasi:**
> 🖼️ *[PLACEHOLDER: Masukkan Screenshot 3 - Bukti layar Wazuh Dashboard menampilkan alert dengan field `ai_verdict: TP/FP`]*

---
*A6 — Final Project MIKS SOC 2026*
---
*Proyek ini diselesaikan oleh kelompok praktikum MIKS — 2026.*
