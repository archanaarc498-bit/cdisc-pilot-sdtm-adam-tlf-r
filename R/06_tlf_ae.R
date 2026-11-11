# TLFs from ADAE: T3 overall AE summary, T4 TEAEs by system organ class and preferred term
suppressPackageStartupMessages({library(dplyr); library(tidyr); library(gt)})
adsl <- readRDS("data/adam/adsl.rds") %>% filter(SAFFL == "Y")
adae <- readRDS("data/adam/adae.rds") %>% filter(TRTEMFL == "Y")
trt_levels <- c("Placebo", "Xanomeline Low Dose", "Xanomeline High Dose")
big_n <- table(factor(adsl$TRT01P, trt_levels))
hdr <- setNames(sprintf("%s (N=%d)", trt_levels, as.integer(big_n)), trt_levels)
cell <- function(n, trt) sprintf("%d (%.1f%%)", n, 100 * n / big_n[[trt]])
subj_n <- function(df, flag_expr) {   # number of subjects per treatment meeting a condition
  sapply(trt_levels, function(t) n_distinct(df$USUBJID[df$TRT01P == t & flag_expr]))
}

# ---- T3 overall summary ----
rows <- list(
  "Any treatment-emergent AE"         = rep(TRUE, nrow(adae)),
  "Any related AE (possible or probable)" = adae$RELFL == "Y",
  "Any severe AE"                     = adae$AESEV == "SEVERE",
  "Any serious AE"                    = adae$AESERFL == "Y",
  "Any AE leading to drug withdrawal" = adae$AEWDFL == "Y")
t3 <- bind_rows(lapply(names(rows), function(nm) {
  n <- subj_n(adae, rows[[nm]]); data.frame(Category = nm, t(setNames(mapply(cell, n, trt_levels), trt_levels)), check.names = FALSE)}))
t3_gt <- t3 %>% gt() %>% cols_label(!!!as.list(hdr)) %>%
  tab_header(title = "Table 14-3.01 Overall Summary of Treatment-Emergent Adverse Events",
             subtitle = "Safety population, CDISC Pilot 01 (public test data); n (%) of subjects") %>%
  tab_source_note("Source: ADAE, TRTEMFL = Y. Treatment-emergent = starts on or after first dose and up to 30 days after last dose.")
gtsave(t3_gt, "output/T3_ae_overall.html")

# ---- T4 by SOC and preferred term (PT reported if >= 5% in any treatment group) ----
pt <- adae %>% filter(AOCCPFL == "Y") %>% count(AEBODSYS, AEDECOD, TRT01P) %>%
  complete(nesting(AEBODSYS, AEDECOD), TRT01P = trt_levels, fill = list(n = 0)) %>%
  mutate(pct = 100 * n / as.numeric(big_n[TRT01P])) %>% group_by(AEBODSYS, AEDECOD) %>% filter(any(pct >= 5)) %>% ungroup()
soc <- adae %>% filter(AOCCSFL == "Y") %>% count(AEBODSYS, TRT01P) %>%
  complete(AEBODSYS, TRT01P = trt_levels, fill = list(n = 0)) %>% filter(AEBODSYS %in% pt$AEBODSYS)
fmt <- function(df, key) df %>% mutate(txt = mapply(cell, n, as.character(TRT01P))) %>% select(all_of(key), TRT01P, txt) %>%
  pivot_wider(names_from = TRT01P, values_from = txt)
tot <- pt %>% group_by(AEBODSYS, AEDECOD) %>% summarise(tot = sum(n), .groups = "drop")
pt_w <- fmt(pt, c("AEBODSYS", "AEDECOD")) %>% left_join(tot, by = c("AEBODSYS", "AEDECOD"))
soc_w <- fmt(soc, "AEBODSYS") %>% mutate(AEDECOD = "ANY EVENT IN THIS SYSTEM ORGAN CLASS", tot = Inf)
t4 <- bind_rows(soc_w, pt_w) %>% group_by(AEBODSYS) %>% arrange(AEBODSYS, desc(tot), .by_group = TRUE) %>% ungroup() %>%
  select(AEBODSYS, AEDECOD, all_of(trt_levels))
t4_gt <- t4 %>% gt(groupname_col = "AEBODSYS", rowname_col = "AEDECOD") %>% cols_label(!!!as.list(hdr)) %>%
  tab_header(title = "Table 14-3.02 Treatment-Emergent Adverse Events by System Organ Class and Preferred Term",
             subtitle = "Safety population; preferred terms with >= 5% in any treatment group; n (%) of subjects") %>%
  tab_source_note("Source: ADAE, TRTEMFL = Y, AOCCSFL = Y (SOC rows) and AOCCPFL = Y (preferred-term rows). A subject is counted once per row.")
gtsave(t4_gt, "output/T4_ae_soc_pt.html")
write.csv(t3, "output/T3_ae_overall_data.csv", row.names = FALSE)
message("AE TLFs written to output/")
