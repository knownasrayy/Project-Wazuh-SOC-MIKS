# 📗 Panduan Instalasi Wazuh Manager

## Prasyarat

Sebelum mulai, pastikan sudah menerima dari Orang 1:
- ✅ File SSH key `miks-key.pem`
- ✅ Public IP VM1 (`4.194.10.103`)
- ✅ Konfirmasi VM1 sudah **Running** di Azure Portal
- ✅ Port 22, 443, 1514, 1515, 55000 sudah dibuka di NSG

---

## Langkah 1 — SSH ke VM1 dari Windows

Buka **PowerShell**, jalankan perintah berikut satu per satu:

```powershell
# Set permission key file (wajib, kalau skip akan error)
icacls "C:\Users\NamaKamu\Downloads\miks-key.pem" /inheritance:r
icacls "C:\Users\NamaKamu\Downloads\miks-key.pem" /grant:r "$($env:USERNAME):(R)"

# SSH ke VM1
ssh -i "C:\Users\NamaKamu\Downloads\miks-key.pem" azureuser@4.194.10.103
```

> Ganti `NamaKamu` dengan nama user Windows kamu.
> Cek nama user: ketik `echo $env:USERNAME` di PowerShell.

Kalau berhasil, prompt berubah menjadi:
```
azureuser@vm1-manager:~$
```

---

## Langkah 2 — Update System

```bash
sudo apt update && sudo apt upgrade -y
```

---

## Langkah 3 — Download Installer

```bash
# Perhatian: gunakan huruf O besar, bukan angka 0
curl -sO https://packages.wazuh.com/4.7/wazuh-install.sh
```

Verifikasi file berhasil didownload:
```bash
ls -la wazuh-install.sh
```

---

## Langkah 4 — Jalankan Installer

```bash
# Flag -a = all-in-one (Manager + Indexer + Dashboard)
# Flag -i = ignore OS check (untuk Ubuntu versi lebih baru dari 22.04)
sudo bash wazuh-install.sh -a -i
```

> ⏳ Proses ini memakan waktu **10–20 menit**. Jangan tutup PowerShell.

Di akhir instalasi akan muncul output seperti ini — **screenshot atau catat:**
```
INFO: --- Summary ---
INFO: You can access the web interface https://4.194.10.103
    User: admin
    Password: Duf3Ib5kZ6PFBU.kNxX+qBL1iP3h7.V3
```

Jika output tidak terlihat, ambil password dengan perintah:
```bash
sudo tar -O -xvf wazuh-install-files.tar wazuh-install-files/wazuh-passwords.txt
```

---

## Langkah 5 — Verifikasi Service

Jalankan ketiga perintah ini, masing-masing harus menampilkan `active (running)`:

```bash
sudo systemctl status wazuh-manager
```
```bash
sudo systemctl status wazuh-indexer
```
```bash
sudo systemctl status wazuh-dashboard
```

> Tekan `q` untuk keluar dari tampilan status sebelum menjalankan perintah berikutnya.

Jika ada service yang tidak running, jalankan:
```bash
sudo systemctl start wazuh-manager
sudo systemctl start wazuh-indexer
sudo systemctl start wazuh-dashboard
```

---

## Langkah 6 — Akses Dashboard

1. Buka **Chrome atau Edge** di laptop
2. Ketik di address bar: `https://4.194.10.103`
3. Saat muncul warning **"Your connection is not private"**:
   - Chrome: klik **Advanced → Proceed to 4.194.10.103 (unsafe)**
   - Edge: klik **Advanced → Continue to this website**
4. Login:
   - **Username:** `admin`
   - **Password:** (dari Langkah 4)

---

## Langkah 7 — Konfigurasi Logging Lengkap

```bash
sudo nano /var/ossec/etc/ossec.conf
```

Cari bagian `<global>` dan sesuaikan menjadi:

```xml
<global>
  <email_notification>no</email_notification>
  <logall>yes</logall>
  <logall_json>yes</logall_json>
</global>
```

Simpan: `Ctrl+X → Y → Enter`

Restart Manager agar konfigurasi berlaku:
```bash
sudo systemctl restart wazuh-manager
```

---

## Langkah 8 — Verifikasi Siap untuk Orang 3

```bash
sudo /var/ossec/bin/agent_control -l
```

Output normal: `No agent available.` — artinya Manager siap menerima koneksi dari agent.

---

## Troubleshooting

| Masalah | Solusi |
|---------|--------|
| `No such file or directory` saat install | Jalankan dulu `curl -sO` (pastikan huruf O besar) |
| `ERROR: The current system does not match` | Tambahkan flag `-i` di perintah installer |
| `Permission denied` saat SSH | Ulangi perintah `icacls` untuk set permission key |
| Dashboard tidak bisa dibuka di browser | Cek port 443 terbuka di NSG, cek service `wazuh-dashboard` running |
| Service `failed` saat dicek | Jalankan `sudo journalctl -u wazuh-manager -n 50` untuk lihat log error |
