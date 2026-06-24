**FINAL PROJECT — SOC MIKS1**

Reducing SOC False Alarms through a Human-AI Collaboration Model

Keamanan Jaringan & Manajemen Insiden  |  Genap 2024/2025

 

# **Gambaran Proyek**

**Tujuan:** Membangun sistem SOC berbasis Human-AI Collaboration yang mampu **mengurangi false alarm** tanpa mengorbankan akurasi deteksi ancaman.

 

| Komponen | Detail |
| ----- | ----- |
| **Infrastruktur** | Wazuh Manager \+ 2 Agent | Azure Free Tier Student VM |
| **Skenario** | DDoS  •  Malware  •  Social Engineering |
| **AI Model** | Klasifikasi FP vs TP — wajib bangun sendiri, NO third-party API |
| **SOAR** | Auto-response: block IP, isolasi agent, notifikasi — dibuktikan live |
| **Deliverables** | GitHub Repository (source code) \+ Laporan Akhir (PDF/Word) |

 

# **Progress Tim — Sudah Sampai Mana?**

 

| Item Pekerjaan | Status |
| ----- | :---: |
| Deploy Wazuh Manager di Azure (VM) | **SELESAI** |
| Deploy 2 Wazuh Agent di Azure (VM) | **SELESAI** |
| Custom rules deteksi DDoS (SYN/ICMP/HTTP Flood) | **SELESAI** |
| Simulasi serangan DDoS dengan hping3 | **SELESAI** |
| Validasi modul Malware (EICAR test file) | **SELESAI** |
| Analisis Logging Density \+ mitigasi (Anti-Flooding, Log Rotation) | **SELESAI** |
| Web server target untuk DDoS (Nginx/Apache di Agent) | **BELUM** |
| Bukti dampak DDoS ke web (response time / timeout) | **BELUM** |
| Skenario Malware lengkap (upload \+ eksekusi file berbahaya) | **BELUM** |
| Skenario Social Engineering (phishing / fake login) | **BELUM** |
| Dataset alert berlabel (True Positive vs False Positive) | **BELUM** |
| Model AI klasifikasi FP vs TP (tanpa third-party API) | **BELUM** |
| Integrasi model AI ke pipeline Wazuh | **BELUM** |
| Platform SOAR \+ playbook auto-response | **BELUM** |
| Benchmark metrics (sebelum vs sesudah AI) | **BELUM** |
| Laporan akhir & GitHub repository final | **BELUM** |

 

**Kesimpulan:** Infrastruktur Wazuh sudah siap. Yang belum ada adalah **web server target, dataset berlabel, model AI, integrasi AI-Wazuh, SOAR, dan benchmark** — semuanya adalah inti dari Final Project ini.

 

# **Pembagian Tugas — 8 Anggota**

 

| ID | Nama | Peran | Nama Anggota | Fokus Utama |
| :---: | :---: | ----- | ----- | ----- |
| **A1** | **A1** | **Infrastructure & Web Server** | \[Nama 1\] | Deploy web server di Agent, pastikan infrastruktur Azure siap untuk semua skenario baru |
| **A2** | **A2** | **Red Team — DDoS & Pengukuran Dampak** | \[Nama 2\] | Eksekusi serangan DDoS ke web server dan dokumentasikan dampak nyata ke performa web |
| **A3** | **A3** | **Red Team — Malware & Social Engineering** | \[Nama 3\] | Simulasikan skenario Malware dan Social Engineering agar Wazuh menghasilkan alert bervariasi |
| **A4** | **A4** | **SOC Analyst — Labeling Dataset** | \[Nama 4\] | Kumpulkan semua alert Wazuh dari 3 skenario, labeli secara manual menjadi dataset training AI |
| **A5** | **A5** | **AI Engineer — Model Development** | \[Nama 5\] | Bangun dan latih model ML dari dataset Wazuh untuk mengklasifikasikan FP vs TP |
| **A6** | **A6** | **AI Engineer — Integration ke Wazuh** | \[Nama 6\] | Integrasikan model AI ke pipeline Wazuh agar alert secara otomatis difilter real-time |
| **A7** | **A7** | **SOAR Engineer** | \[Nama 7\] | Konfigurasi SOAR agar secara otomatis merespons serangan nyata (TP) yang lolos dari filter AI |
| **A8** | **A8** | **Benchmarking, QA & Laporan** | \[Nama 8\] | Ukur efektivitas sistem AI (sebelum vs sesudah), pastikan repo rapi, dan susun laporan akhir |

 

