# 📗 Panduan Instalasi Wazuh Agent

## Prasyarat

Sebelum mulai, pastikan sudah menerima dari Orang 2:
- ✅ File SSH key `miks-key.pem`
- ✅ Wazuh Manager sudah running di VM1 (`4.194.10.103`)
- ✅ Dashboard bisa diakses di `https://4.194.10.103`
- ✅ Port 1514, 1515 sudah dibuka di NSG Azure

---

## Langkah 1 — Persiapan SSH Key di WSL

```bash
# Copy key dari Windows ke home directory WSL
cp "/mnt/c/Users/<NamaKamu>/Documents/Semester 4/MIKS/miks-key.pem" ~/miks-key.pem

# Set permission (wajib, kalau skip akan error)
chmod 400 ~/miks-key.pem

# Verifikasi permission
ls -la ~/miks-key.pem
# Output harus: -r-------- 1 <user> ...
```

> ⚠️ Jangan taruh key di folder `/mnt/c/` karena Windows filesystem tidak support Linux permissions.

---

## Langkah 2 — Install Agent di VM2

SSH ke VM2:
```bash
ssh -i ~/miks-key.pem azureuser@20.212.154.248
```

Install Wazuh Agent:
```bash
# Tambah repo Wazuh dan install versi yang sesuai Manager (4.7.5)
sudo WAZUH_MANAGER="4.194.10.103" WAZUH_AGENT_NAME="agent-vm2" \
  bash -c "curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | apt-key add - && \
  echo 'deb https://packages.wazuh.com/4.x/apt/ stable main' > /etc/apt/sources.list.d/wazuh.list && \
  apt update && apt install -y wazuh-agent=4.7.5-1"
```

Start dan enable agent:
```bash
sudo systemctl start wazuh-agent
sudo systemctl enable wazuh-agent
sudo systemctl status wazuh-agent
```

Verifikasi koneksi ke Manager:
```bash
sudo grep "Connected to the server" /var/ossec/logs/ossec.log
# Output: INFO: (4102): Connected to the server ([4.194.10.103]:1514/tcp)
```

---

## Langkah 3 — Install Agent di VM3

Buka terminal baru, SSH ke VM3:
```bash
ssh -i ~/miks-key.pem azureuser@4.194.60.80
```

Install Wazuh Agent:
```bash
sudo WAZUH_MANAGER="4.194.10.103" WAZUH_AGENT_NAME="agent-vm3" \
  bash -c "curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | apt-key add - && \
  echo 'deb https://packages.wazuh.com/4.x/apt/ stable main' > /etc/apt/sources.list.d/wazuh.list && \
  apt update && apt install -y wazuh-agent=4.7.5-1"

sudo systemctl start wazuh-agent
sudo systemctl enable wazuh-agent
sudo systemctl status wazuh-agent
```

Verifikasi koneksi:
```bash
sudo grep "Connected to the server" /var/ossec/logs/ossec.log
```

---

## Langkah 4 — Verifikasi di Dashboard

1. Buka browser → `https://4.194.10.103`
2. Login: `admin` / `<password dari Orang 2>`
3. Masuk menu **Agents**
4. Pastikan muncul:
   - `agent-vm2` → Status: **Active** 🟢
   - `agent-vm3` → Status: **Active** 🟢

---

## Langkah 5 — Siapkan Monitor DDoS

Sebelum Orang 4 mulai serang, set filter di dashboard:
```
rule.groups: ddos
```

Jalankan bertahap, jangan langsung `--flood` penuh agar alert naik secara gradual dan bisa terdokumentasi.

---

## Troubleshooting

| Masalah | Penyebab | Solusi |
|---------|----------|--------|
| `Permission denied` saat SSH | Permission key terlalu terbuka | `chmod 400 ~/miks-key.pem` |
| `Agent version must be lower or equal to manager` | Versi agent lebih baru dari Manager | Downgrade agent: `apt install -y wazuh-agent=4.7.5-1` |
| Agent tidak muncul di dashboard | IP Manager salah di config | Cek `/var/ossec/etc/ossec.conf` → `<address>` |
| `chmod` tidak berpengaruh | File ada di `/mnt/c/` (Windows FS) | Pindahkan key ke `~/` (home WSL) dulu |
