# Evaluasi Program RBI Aceh

Repositori ini berisi data, skrip analisis, dan dashboard interaktif untuk
evaluasi dampak program **Recovery Basic Income (RBI)** &mdash; transfer
tunai sebesar **Rp300.000/jiwa/bulan selama 3 bulan** &mdash; di Aceh.

**Dashboard live:** `index.html` (lihat bagian [Menjalankan Dashboard](#menjalankan-dashboard))

---

## Ringkasan Temuan

| Indikator | Hasil |
|---|---|
| Estimasi dampak (DiD, skor pendapatan ordinal 1&ndash;3) | **+0.386** (SE clustered = 0.083, p < 0.001) |
| Estimasi dengan kovariat (usia, pendidikan, status nikah) | **+0.386** (p < 0.001) &mdash; identik, robust |
| Effect size (Cohen's d) | **0.79** (efek besar) |
| Skor Intervensi, Bulan 1 &rarr; 3 | 1.114 &rarr; 1.457 (p < 0.001) |
| Skor Kontrol, Bulan 1 &rarr; 3 | 1.057 &rarr; 1.014 (p = 0.083) |
| Sensitivity check (5 seed re-matching) | Estimasi DiD 0.364&ndash;0.403 |
| Balance check pasca-PSM | Semua kovariat p > 0.05 (setara) |

**Interpretasi singkat:** Setelah PSM 1:1 menghasilkan kelompok pembanding
yang setara karakteristik baseline, kelompok penerima RBI menunjukkan
peningkatan signifikan pada kategori pendapatan rumah tangga selama 3 bulan
intervensi, sementara kelompok kontrol relatif stagnan. Hasil ini stabil
terhadap penambahan kovariat demografis dan terhadap variasi proses matching.

---

## Desain Studi

- **Desain:** Kuasi-eksperimental dengan Propensity Score Matching (PSM) 1:1,
  caliper = 0,2 &times; SD propensity score (&asymp; 0,0674), `random_state = 42`.
- **Lokasi:**
  - Intervensi &mdash; Desa Pantai Perlak
  - Kontrol &mdash; Desa Blang Guron
- **Sampel:** 184 vs 184 responden awal &rarr; **70 vs 70 responden matched**
  (140 total, 420 observasi panel).
- **Periode:** 3 gelombang survei (Bulan 1, 2, 3).
- **Outcome utama:** `pendapatan_ordinal` &mdash; kategori pendapatan rumah
  tangga (1 = < Rp1,2 juta; 2 = Rp1,2 &ndash; <2,5 juta; 3 = Rp2,5 &ndash; <4,8 juta).
- **Metode estimasi dampak:** Difference-in-Differences (DiD), OLS dengan
  *standard error* di-cluster pada level pasangan PSM (`pair_id`).

---

## Struktur Repositori

```
.
├── index.html                          # Dashboard interaktif (Chart.js)
├── data/
│   ├── RBI_Aceh_Matched70vs70_Clean.xlsx   # Data sumber (panel + metadata)
│   ├── panel_long.csv                      # Data panel format long (420 baris)
│   ├── panel_wide.csv                      # Data panel format wide (140 baris)
│   └── dashboard_data.json                 # Data teragregasi untuk dashboard
├── scripts/
│   └── analisis_RBI_Aceh.R             # Skrip analisis R lengkap
├── output/                              # Grafik PNG hasil skrip R (dibuat saat run)
└── README.md
```

### Sheet dalam `RBI_Aceh_Matched70vs70_Clean.xlsx`

| Sheet | Isi |
|---|---|
| `Struktur_Data` | Deskripsi struktur dataset |
| `Codebook` | Definisi dan label setiap variabel |
| `Catatan_Matching` | Catatan proses PSM |
| `Catatan_Cleaning` | Catatan proses pembersihan data |
| `Balance_Check` | Hasil uji kesetaraan kovariat sebelum/sesudah PSM |
| `Sensitivity_PSM` | Hasil re-matching dengan 5 seed berbeda |
| `Pasangan_PSM` | Daftar pasangan hasil matching |
| `Panel_Long` | Data panel format long (1 baris = 1 responden x 1 bulan) |
| `Panel_Wide` | Data panel format wide (1 baris = 1 responden) |

---

## Menjalankan Analisis R

### Prasyarat

```r
install.packages(c("readxl","dplyr","tidyr","ggplot2","sandwich","lmtest","broom","scales"))
```

### Cara menjalankan

1. Clone/download repositori ini.
2. Buka R/RStudio dan **set working directory ke folder root repo** (folder
   yang berisi `data/` dan `scripts/`):
   ```r
   setwd("path/ke/folder/repo-ini")
   ```
3. Jalankan skrip:
   ```r
   source("scripts/analisis_RBI_Aceh.R")
   ```

### Output

- Seluruh hasil statistik (deskriptif, balance check, model DiD, uji t,
  effect size, sensitivity check) tercetak di Console.
- 7 grafik PNG (300 DPI) tersimpan ke folder `output/`:
  1. `01_tren_pendapatan_ordinal.png`
  2. `02_perubahan_diff_in_diff.png`
  3. `03_boxplot_pendapatan_per_bulan.png`
  4. `04_distribusi_kategori_pendapatan.png`
  5. `05_trajektori_individual.png`
  6. `06_perubahan_pengeluaran.png`
  7. `07_forest_plot_sensitivity.png`

---

## Menjalankan Dashboard

Dashboard (`index.html`) memuat data dari `data/dashboard_data.json` via
`fetch()`, sehingga **tidak bisa dibuka langsung sebagai file** (`file://`)
karena keterbatasan CORS pada sebagian browser. Jalankan local server
sederhana dari folder root repo:

```bash
python3 -m http.server
```

lalu buka `http://localhost:8000` di browser.

Atau, jika repo ini di-push ke GitHub, aktifkan **GitHub Pages** (Settings →
Pages → Deploy from branch) dan dashboard akan dapat diakses langsung via
URL `https://<username>.github.io/<repo>/`.

### Isi Dashboard

1. **Tren Pendapatan** &mdash; rata-rata skor pendapatan ordinal per kelompok per bulan.
2. **Estimasi DiD** &mdash; bar chart perubahan + tabel koefisien model.
3. **Distribusi Skor & Kategori** &mdash; interaktif per bulan (Bulan 1/2/3).
4. **Trajektori Individual** &mdash; garis tiap responden + tren rata-rata kelompok.
5. **Pengeluaran Rumah Tangga** &mdash; perbandingan deskriptif Bulan 1 vs 3 (Intervensi saja).
6. **Uji Robustness** &mdash; forest plot estimasi utama vs sensitivity check, tabel balance check dan sensitivity.

---

## Keterbatasan Data

1. **`pendapatan_ordinal` adalah ukuran kategorikal (1&ndash;3)**, bukan nilai
   rupiah aktual. Estimasi DiD dengan OLS pada variabel ini bersifat
   *linear-probability-like*; model ordinal logistic (mis. `MASS::polr`)
   direkomendasikan sebagai uji robustness tambahan.
2. **`pendapatan_numerik` (Rp)** memiliki *missing* sangat tinggi
   (100% pada kelompok Kontrol di semua bulan; 71% Intervensi secara
   keseluruhan), sehingga tidak digunakan sebagai outcome utama.
3. **Variabel pengeluaran** (`pengeluaran_pokok`, `belanja_makanan`,
   `belanja_kesehatan`, `belanja_pendidikan`) **hanya tersedia untuk kelompok
   Intervensi** &mdash; analisis pada variabel ini (Bagian 4/5) bersifat
   deskriptif, bukan estimasi kausal.
4. **Data pengeluaran Bulan 2 adalah duplikat persis dari Bulan 1** (bug
   pencatatan pada sumber data), sehingga perbandingan pengeluaran dilakukan
   hanya antara Bulan 1 dan Bulan 3.
5. **Sensitivity check (5 seed)** menguji stabilitas hasil terhadap variasi
   urutan/seed pada proses re-matching dari pool yang sudah matched (70 vs
   70), bukan pengujian ulang spesifikasi propensity score model dari pool
   asli (184 vs 184).

---

## Sitasi / Penggunaan

Repositori ini disusun untuk keperluan riset dan transparansi metodologis.
Silakan gunakan dan modifikasi skrip sesuai kebutuhan, dengan mencantumkan
sumber data dan metode sebagaimana dijelaskan di atas.