# **Alur Ketergantungan Tugas (Workflow)**

 

Pengerjaan harus mengikuti urutan dependensi berikut — komponen hilir tidak bisa dimulai sebelum komponen hulu selesai:

 

| Fase | Anggota | Output Utama | Dibutuhkan Oleh | Dapat Dimulai Setelah | Paralel? |
| :---: | ----- | ----- | ----- | ----- | :---: |
| **1** | **A1 — Infrastructure** | Web server \+ SOAR terinstall | A2, A3, A6, A7 | Langsung (tidak ada dependensi) | **Mulai duluan** |
| **2** | **A2 — DDoS Attack** | Alert DDoS \+ bukti dampak web | A4 (dataset) | A1 selesai | **Paralel A3** |
| **2** | **A3 — Malware & SE** | Alert Malware \+ SE terdokumentasi | A4 (dataset) | A1 selesai | **Paralel A2** |
| **3** | **A4 — Dataset Labeling** | Dataset CSV berlabel FP/TP | A5 (training) | A2 \+ A3 selesai | **Tunggu A2 & A3** |
| **4** | **A5 — AI Model** | Model .pkl \+ evaluasi metrics | A6 (integrasi) | A4 selesai | **Tunggu A4** |
| **5** | **A6 — AI Integration** | Alert Wazuh ber-verdict AI | A7, A8 | A5 selesai \+ A1 selesai | **Tunggu A5** |
| **5** | **A7 — SOAR** | Playbook aktif \+ bukti eksekusi | A8 (benchmark) | A6 selesai \+ A1 selesai | **Paralel A6 setup** |
| **6** | **A8 — Benchmark & Laporan** | Laporan akhir \+ repo final | — (endpoint) | A5 \+ A6 \+ A7 selesai | **Terakhir** |

 

**Catatan:** A8 boleh mulai menyusun kerangka laporan dan struktur GitHub sejak awal, tapi benchmark baru bisa dihitung setelah A5-A7 selesai.

 

# **Detail Tugas Tiap Anggota**

 

**A1  Infrastructure & Web Server**

| Nama Anggota | \[Nama 1\] |
| :---- | :---- |
| **Fokus** | Deploy web server di Agent, pastikan infrastruktur Azure siap untuk semua skenario baru |
| **Tugas Teknis** | •      Install & konfigurasi Nginx di Wazuh Agent sebagai web server target •      Konfigurasi ulang NSG Azure (buka port 80/443 untuk target serangan) •      Setup monitoring response time web (Apache Bench / curl timing) •      Konfigurasi log Nginx agar masuk ke Wazuh monitoring •      Deploy & konfigurasi SOAR platform (Shuffle/n8n) di VM Manager |
| **Deliverables** | •      Web server aktif & dapat diakses dari VM attacker •      SOAR platform terinstall & terhubung ke Wazuh API •      Dokumentasi konfigurasi infrastruktur (screenshot Azure \+ config files) |
| **Butuh dari** | — |
| **Dibutuhkan oleh** | A2, A3 |

 

**A2  Red Team — DDoS & Pengukuran Dampak**

