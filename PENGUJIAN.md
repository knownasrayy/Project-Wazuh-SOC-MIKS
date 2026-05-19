# 🧪 Panduan Pengujian Keamanan & Deteksi DDoS Wazuh
### (Proof of Concept & Verification Guide)

Dokumen ini berisi panduan teknis **langkah-demi-langkah dari awal sampai akhir** untuk menguji skenario serangan **TCP SYN Flood DDoS**, melakukan verifikasi log pada target, serta memvalidasi hasil deteksi pada Wazuh SIEM Dashboard.

---

## 🎯 Target & Parameter Pengujian
* **Attacker (VM3)**: `10.0.0.6` (IP Internal)
* **Target / Korban (VM2)**: `10.0.0.5` (IP Internal)
* **Layanan Target**: HTTP (Nginx) pada Port `80`
* **SIEM / Manager (VM1)**: `10.0.0.4` (IP Internal)

---

## 📋 Langkah 1: Persiapan Sebelum Pengujian (Pre-Test Checks)
Sebelum melancarkan serangan, pastikan seluruh layanan berjalan normal.

### 1. Periksa Status Agen di Wazuh Manager (VM1)
Hubungkan ke VM1 dan pastikan kedua agen (VM2 dan VM3) berstatus **Active**:
```bash
sudo /var/ossec/bin/agent_control -l
```
*Pastikan Agen 001 (`agent-vm2`) dan 002 (`agent-vm3`) aktif.*

### 2. Periksa Status Nginx di VM2 (Target)
Hubungkan ke VM2 dan pastikan Web Server berjalan:
```bash
sudo systemctl status nginx
```

---

## ⚔️ Langkah 2: Menjalankan Serangan (Execution)
Kita akan melancarkan serangan TCP SYN Flood secepat mungkin (*flood mode*) menggunakan `hping3` dari VM3.

1. **Masuk ke VM3 (Attacker)** via SSH.
2. **Jalankan serangan** mengarah ke IP Internal VM2:
   ```bash
   sudo hping3 -S -p 80 --flood 10.0.0.5
   ```
   > ⚠️ **Catatan penting**: Di layar terminal VM3 Anda **tidak akan muncul respon apa pun** karena ini adalah *flood mode*. Biarkan serangan berjalan selama **15 sampai 30 detik**.

---

## 🔍 Langkah 3: Verifikasi di Sisi Target (VM2 - Korban)
Sambil serangan berlangsung di VM3, Anda dapat memantau dampak serangan secara real-time di VM2.

1. **Masuk ke VM2 (Target)** via SSH.
2. **Cek Statistik iptables**:
   Jalankan perintah ini berulang kali untuk melihat jumlah paket SYN yang ditangkap:
   ```bash
   sudo iptables -L INPUT -v -n
   ```
   *Anda akan melihat baris dengan prefix `SYN-Flood-Detect:` meningkat drastis hingga **ratusan ribu atau jutaan paket**.*
3. **Cek Syslog Lokal**:
   Pastikan kernel mencatat upaya flooding tersebut ke berkas syslog:
   ```bash
   sudo tail -f /var/log/syslog | grep "SYN-Flood-Detect"
   ```

---

## 📊 Langkah 4: Verifikasi & Deteksi di Wazuh Manager (VM1)
Sekarang, kita validasi apakah Wazuh Manager berhasil menganalisis log dari VM2 dan menaikkan alarm ke level kritis.

1. **Masuk ke VM1 (Wazuh Manager)** via SSH.
2. **Cek Log Alerts Aktif**:
   Jalankan perintah berikut untuk melihat apakah alert kustom (Rule `100011`) telah terpicu:
   ```bash
   sudo grep -A 5 '100011' /var/ossec/logs/alerts/alerts.log | tail -n 25
   ```
   *Hasil sukses ditunjukkan dengan adanya alert level 12 (CRITICAL) seperti di bawah ini:*
   ```text
   Rule: 100011 (level 12) -> '🔴 CRITICAL: Kemungkinan Serangan SYN Flood DDoS Sedang Berlangsung!'
   Src IP: 10.0.0.6 (IP VM3 Attacker)
   Dst IP: 10.0.0.5 (IP VM2 Target)
   Dst Port: 80
   ```

3. **Verifikasi via Wazuh Dashboard (UI)**:
   * Buka browser Anda dan akses: `https://4.194.10.103` (Abaikan warning HTTPS untrusted).
   * Login dengan user `admin` dan password Wazuh Anda.
   * Masuk ke menu **Security Events** -> **Events**.
   * Cari/Filter menggunakan Rule ID: `100011`.
   * Anda akan melihat visualisasi grafik batang yang melonjak tajam (*spike*) yang menandai terjadinya deteksi DDoS.

---

## 🛑 Langkah 5: Menghentikan Serangan & Pembersihan (Cleanup)
Setelah pengujian selesai dan seluruh screenshot/bukti deteksi berhasil diambil, hentikan proses serangan agar sistem kembali normal.

1. **Hentikan hping3 di VM3 (Attacker)**:
   Kembali ke terminal VM3 dan tekan **`Ctrl + C`**. Anda akan melihat ringkasan statistik seperti ini:
   ```text
   --- 10.0.0.5 hping statistic ---
   1983050 packets transmitted, 0 packets received, 100% packet loss
   ```
2. **Pastikan proses benar-benar mati**:
   Jika terminal hang atau terputus, Anda bisa memaksa menghentikan hping3 dengan perintah:
   ```bash
   sudo pkill -9 hping3
   ```
3. **Konfirmasi pemulihan**:
   Jalankan kembali `sudo iptables -L INPUT -v -n` di VM2 untuk memastikan angka counter paket sudah berhenti meningkat.

---

## 🔧 Troubleshooting Pengujian

| Masalah | Kemungkinan Penyebab | Solusi |
| :--- | :--- | :--- |
| **Tidak ada log `SYN-Flood-Detect:` di VM2** | Serangan dikirim ke IP Publik VM2, sehingga didrop oleh firewall Azure. | Jalankan `hping3` dengan menargetkan IP Internal VNet VM2 (`10.0.0.5`). |
| **Log ada di VM2, tapi alert `100011` tidak muncul di VM1** | Wazuh Agent VM2 belum merestart konfigurasinya atau ruleset di VM1 belum dimuat ulang. | Jalankan `sudo systemctl restart wazuh-agent` di VM2 dan `sudo systemctl restart wazuh-manager` di VM1. |
| **Log drops / Kehilangan Event di VM2** | Buffer Agen penuh karena banjir log yang terlampau cepat. | Pastikan `<client_buffer>` di `ossec.conf` VM2 sudah ditingkatkan ke `15000` queue size dan `1000` events per second. |
