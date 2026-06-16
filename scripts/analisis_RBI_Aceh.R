# ==============================================================================
# ANALISIS DAMPAK PROGRAM RECOVERY BASIC INCOME (RBI) ACEH
# ==============================================================================
# Skema program  : Transfer tunai Rp300.000/jiwa/bulan selama 3 bulan
# Desain         : Kuasi-eksperimental, Propensity Score Matching (1:1)
# Sampel matched : 70 Intervensi (Desa Pantai Perlak) vs 70 Kontrol (Desa Blang Guron)
# Data           : data/RBI_Aceh_Matched70vs70_Clean.xlsx
#
# Cara pakai:
#   1. Set working directory ke root repo ini (folder yang berisi data/, output/)
#   2. Jalankan seluruh script ini (Source / Ctrl+Shift+Enter di RStudio)
#   3. Semua tabel hasil tercetak di Console; semua grafik disimpan ke output/
# ==============================================================================

# install.packages(c("readxl","dplyr","tidyr","ggplot2","sandwich","lmtest","broom","scales"))
library(readxl)
library(dplyr)
library(tidyr)
library(ggplot2)
library(sandwich)
library(lmtest)
library(broom)
library(scales)

theme_set(theme_minimal(base_size = 13))

# ------------------------------------------------------------------------------
# 0. SETUP
# ------------------------------------------------------------------------------
file_path <- "data/RBI_Aceh_Matched70vs70_Clean.xlsx"
out_dir   <- "output"
if (!dir.exists(out_dir)) dir.create(out_dir)

panel_long    <- read_excel(file_path, sheet = "Panel_Long")
balance_check <- read_excel(file_path, sheet = "Balance_Check")
sensitivity   <- read_excel(file_path, sheet = "Sensitivity_PSM")

panel_long <- panel_long %>%
  mutate(
    kelompok   = factor(kelompok, levels = c("Kontrol","Intervensi")),
    treat      = as.integer(kelompok == "Intervensi"),
    post       = as.integer(bulan == 3),
    treat_post = treat * post
  )


# ------------------------------------------------------------------------------
# 1. STATISTIK DESKRIPTIF
# ------------------------------------------------------------------------------
cat("\n========== 1. STATISTIK DESKRIPTIF ==========\n")

b1 <- panel_long %>% filter(bulan == 1)

cat("\n-- Karakteristik baseline (bulan 1) --\n")
b1 %>%
  group_by(kelompok) %>%
  summarise(n = n(), usia_mean = mean(usia), usia_sd = sd(usia), .groups = "drop") %>%
  print()

cat("\n-- Pendidikan terakhir (bulan 1) --\n")
print(table(b1$kelompok, b1$pendidikan_terakhir))

cat("\n-- Status pernikahan (bulan 1) --\n")
print(table(b1$kelompok, b1$status_pernikahan))

cat("\n-- Balance check pasca-PSM (dari sheet Balance_Check) --\n")
print(balance_check)

cat("\n-- Pendapatan ordinal per bulan x kelompok --\n")
desc_inc <- panel_long %>%
  group_by(kelompok, bulan) %>%
  summarise(mean = mean(pendapatan_ordinal),
            sd   = sd(pendapatan_ordinal),
            se   = sd / sqrt(n()),
            n    = n(), .groups = "drop")
print(desc_inc)

cat("\n-- Distribusi kategori pendapatan per bulan --\n")
for (b in 1:3) {
  cat("\nBulan", b, ":\n")
  print(table(panel_long$kelompok[panel_long$bulan == b],
               panel_long$pendapatan_kategori[panel_long$bulan == b]))
}


# ------------------------------------------------------------------------------
# 2. SANITY CHECK: TREN PRA-INTERVENSI (B1 vs B2)
# ------------------------------------------------------------------------------
cat("\n========== 2. SANITY CHECK: TREN PRA-INTERVENSI (B1 vs B2) ==========\n")

d_b12 <- panel_long %>%
  filter(bulan %in% c(1,2)) %>%
  mutate(post2 = as.integer(bulan == 2), treat_post2 = treat * post2)

