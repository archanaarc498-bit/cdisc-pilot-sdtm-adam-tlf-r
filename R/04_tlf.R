# TLFs from ADaM: T1 demographics, T2 change from baseline in supine SBP, F1 mean change over time
suppressPackageStartupMessages({library(dplyr); library(tidyr); library(gt); library(ggplot2)})
adsl <- readRDS("data/adam/adsl.rds") %>% filter(SAFFL == "Y")
advs <- readRDS("data/adam/advs.rds")
trt_levels <- c("Placebo", "Xanomeline Low Dose", "Xanomeline High Dose")
adsl$TRT01P <- factor(adsl$TRT01P, trt_levels); advs$TRT01P <- factor(advs$TRT01P, trt_levels)
pop_n <- adsl %>% count(TRT01P) %>% mutate(lab = paste0(TRT01P, "\n(N=", n, ")"))
fmt_ns <- function(x, n) sprintf("%d (%.1f%%)", x, 100 * x / n)

# ---- T1 Demographics ----
cat_rows <- function(var, label) {
  adsl %>% count(TRT01P, level = .data[[var]]) %>% mutate(level = as.character(level)) %>% group_by(TRT01P) %>% mutate(txt = fmt_ns(n, sum(adsl$TRT01P == first(TRT01P)))) %>%
    ungroup() %>% select(level, TRT01P, txt) %>% pivot_wider(names_from = TRT01P, values_from = txt, values_fill = "0") %>%
    mutate(group = label)
}
num_rows <- adsl %>% group_by(TRT01P) %>% summarise(
  `Mean (SD)` = sprintf("%.1f (%.1f)", mean(AGE), sd(AGE)), `Median` = sprintf("%.1f", median(AGE)),
  `Min, Max` = sprintf("%d, %d", min(AGE), max(AGE)), .groups = "drop") %>%
  pivot_longer(-TRT01P, names_to = "level") %>% pivot_wider(names_from = TRT01P, values_from = value) %>% mutate(group = "Age (years)")
t1 <- bind_rows(num_rows, cat_rows("AGEGR1", "Age group (years)"), cat_rows("SEX", "Sex"), cat_rows("RACE", "Race")) %>%
  mutate(ord = match(level, c("<65","65-80",">80","F","M","WHITE","BLACK OR AFRICAN AMERICAN","AMERICAN INDIAN OR ALASKA NATIVE"), nomatch = 0)) %>% arrange(factor(group, c("Age (years)","Age group (years)","Sex","Race")), ord) %>% select(group, level, all_of(trt_levels))
t1_gt <- t1 %>% gt(groupname_col = "group", rowname_col = "level") %>%
  tab_header(title = "Table 14-2.01 Summary of Demographic Characteristics",
             subtitle = "Safety population, CDISC Pilot 01 (public test data)") %>%
  cols_label(!!!setNames(as.list(gsub("\n", " ", pop_n$lab)), as.character(pop_n$TRT01P))) %>%
  tab_source_note("Source: ADSL. Percentages use the number of subjects in each treatment group as denominator.")
gtsave(t1_gt, "output/T1_demographics.html")

# ---- T2 Change from baseline, supine systolic BP ----
sbp <- advs %>% filter(PARAMCD == "SYSBP", ANL01FL == "Y")
t2 <- sbp %>% group_by(AVISITN, AVISIT, TRT01P) %>%
  summarise(n = n(), mean = mean(CHG), sd = sd(CHG), .groups = "drop") %>%
  mutate(txt = sprintf("%d | %.1f (%.1f)", n, mean, sd)) %>%
  select(AVISITN, Visit = AVISIT, TRT01P, txt) %>% pivot_wider(names_from = TRT01P, values_from = txt, values_fill = "-") %>%
  arrange(AVISITN) %>% select(-AVISITN)
t2_gt <- t2 %>% gt() %>%
  tab_header(title = "Table 14-5.01 Change from Baseline in Supine Systolic Blood Pressure (mmHg)",
             subtitle = "Safety population; cells show n | mean (SD)") %>%
  tab_source_note("Source: ADVS, PARAMCD = SYSBP, ANL01FL = Y. Baseline = last non-missing supine value on or before first dose.")
gtsave(t2_gt, "output/T2_sbp_change.html")

# ---- F1 Mean change over time with SE ----
f1d <- sbp %>% group_by(AVISITN, TRT01P) %>% summarise(n = n(), m = mean(CHG), se = sd(CHG) / sqrt(n), .groups = "drop")
f1 <- ggplot(f1d, aes(AVISITN, m, colour = TRT01P, group = TRT01P)) +
  geom_hline(yintercept = 0, linetype = "dashed", colour = "grey60") +
  geom_errorbar(aes(ymin = m - se, ymax = m + se), width = 0.5, position = position_dodge(0.8)) +
  geom_line(position = position_dodge(0.8)) + geom_point(position = position_dodge(0.8), size = 2) +
  scale_x_continuous(breaks = sort(unique(f1d$AVISITN))) +
  labs(title = "Figure 14-5.01 Mean (±SE) change from baseline in supine SBP", subtitle = "Safety population, CDISC Pilot 01",
       x = "Week", y = "Change from baseline (mmHg)", colour = NULL, caption = "Source: ADVS (PARAMCD = SYSBP, ANL01FL = Y)") +
  theme_minimal(base_size = 11) + theme(legend.position = "bottom")
ggsave("output/F1_sbp_change.png", f1, width = 8, height = 5, dpi = 200)
write.csv(f1d, "output/F1_sbp_change_data.csv", row.names = FALSE)
message("TLFs written to output/")