| Nama Anggota | \[Nama 2\] |
| :---- | :---- |
| **Fokus** | Eksekusi serangan DDoS ke web server dan dokumentasikan dampak nyata ke performa web |
| **Tugas Teknis** | •      Jalankan serangan DDoS ke web server: hping3 SYN flood, ICMP flood, HTTP flood •      Ukur response time web sebelum serangan (baseline) dengan Apache Bench / curl •      Ukur response time saat serangan aktif — capture timeout & penurunan performa •      Screenshot bukti: web tidak dapat diakses / response time melonjak •      Variasikan intensitas serangan (low/medium/high) untuk menghasilkan dataset variatif |
| **Deliverables** | •      Screenshot web server timeout / response time degradation saat DDoS •      Log serangan (command \+ output hping3) per skenario •      Raw alert export dari Wazuh untuk skenario DDoS (JSON/CSV) |
| **Butuh dari** | A1 (web server harus aktif) |
| **Dibutuhkan oleh** | A4 (data untuk labeling) |

 

**A3  Red Team — Malware & Social Engineering**

| Nama Anggota | \[Nama 3\] |
| :---- | :---- |
| **Fokus** | Simulasikan skenario Malware dan Social Engineering agar Wazuh menghasilkan alert bervariasi |
| **Tugas Teknis** | •      Skenario Malware: upload EICAR \+ file simulasi berbahaya, jalankan di Agent, trigger Wazuh rule •      Buat script bash yang mensimulasikan perilaku malware (mass file write, fork bomb terbatas) •      Skenario Social Engineering: buat fake login page HTML di web server, log akses credential •      Trigger Wazuh alert untuk login brute force (hydra / medusa ke SSH) •      Dokumentasikan command dan langkah tiap skenario secara detail |
| **Deliverables** | •      Bukti simulasi Malware \+ alert Wazuh yang terpicu •      Fake login page / skenario phishing yang terdokumentasi •      Raw alert export dari Wazuh untuk skenario Malware & Social Engineering |
| **Butuh dari** | A1 (web server \+ infrastruktur siap) |
| **Dibutuhkan oleh** | A4 (data untuk labeling) |

 

**A4  SOC Analyst — Labeling Dataset**

| Nama Anggota | \[Nama 4\] |
| :---- | :---- |
| **Fokus** | Kumpulkan semua alert Wazuh dari 3 skenario, labeli secara manual menjadi dataset training AI |
| **Tugas Teknis** | •      Export alert dari Wazuh API atau Elasticsearch (format JSON → CSV) •      Normalisasi field: rule.id, rule.level, rule.description, agent.name, timestamp, dll •      Labeli tiap alert: 1 \= True Positive (serangan nyata), 0 \= False Positive (noise/salah deteksi) •      Buat kriteria false alarm secara mandiri (contoh: rule.level \< 7 \+ pola tertentu \= FP) •      Pastikan dataset balanced: minimal 300 TP \+ 300 FP, total min. 600 baris |
| **Deliverables** | •      Dataset CSV: kolom fitur Wazuh \+ kolom label (0/1) •      Dokumen kriteria false alarm yang digunakan •      Statistik distribusi dataset (jumlah TP vs FP per skenario) |
| **Butuh dari** | A2 \+ A3 (alert dari semua skenario harus sudah ada) |
| **Dibutuhkan oleh** | A5 (data untuk training model) |

 

**A5  AI Engineer — Model Development**

| Nama Anggota | \[Nama 5\] |
| :---- | :---- |
| **Fokus** | Bangun dan latih model ML dari dataset Wazuh untuk mengklasifikasikan FP vs TP |
| **Tugas Teknis** | •      Feature engineering: encode rule.id, normalisasi rule.level, extract fitur dari timestamp •      Split dataset: 80% train, 20% test — gunakan stratified split •      Latih minimal 3 model: Random Forest, Decision Tree, SVM/Logistic Regression •      Evaluasi: accuracy, precision, recall, F1-score, confusion matrix per model •      Pilih model terbaik, tuning hyperparameter (GridSearchCV), export ke .pkl |
| **Deliverables** | •      Jupyter Notebook: EDA \+ training \+ evaluasi semua model •      Model file terbaik (.pkl / joblib) •      Tabel perbandingan performa 3 model |
| **Butuh dari** | A4 (dataset berlabel) |
| **Dibutuhkan oleh** | A6 (model siap diintegrasikan) |

 