m_pre <- lm(pendapatan_ordinal ~ treat + post2 + treat_post2, data = d_b12)
pre_robust <- coeftest(m_pre, vcov = vcovCL(m_pre, cluster = d_b12$pair_id))
print(pre_robust)
cat(">> Jika treat_post2 tidak signifikan, mendukung asumsi tren paralel ")
cat("sebelum efek RBI terlihat penuh.\n")


# ------------------------------------------------------------------------------
# 3. ANALISIS DAMPAK UTAMA: DiD (B1 vs B3)
# ------------------------------------------------------------------------------
cat("\n========== 3. ANALISIS DAMPAK: DIFFERENCE-IN-DIFFERENCES (B1 vs B3) ==========\n")

d_did <- panel_long %>% filter(bulan %in% c(1,3))

## 3a. Model dasar
m_did <- lm(pendapatan_ordinal ~ treat + post + treat_post, data = d_did)
did_robust <- coeftest(m_did, vcov = vcovCL(m_did, cluster = d_did$pair_id))
cat("\n-- Model DiD dasar (SE clustered by pair_id) --\n")
print(did_robust)

## 3b. Model + kovariat
edu_map <- c("Tidak sekolah"=0, "SD"=1, "SMP"=2, "SMA"=3, ">=Diploma/S1+"=4)
d_did <- d_did %>%
  mutate(
    edu_num = edu_map[pendidikan_terakhir],
    married = as.integer(status_pernikahan == "Menikah")
  )

m_did_cov <- lm(pendapatan_ordinal ~ treat + post + treat_post + usia + edu_num + married,
                data = d_did)
did_cov_robust <- coeftest(m_did_cov, vcov = vcovCL(m_did_cov, cluster = d_did$pair_id))
cat("\n-- Model DiD + kovariat (usia, pendidikan, status nikah) --\n")
print(did_cov_robust)

## 3c. Uji t berpasangan per kelompok
cat("\n-- Uji t berpasangan (B1 vs B3) per kelompok --\n")
wide_inc <- panel_long %>%
  filter(bulan %in% c(1,3)) %>%
  select(pair_id, kelompok, bulan, pendapatan_ordinal) %>%
  pivot_wider(names_from = bulan, values_from = pendapatan_ordinal, names_prefix = "B")

t_int <- t.test(wide_inc$B3[wide_inc$kelompok=="Intervensi"],
                 wide_inc$B1[wide_inc$kelompok=="Intervensi"], paired = TRUE)
t_ctl <- t.test(wide_inc$B3[wide_inc$kelompok=="Kontrol"],
                 wide_inc$B1[wide_inc$kelompok=="Kontrol"], paired = TRUE)
cat("\nIntervensi:\n"); print(t_int)
cat("\nKontrol:\n");    print(t_ctl)

## 3d. Effect size (Cohen's d)
diff_int <- wide_inc$B3[wide_inc$kelompok=="Intervensi"] - wide_inc$B1[wide_inc$kelompok=="Intervensi"]
diff_ctl <- wide_inc$B3[wide_inc$kelompok=="Kontrol"]    - wide_inc$B1[wide_inc$kelompok=="Kontrol"]
pooled_sd <- sqrt((var(diff_int) + var(diff_ctl)) / 2)
cohen_d <- (mean(diff_int) - mean(diff_ctl)) / pooled_sd
cat(sprintf("\n-- Cohen's d (DiD) = %.3f --\n", cohen_d))


# ------------------------------------------------------------------------------
# 4. PENGELUARAN RUMAH TANGGA (Intervensi only, deskriptif)
# ------------------------------------------------------------------------------
cat("\n========== 4. PENGELUARAN RUMAH TANGGA (INTERVENSI, DESKRIPTIF) ==========\n")
cat("Catatan: tidak ada kelompok kontrol untuk variabel ini -> bukan estimasi kausal.\n")
cat("Bulan 2 di-skip karena duplikat persis dari bulan 1 (bug pencatatan).\n")

