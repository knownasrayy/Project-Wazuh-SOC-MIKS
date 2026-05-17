# 🛡️ Wazuh Manager Setup — Orang 2

Bagian ini mencakup instalasi dan konfigurasi **Wazuh Manager** (all-in-one: Manager + Indexer + Dashboard) di Azure VM1.

---

## 📋 Tanggung Jawab

- Install Wazuh Manager, Indexer, dan Dashboard di VM1
- Memastikan ketiga service berjalan (`active (running)`)
- Membuka akses dashboard untuk seluruh anggota tim
- Menyiapkan konfigurasi agar agent dari Orang 3 bisa terhubung

---

## 🖥️ Spesifikasi VM yang Digunakan

| Item | Detail |
|------|--------|
| VM Name | `vm1-manager` |
| Public IP | `4.194.10.103` |
| OS | Ubuntu 22.04+ |
| Size | B2s (2 vCPU, 4GB RAM) |
| Dashboard URL | `https://4.194.10.103` |

---

## 📁 Struktur Folder

```
wazuh-orang2/
├── README.md                  ← File ini
├── docs/
│   └── manager-setup.md       ← Langkah-langkah instalasi lengkap
├── scripts/
│   └── install-manager.sh     ← Script otomatis instalasi
└── config/
    └── ossec.conf             ← Template konfigurasi Wazuh Manager
```

---

## ⚡ Quick Start

```bash
# 1. SSH ke VM1 (Windows PowerShell)
ssh -i "C:\Users\NamaKamu\Downloads\miks-key.pem" azureuser@4.194.10.103

# 2. Download & jalankan installer
curl -sO https://packages.wazuh.com/4.7/wazuh-install.sh
sudo bash wazuh-install.sh -a -i

# 3. Ambil password
sudo tar -O -xvf wazuh-install-files.tar wazuh-install-files/wazuh-passwords.txt

# 4. Buka dashboard di browser
# https://4.194.10.103 → login: admin / <password dari step 3>
```

Panduan lengkap ada di [`docs/manager-setup.md`](docs/manager-setup.md)

---

## ✅ Hasil Akhir

Setelah setup selesai, bagikan ke grup chat:

```
🟢 Wazuh Manager sudah aktif!

🌐 Dashboard : https://4.194.10.103
👤 Username  : admin
🔑 Password  : <dari installer>

Orang 3 silakan mulai install agent!
```
# 🟡 Wazuh Agent Setup — Orang 3

Bagian ini mencakup instalasi dan enrollment **Wazuh Agent** di VM2 dan VM3, serta verifikasi koneksi ke Wazuh Manager di VM1.

---

## 📋 Tanggung Jawab

- Install Wazuh Agent di VM2 (agent-vm2) dan VM3 (agent-vm3)
- Enroll kedua agent ke Wazuh Manager di VM1
- Verifikasi kedua agent muncul di dashboard dengan status **Active**
- Siapkan dashboard monitoring untuk simulasi DDoS oleh Orang 4

---

## 🖥️ Spesifikasi VM

| VM | Role | Public IP | Agent Name |
|----|------|-----------|------------|
| VM1 | Wazuh Manager | `4.194.10.103` | — |
| VM2 | Agent 1 (Target) | `20.212.154.248` | `agent-vm2` |
| VM3 | Agent 2 (Attacker) | `4.194.60.80` | `agent-vm3` |

---

## 📁 Struktur Folder
```
miks-wazuh-azure-project/
├── README.md                  
├── docs/
│   └── manager-setup.md       
│   └── agent-setup.md       ← Langkah-langkah instalasi agent
├── scripts/
│   └── install-manager.sh     
│   └── install-agent.sh     ← Script otomatis instalasi agent
└── config/
    └── ossec.conf             
```
## ✅ Hasil Akhir

| Metric | Value |
|--------|-------|
| Total agents | 2 |
| Active agents | 2 |
| Disconnected | 0 |

Kedua agent berhasil terdaftar dan aktif di Wazuh Dashboard (Total: 2, Active: 2).
Bukti screenshot tersedia di folder documentation.