**A6  AI Engineer — Integration ke Wazuh**

| Nama Anggota | \[Nama 6\] |
| :---- | :---- |
| **Fokus** | Integrasikan model AI ke pipeline Wazuh agar alert secara otomatis difilter real-time |
| **Tugas Teknis** | •      Buat script Python: polling Wazuh API → ambil alert baru → prediksi FP/TP dengan model •      Tambahkan field custom ke alert: ai\_verdict: TP/FP, ai\_confidence: 0.0–1.0 •      Konfigurasi Wazuh active response: alert FP di-suppress / di-tag, TP diteruskan ke SOAR •      Buat simple REST endpoint (Flask) sebagai AI inference server agar bisa dipanggil Wazuh •      Testing end-to-end: simulasikan serangan → cek apakah AI verdict muncul di alert |
| **Deliverables** | •      Script integrasi AI-Wazuh (Python) •      Screenshot alert dengan field ai\_verdict dari Wazuh Dashboard •      Dokumentasi alur integrasi (diagram atau penjelasan tertulis) |
| **Butuh dari** | A5 (model .pkl), A1 (infrastruktur \+ Wazuh API aktif) |
| **Dibutuhkan oleh** | A7 (SOAR hanya proses alert TP) |

 

**A7  SOAR Engineer**

| Nama Anggota | \[Nama 7\] |
| :---- | :---- |
| **Fokus** | Konfigurasi SOAR agar secara otomatis merespons serangan nyata (TP) yang lolos dari filter AI |
| **Tugas Teknis** | •      Buat playbook SOAR \#1: DDoS terdeteksi → block IP attacker via firewall Azure NSG •      Buat playbook SOAR \#2: Malware terdeteksi → kirim notifikasi (webhook/email) \+ isolasi agent •      Integrasikan SOAR dengan Wazuh: trigger playbook dari alert Wazuh ber-verdict TP •      Testing: jalankan serangan → pastikan SOAR auto-block tanpa intervensi manual •      Dokumentasikan workflow tiap playbook (flowchart input → aksi → output) |
| **Deliverables** | •      Playbook SOAR aktif untuk DDoS dan Malware (screenshot konfigurasi) •      Bukti SOAR bekerja: log eksekusi playbook saat serangan terjadi •      Diagram workflow SOAR untuk laporan |
| **Butuh dari** | A6 (AI verdict sudah ada di alert), A1 (SOAR platform terinstall) |
| **Dibutuhkan oleh** | A8 (benchmark lengkap) |

 

**A8  Benchmarking, QA & Laporan**

| Nama Anggota | \[Nama 8\] |
| :---- | :---- |
| **Fokus** | Ukur efektivitas sistem AI (sebelum vs sesudah), pastikan repo rapi, dan susun laporan akhir |
| **Tugas Teknis** | •      Hitung metrics sebelum AI: False Positive Rate, True Positive Rate, jumlah alert total •      Hitung metrics sesudah AI: bandingkan FPR, TPR, alert reduction rate •      Buat tabel & grafik perbandingan (matplotlib / Excel) untuk laporan •      Review dan rapi-kan GitHub repo: folder structure, README, komentar kode semua anggota •      Susun laporan akhir lengkap: gabungkan kontribusi A1–A7 \+ analisis hasil |
| **Deliverables** | •      Tabel benchmark: FPR/TPR/F1 sebelum vs sesudah AI •      Grafik perbandingan alert sebelum dan sesudah AI aktif •      GitHub repo final yang rapi \+ README lengkap •      Laporan akhir (PDF) — semua bab |
| **Butuh dari** | A5 \+ A6 \+ A7 (semua komponen harus sudah berjalan) |
| **Dibutuhkan oleh** | — (endpoint) |

 

 

SOC Final Project  |  MIKS1  |  Genap 2024/2025  