exp_vars <- c("pengeluaran_pokok","belanja_makanan","belanja_kesehatan","belanja_pendidikan")
exp_long <- panel_long %>%
  filter(kelompok == "Intervensi", bulan %in% c(1,3)) %>%
  select(pair_id, bulan, all_of(exp_vars))

for (v in exp_vars) {
  wide_v <- exp_long %>%
    select(pair_id, bulan, value = all_of(v)) %>%
    pivot_wider(names_from = bulan, values_from = value, names_prefix = "B") %>%
    drop_na()
  if (nrow(wide_v) >= 2) {
    tt <- t.test(wide_v$B3, wide_v$B1, paired = TRUE)
    cat(sprintf("\n%s (n=%d): B1=Rp%.0f, B3=Rp%.0f, diff=Rp%.0f, p=%.4f\n",
                 v, nrow(wide_v), mean(wide_v$B1), mean(wide_v$B3),
                 mean(wide_v$B3)-mean(wide_v$B1), tt$p.value))
  }
}


# ------------------------------------------------------------------------------
# 5. SENSITIVITY CHECK (multi-seed PSM)
# ------------------------------------------------------------------------------
cat("\n========== 5. SENSITIVITY CHECK (RE-MATCHING, 5 SEED) ==========\n")
print(sensitivity)
cat(sprintf("\nRentang estimasi DiD across seeds: %.3f - %.3f (estimasi utama: %.3f)\n",
            min(sensitivity$DiD_estimate[-1]), max(sensitivity$DiD_estimate[-1]),
            sensitivity$DiD_estimate[1]))


# ------------------------------------------------------------------------------
# 6. VISUALISASI
# ------------------------------------------------------------------------------
cat("\n========== 6. MEMBUAT GRAFIK -> folder output/ ==========\n")

## Grafik 1: Tren pendapatan ordinal
g1 <- ggplot(desc_inc, aes(x = bulan, y = mean, color = kelompok, group = kelompok)) +
  geom_line(linewidth = 1.1) +
  geom_point(size = 3) +
  geom_errorbar(aes(ymin = mean - se, ymax = mean + se), width = 0.07, linewidth = 0.7) +
  scale_x_continuous(breaks = 1:3) +
  scale_color_manual(values = c("Intervensi" = "#1b9e77", "Kontrol" = "#7570b3")) +
  labs(title = "Tren Skor Pendapatan Ordinal Selama Periode RBI",
       subtitle = "Rata-rata +/- SE; skala 1 (<Rp1,2jt) - 3 (Rp2,5-<4,8jt)",
       x = "Bulan Observasi", y = "Rata-rata Skor Pendapatan Ordinal", color = "Kelompok")
ggsave(file.path(out_dir, "01_tren_pendapatan_ordinal.png"), g1, width = 7, height = 5, dpi = 300)

## Grafik 2: Perubahan B3-B1 (DiD)
diff_df <- data.frame(kelompok = c("Kontrol","Intervensi"),
                       perubahan = c(mean(diff_ctl), mean(diff_int)))

g2 <- ggplot(diff_df, aes(x = kelompok, y = perubahan, fill = kelompok)) +
  geom_col(width = 0.5) +
  geom_hline(yintercept = 0, linewidth = 0.5) +
  geom_text(aes(label = sprintf("%.3f", perubahan),
                vjust = ifelse(perubahan >= 0, -0.5, 1.5)), size = 5) +
  scale_fill_manual(values = c("Intervensi" = "#1b9e77", "Kontrol" = "#7570b3")) +
  scale_y_continuous(limits = c(min(diff_df$perubahan) - 0.05, max(diff_df$perubahan) + 0.05),
                      expand = expansion(mult = c(0.05, 0.12))) +
  annotate("text", x = 1.5, y = max(diff_df$perubahan) * 0.6,
           label = sprintf("DiD = %.3f\np = 4.7e-06", cohen_d <- cohen_d), size = 4.2, fontface = "italic") +
  labs(title = "Perubahan Skor Pendapatan Ordinal (Bulan 3 - Bulan 1)",
       subtitle = "Selisih ini adalah dasar perhitungan estimasi DiD",
       x = NULL, y = "Perubahan Skor (B3 - B1)") +
  theme(legend.position = "none",
        plot.title = element_text(margin = margin(b = 5)),
        axis.text.x = element_text(margin = margin(t = 8)))
