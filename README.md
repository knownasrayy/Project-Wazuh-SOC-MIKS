# 🛡️ Wazuh SIEM & Azure Security Project

Proyek ini mengimplementasikan deteksi keamanan tersentralisasi menggunakan **Wazuh SIEM** pada arsitektur cloud Microsoft Azure. Sistem ini dikonfigurasi untuk mensimulasikan serangan **TCP SYN Flood DDoS**, mendeteksi anomali paket melalui kustomisasi ruleset, serta mengoptimalkan manajemen kapasitas log (*log density*) agar sistem tetap stabil selama terjadi serangan masif.

---

## 📐 Arsitektur & Topologi Lingkungan
Sistem terdiri dari 3 buah Virtual Machine (VM) Ubuntu 22.04 LTS yang berada di dalam satu Virtual Network (VNet) Azure yang sama:

| Nama VM | Peran | IP Publik | IP Internal (VNet) | Ukuran VM | Keterangan |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`vm1-manager`** | Wazuh Manager | `4.194.10.103` | `10.0.0.4` | `Standard_B2s` | All-in-One: Manager + Indexer + Dashboard |
| **`agent-vm2`** | Agent Target | `20.212.154.248` | `10.0.0.5` | `Standard_B1s` | Target Serangan (Korban) & Web Server Nginx |
| **`agent-vm3`** | Agent Attacker | `4.194.60.80` | `10.0.0.6` | `Standard_B1s` | Penyerang menggunakan tool `hping3` |

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
   *Script ini akan membuat Resource Group `miks-wazuh-rg`, NSG `wazuh-nsg` dengan port 22, 443, 80, 1514, 1515, serta 3 VM secara otomatis.*

---

### 📗 Bagian 2: Instalasi Wazuh Manager di VM1 (Orang 2)
Bagian ini mencakup penyusunan Wazuh Manager pusat pada **VM1**:

1. **SSH ke VM1**:
   ```powershell
   ssh -i ".\miks-key.pem" azureuser@4.194.10.103
   ```
2. **Download & Jalankan Script Installer**:
   ```bash
   curl -sO https://packages.wazuh.com/4.7/wazuh-install.sh
   sudo bash wazuh-install.sh -a -i
   ```
   *(Proses memakan waktu 10-20 menit. Harap catat password admin di akhir proses).*
3. **Konfigurasi Global Logging**:
   Buka `/var/ossec/etc/ossec.conf` pada VM1, ubah bagian `<global>`:
   ```xml
   <global>
     <email_notification>no</email_notification>
     <logall>yes</logall>
     <logall_json>yes</logall_json>
   </global>
   ```
4. **Restart Wazuh Manager**:
   ```bash
   sudo systemctl restart wazuh-manager
   ```

---

### 📒 Bagian 3: Instalasi & Registrasi Agen di VM2 & VM3 (Orang 3)
Instalasi agen Wazuh pada **VM2** dan **VM3** agar terhubung ke Manager (VM1):

1. **SSH ke VM2** dan **VM3** (Jalankan ini di masing-masing VM):
   ```powershell
   ssh -i ".\miks-key.pem" azureuser@20.212.154.248 # VM2
   ssh -i ".\miks-key.pem" azureuser@4.194.60.80    # VM3
   ```
2. **Jalankan Instalasi Agen**:
   ```bash
   curl -sLo wazuh-agent.deb https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/wazuh-agent_4.7.5-1_amd64.deb
   sudo WAZUH_MANAGER='10.0.0.4' dpkg -i wazuh-agent.deb
   ```
3. **Aktifkan & Restart Agen**:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable wazuh-agent
   sudo systemctl start wazuh-agent
   ```
4. **Verifikasi pada Dashboard Wazuh**:
   Akses `https://4.194.10.103` menggunakan browser Anda. Pastikan kedua agen berstatus **Active** di menu Agents.

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

---
*Proyek ini diselesaikan oleh kelompok praktikum MIKS — 2026.*
