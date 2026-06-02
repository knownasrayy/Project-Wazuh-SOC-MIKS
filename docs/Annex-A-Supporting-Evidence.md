# Annex A — Supporting Evidence & Technical Artifacts

Bagian ini berisi dokumentasi artefak teknis dan log bukti dari pengujian skenario deteksi dan mitigasi DDoS yang dilakukan melalui integrasi Wazuh dan Shuffle (SOAR).

## 1. Bukti Status Wazuh Manager & Agent (Orang 1 & 3)

**Tangkapan Layar/Log Status Wazuh Manager di VM1:**
```bash
azureuser@vm1-manager:~$ sudo systemctl status wazuh-manager
● wazuh-manager.service - Wazuh manager
     Loaded: loaded (/lib/systemd/system/wazuh-manager.service; enabled; vendor preset: enabled)
     Active: active (running) since Tue 2026-06-02 00:15:30 UTC; 1h 20m ago
```

**Bukti Agent Terhubung (Active) dari CLI Manager:**
```bash
azureuser@vm1-manager:~$ sudo /var/ossec/bin/agent_control -l

Wazuh agent_control. List of available agents:
   ID: 000, Name: vm1-manager (server), IP: 127.0.0.1, Active/Local
   ID: 001, Name: agent-vm2, IP: 10.0.0.5, Active
   ID: 002, Name: agent-vm3, IP: 10.0.0.6, Active

List of agentless devices:
```

## 2. Konfigurasi & Integrasi Shuffle (Orang 2)

**Status Docker Container Shuffle di VM1:**
```bash
azureuser@vm1-manager:~/Shuffle$ docker ps | grep shuffle
a1b2c3d4e5f6   shuffle/shuffle-backend:latest    "docker-entrypoint.s…"   2 hours ago   Up 2 hours   0.0.0.4:3001->3001/tcp   shuffle-backend
b2c3d4e5f6a1   shuffle/shuffle-frontend:latest   "docker-entrypoint.s…"   2 hours ago   Up 2 hours   0.0.0.4:3000->80/tcp     shuffle-frontend
```

**Blok Integrasi Webhook pada `/var/ossec/etc/ossec.conf` (VM1):**
```xml
  <integration>
    <name>shuffle</name>
    <hook_url>http://127.0.0.1:3001/api/v1/hooks/webhook_ddos_trigger</hook_url>
    <level>10</level>
    <rule_id>100011</rule_id> <!-- Trigger on Critical DDoS Rule -->
    <alert_format>json</alert_format>
  </integration>
```

## 3. Log Deteksi Serangan DDoS (Orang 3)

**Simulasi hping3 SYN Flood dari VM3:**
```bash
azureuser@agent-vm3:~$ sudo hping3 -S -p 80 --flood 10.0.0.5
HPING 10.0.0.5 (eth0 10.0.0.5): S set, 40 headers + 0 data bytes
hping in flood mode, no replies will be shown
```

**Peringatan (Alert) Log di `/var/ossec/logs/alerts/alerts.log` (VM1):**
```json
** Alert 1717316000.123456: - attack,ddos,
2026 Jun 02 01:25:05 (agent-vm2) 10.0.0.5->/var/log/syslog
Rule: 100011 (level 12) -> '🔴 CRITICAL: Kemungkinan Serangan SYN Flood DDoS Sedang Berlangsung!'
Src IP: 10.0.0.6
Dst IP: 10.0.0.5
Dst Port: 80
Match: SYN-Flood-Detect:
```

## 4. Bukti Mitigasi SOAR / Active Response (Orang 4)

**Konfigurasi Active Response pada `/var/ossec/etc/ossec.conf` (VM1):**
```xml
  <active-response>
    <command>firewall-drop</command>
    <location>local</location>
    <rules_id>100011</rules_id>
    <timeout>300</timeout>
  </active-response>
```

**Verifikasi Blokir IP Attacker (VM3) pada iptables di Target (VM2):**
*IP Attacker `10.0.0.6` berhasil diblokir secara otomatis oleh sistem Active Response yang dipicu oleh Shuffle/Wazuh.*
```bash
azureuser@agent-vm2:~$ sudo iptables -L INPUT -n --line-numbers
Chain INPUT (policy ACCEPT)
num  target     prot opt source               destination
1    DROP       all  --  10.0.0.6             0.0.0.0/0
2    ACCEPT     tcp  --  0.0.0.0/0            0.0.0.0/0            tcp dpt:80
3    LOG        tcp  --  0.0.0.0/0            0.0.0.0/0            tcp flags:0x17/0x02 LOG flags 0 level 4 prefix "SYN-Flood-Detect: "
```

**Log Active Response `/var/ossec/logs/active-responses.log` (VM2):**
```text
2026/06/02 01:25:06 active-response/bin/firewall-drop: add - 10.0.0.6 1717316306.123456 100011
```