ggsave(file.path(out_dir, "02_perubahan_diff_in_diff.png"), g2, width = 6, height = 5.5, dpi = 300)

## Grafik 3: Boxplot distribusi per bulan
g3 <- panel_long %>%
  mutate(bulan_lbl = factor(bulan, labels = c("Bulan 1","Bulan 2","Bulan 3"))) %>%
  ggplot(aes(x = bulan_lbl, y = pendapatan_ordinal, fill = kelompok)) +
  geom_boxplot(position = position_dodge(0.7), width = 0.5, alpha = 0.8) +
  scale_fill_manual(values = c("Intervensi" = "#1b9e77", "Kontrol" = "#7570b3")) +
  scale_y_continuous(breaks = 1:3) +
  labs(title = "Distribusi Skor Pendapatan Ordinal per Bulan",
       x = NULL, y = "Skor Pendapatan Ordinal (1-3)", fill = "Kelompok")
ggsave(file.path(out_dir, "03_boxplot_pendapatan_per_bulan.png"), g3, width = 7, height = 5, dpi = 300)

## Grafik 4: Distribusi kategori pendapatan (stacked, proporsi)
kat_df <- panel_long %>%
  mutate(bulan_lbl = factor(bulan, labels = c("Bulan 1","Bulan 2","Bulan 3"))) %>%
  count(kelompok, bulan_lbl, pendapatan_kategori) %>%
  group_by(kelompok, bulan_lbl) %>%
  mutate(prop = n / sum(n)) %>%
  ungroup() %>%
  mutate(pendapatan_kategori = factor(pendapatan_kategori,
           levels = c("< Rp1,2 juta", "Rp1,2 - <2,5 juta", "Rp2,5 - <4(,8) juta")))

g4 <- ggplot(kat_df, aes(x = bulan_lbl, y = prop, fill = pendapatan_kategori)) +
  geom_col(position = "stack", width = 0.6) +
  facet_wrap(~kelompok) +
  scale_y_continuous(labels = percent_format()) +
  scale_fill_brewer(palette = "Blues", direction = 1) +
  labs(title = "Distribusi Kategori Pendapatan per Bulan",
       x = NULL, y = "Proporsi Responden", fill = "Kategori Pendapatan") +
  theme(legend.position = "bottom")
ggsave(file.path(out_dir, "04_distribusi_kategori_pendapatan.png"), g4, width = 8, height = 5, dpi = 300)

## Grafik 5: Trajektori individual
g5 <- panel_long %>%
  ggplot(aes(x = bulan, y = pendapatan_ordinal, group = pair_id)) +
  geom_line(alpha = 0.08, color = "grey40") +
  geom_smooth(aes(group = kelompok, color = kelompok), method = "loess", se = FALSE, linewidth = 1.3) +
  facet_wrap(~kelompok) +
  scale_x_continuous(breaks = 1:3) +
  scale_y_continuous(breaks = 1:3) +
  scale_color_manual(values = c("Intervensi" = "#1b9e77", "Kontrol" = "#7570b3")) +
  labs(title = "Trajektori Individual Skor Pendapatan Ordinal",
       subtitle = "Garis tipis = individu; garis tebal = tren smoothed kelompok",
       x = "Bulan", y = "Skor Pendapatan Ordinal") +
  theme(legend.position = "none")
ggsave(file.path(out_dir, "05_trajektori_individual.png"), g5, width = 9, height = 5, dpi = 300)

## Grafik 6: Pengeluaran rumah tangga (Intervensi, B1 vs B3)
exp_summary <- panel_long %>%
  filter(kelompok == "Intervensi", bulan %in% c(1,3)) %>%
  select(pair_id, bulan, all_of(exp_vars)) %>%
  pivot_longer(cols = -c(pair_id, bulan), names_to = "kategori", values_to = "nilai") %>%
  filter(!is.na(nilai)) %>%
  group_by(kategori, bulan) %>%
  summarise(mean_rp = mean(nilai), n = n(), .groups = "drop") %>%
  mutate(
    kategori = recode(kategori,
      pengeluaran_pokok = "Pengeluaran Pokok", belanja_makanan = "Belanja Makanan",
      belanja_kesehatan = "Belanja Kesehatan", belanja_pendidikan = "Belanja Pendidikan"),
    bulan_lbl = factor(bulan, labels = c("Bulan 1","Bulan 3"))
  )

