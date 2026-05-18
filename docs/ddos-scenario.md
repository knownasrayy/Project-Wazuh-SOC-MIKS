# 🚨 Skenario Serangan DDoS & Deteksi Wazuh

Dokumen ini menjelaskan langkah-langkah **Proof of Concept (PoC)** untuk mensimulasikan serangan Distributed Denial of Service (DDoS) menggunakan `hping3` dari VM penyerang (Attacker) ke VM target.

---

## 🎯 Topologi & Informasi Lingkungan

| Peran | Hostname | IP Address | Keterangan |
|-------|----------|------------|------------|
| **Attacker** | `agent-vm3` | `4.194.60.80` | Mesin yang digunakan untuk melancarkan serangan (hping3). |
| **Target** | `agent-vm2` | `20.212.154.248` | Mesin web server yang akan diserang. |
| **Manager** | `vm1-manager`| `4.194.10.103` | Wazuh Manager untuk analisis dan deteksi log. |

---

## 🛠️ Langkah 1: Persiapan Target (VM2 - 20.212.154.248)

VM2 akan menjadi target serangan. Untuk melihat dampak dari DDoS, sebaiknya ada servis yang berjalan (misal: Nginx) dan kita akan merekam koneksi melalui `iptables`.

1. **SSH ke VM2**
   ```bash
   ssh azureuser@20.212.154.248
   ```

2. **Install Nginx (Opsional, untuk simulasi Web DDoS)**
   ```bash
   sudo apt update
   sudo apt install -y nginx
   sudo systemctl start nginx
   ```

3. **Konfigurasi iptables untuk Logging SYN Packets**
   Agar Wazuh bisa mendeteksi *SYN Flood*, kita harus mengaktifkan log pada iptables untuk mendeteksi permintaan SYN yang terlalu cepat.
   ```bash
   sudo iptables -A INPUT -p tcp --syn -m limit --limit 5/s -j ACCEPT
   sudo iptables -A INPUT -p tcp --syn -j LOG --log-prefix "Possible SYN Flood: "
   ```

4. **Pastikan iptables log dibaca oleh Wazuh Agent**
   Buka file konfigurasi agen: `sudo nano /var/ossec/etc/ossec.conf`
   Tambahkan blok ini pada bagian `<localfile>`:
   ```xml
   <localfile>
     <log_format>syslog</log_format>
     <location>/var/log/syslog</location>
   </localfile>
   ```
   Lalu restart agen:
   ```bash
   sudo systemctl restart wazuh-agent
   ```

---

## ⚔️ Langkah 2: Simulasi Serangan (VM3 - 4.194.60.80)

Kita akan menggunakan `hping3` untuk melakukan **TCP SYN Flood Attack**.

1. **SSH ke VM3**
   ```bash
   ssh azureuser@4.194.60.80
   ```

2. **Install hping3**
   ```bash
   sudo apt update
   sudo apt install -y hping3
   ```

3. **Eksekusi Serangan DDoS (Otomatis)**
   Gunakan script `simulate-ddos.sh` yang tersedia di direktori `scripts/`.
   ```bash
   # Beri izin eksekusi
   chmod +x scripts/simulate-ddos.sh
   # Jalankan serangan ke IP Target (Gunakan sudo)
   sudo ./scripts/simulate-ddos.sh 20.212.154.248
   ```

   **Penjelasan Command Hping3 Manual:**
   ```bash
   sudo hping3 -S --flood -V -p 80 20.212.154.248
   ```
   - `-S`: Mengirim paket TCP SYN.
   - `--flood`: Mengirim paket secepat mungkin tanpa menunggu balasan (menguras *buffer* TCP koneksi di target).
   - `-p 80`: Menargetkan port 80 (HTTP).

---

## 🔍 Langkah 3: Deteksi dan Investigasi pada Wazuh Manager

1. **Buka Wazuh Dashboard**
   Navigasi ke `https://4.194.10.103` dan login menggunakan kredensial `admin`.
2. Buka modul **Security events**.
3. **Pencarian Log:**
   Anda akan melihat lonjakan tajam pada grafik event (events timeline).
   Anda dapat melakukan pencarian/filter:
   ```
   rule.id: "100001" ATAU rule.description: "Possible SYN Flood Attack detected"
   ```
4. **Analisis Log:**
   Log yang ditangkap akan menunjukkan sumber IP dari attacker (4.194.60.80) dan port tujuan. 
   Tingkat peringatan (*Rule Level*) akan menampilkan angka tinggi (misal: 10 atau 12 - Critical) sesuai dengan *custom rule* yang ditambahkan di `/var/ossec/etc/rules/local_rules.xml`.

---

## 🛡️ Langkah 4: Mitigasi (Active Response - Opsional)

Wazuh dapat merespon secara otomatis dengan memblokir IP penyerang menggunakan *Active Response* (firewall-drop).

Jika dikonfigurasi, IP penyerang (4.194.60.80) akan otomatis dimasukkan ke `iptables` drop rule di VM2, dan koneksi `hping3` dari VM3 akan mengalami "100% packet loss".
