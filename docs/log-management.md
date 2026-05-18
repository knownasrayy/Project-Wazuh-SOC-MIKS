# 📊 Manajemen Log (Kepadatan & Distribusi)

Dokumen ini menjelaskan strategi yang diterapkan untuk mengatasi masalah **Kepadatan Log (Log Density)** dan **Distribusi Log** saat terjadi insiden keamanan dengan volume tinggi, seperti serangan DDoS.

Tanpa manajemen log yang tepat, serangan DDoS dapat membanjiri (*flood*) agen Wazuh dan *network bandwidth*, menyebabkan *Event Dropped* atau kelebihan beban pada Wazuh Manager.

---

## 1. Anti-Flooding pada Wazuh Agent (VM2 - Target)

Wazuh menggunakan mekanisme *leaky bucket* untuk mencegah agen mengirim log terlalu cepat (yang bisa membuat server kelebihan beban). Kita akan melakukan *tuning* pada buffer klien (Client Buffer).

### Konfigurasi di `ossec.conf` (Wazuh Agent VM2)

Buka `sudo nano /var/ossec/etc/ossec.conf` dan temukan / tambahkan blok `<client_buffer>`:

```xml
  <client_buffer>
    <!-- Disable atau Enable buffer. Jika "no", agent akan mengirim log langsung tanpa antrean (bahaya saat DDoS) -->
    <disabled>no</disabled>
    
    <!-- Jumlah maksimum antrean event di memori agen (default 5000) -->
    <queue_size>10000</queue_size>
    
    <!-- Berapa event per detik (EPS) yang dikirim dari agent ke manager (default 500) -->
    <events_per_second>1000</events_per_second>
  </client_buffer>
```

**Penjelasan:**
- Dengan meningkatkan `queue_size`, agent dapat menampung sementara log dari kernel iptables (saat serangan terjadi) tanpa langsung menghapusnya (*dropped events*).
- Dengan meningkatkan `events_per_second` (EPS), agen dapat mendistribusikan log ke manager lebih cepat, mengurangi penumpukan di agent.

Setelah diubah, restart agen:
```bash
sudo systemctl restart wazuh-agent
```

---

## 2. Kepadatan dan Retensi Log pada Wazuh Manager (VM1)

Manager akan menerima jutaan baris log syslog saat terjadi serangan. Hal ini dapat membuat disk (Storage Azure) penuh seketika. 
Wazuh mengelola ini melalui fitur **Log Rotation** internal pada Indexer dan arsip file manager.

### Rotasi Alert File (`ossec.conf` Manager VM1)
Konfigurasi file ini dilakukan pada `/var/ossec/etc/ossec.conf` milik **Manager**.

```xml
  <global>
    <!-- Kapan log alerts.log dirotasi (default: setiap hari) -->
    <logall>yes</logall>
    <logall_json>yes</logall_json>
    <rotate_interval>1d</rotate_interval>
    <keep_log_days>31</keep_log_days>
  </global>
```
*Catatan: Saat produksi, Anda dapat mengubah `rotate_interval` menggunakan ukuran file (misalnya `<rotate_interval>500M</rotate_interval>`) jika serangan membuat log membengkak drastis dalam beberapa menit.*

### Kebijakan Retensi di Wazuh Indexer / Dashboard (ILM - Index Lifecycle Management)
1. Buka menu **Index Management** di Wazuh Dashboard (hamburger menu kiri atas).
2. Pergi ke **State management policies**.
3. Pastikan terdapat policy yang akan memindahkan Index lama ke status `Cold` atau `Delete` jika sudah melampaui umur (misal > 30 hari) atau ukuran maksimum (misal > 50 GB).

---

## 3. Distribusi dan Pengecualian Log (Log Filtering)

Saat DDoS, banyak log berulang. Untuk menghemat storage, kita dapat menggunakan rule kustom agar hanya peringatan tertentu yang diteruskan ke Wazuh Indexer, atau menurunkan *Rule Level* dari log berulang tersebut.

Gunakan rule bawaan Wazuh untuk memfilter (seperti *frequency* and *timeframe* pada XML local_rules):
Contohnya, sebuah *alert* hanya dipicu jika ada 100 log yang sama dalam 60 detik. (Lihat `config/ddos_rules.xml`).