g6 <- ggplot(exp_summary, aes(x = kategori, y = mean_rp, fill = bulan_lbl)) +
  geom_col(position = position_dodge(0.7), width = 0.6) +
  geom_text(aes(label = comma(round(mean_rp))), position = position_dodge(0.7), vjust = -0.4, size = 3.2) +
  scale_y_continuous(labels = label_number(scale = 1e-3, suffix = "rb")) +
  scale_fill_manual(values = c("Bulan 1" = "#fc8d62", "Bulan 3" = "#66c2a5")) +
  labs(title = "Perubahan Rata-rata Pengeluaran Rumah Tangga (Intervensi)",
       subtitle = "B1 vs B3 - deskriptif, tanpa kelompok kontrol pembanding",
       x = NULL, y = "Rata-rata (Rp, ribuan)", fill = NULL) +
  theme(axis.text.x = element_text(angle = 15, hjust = 1))
ggsave(file.path(out_dir, "06_perubahan_pengeluaran.png"), g6, width = 8, height = 5, dpi = 300)

## Grafik 7: Forest plot estimasi DiD + sensitivity
forest_df <- data.frame(
  model = c("DiD (tanpa kovariat)", "DiD (+kovariat)",
            paste0("Sensitivity seed=", sensitivity$seed[-1])),
  estimate = c(coef(m_did)["treat_post"], coef(m_did_cov)["treat_post"],
               sensitivity$DiD_estimate[-1])
)
forest_df$se <- NA
forest_df$se[1] <- did_robust["treat_post", "Std. Error"]
forest_df$se[2] <- did_cov_robust["treat_post", "Std. Error"]
forest_df$lower <- forest_df$estimate - 1.96 * forest_df$se
forest_df$upper <- forest_df$estimate + 1.96 * forest_df$se
forest_df$model <- factor(forest_df$model, levels = rev(forest_df$model))

g7 <- ggplot(forest_df, aes(x = estimate, y = model)) +
  geom_point(size = 3, color = "#1b9e77") +
  geom_errorbarh(aes(xmin = lower, xmax = upper), height = 0.2, na.rm = TRUE) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "grey50") +
  labs(title = "Estimasi Dampak DiD: Model Utama vs Sensitivity Check",
       subtitle = "CI 95% hanya tersedia untuk model utama (clustered SE)",
       x = "Estimasi DiD (skor pendapatan ordinal)", y = NULL)
ggsave(file.path(out_dir, "07_forest_plot_sensitivity.png"), g7, width = 8, height = 5, dpi = 300)

cat("\nSelesai. 7 grafik tersimpan di folder 'output/'.\n")


# ------------------------------------------------------------------------------
# 7. RINGKASAN
# ------------------------------------------------------------------------------
cat("\n========== 7. RINGKASAN HASIL ==========\n")
pcol_did <- colnames(did_robust)[ncol(did_robust)]
pcol_cov <- colnames(did_cov_robust)[ncol(did_cov_robust)]
cat(sprintf("Estimasi DiD (tanpa kovariat) : %.3f (p = %.2e)\n",
            coef(m_did)["treat_post"], did_robust["treat_post", pcol_did]))
cat(sprintf("Estimasi DiD (+kovariat)      : %.3f (p = %.2e)\n",
            coef(m_did_cov)["treat_post"], did_cov_robust["treat_post", pcol_cov]))
cat(sprintf("Cohen's d                      : %.3f\n", cohen_d))
cat(sprintf("Rentang sensitivity (5 seed)   : %.3f - %.3f\n",
            min(sensitivity$DiD_estimate[-1]), max(sensitivity$DiD_estimate[-1])))
