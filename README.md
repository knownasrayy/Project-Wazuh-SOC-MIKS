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

```
---
*Proyek ini diselesaikan oleh kelompok praktikum MIKS — 2026.*
