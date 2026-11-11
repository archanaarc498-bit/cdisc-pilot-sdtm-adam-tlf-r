# ADVS: Basic Data Structure (BDS) dataset for supine vital signs. Source: VS + ADSL. See docs/adam_specs.md
suppressPackageStartupMessages({library(haven); library(dplyr)})
adsl <- readRDS("data/adam/adsl.rds")
vs <- read_xpt("data/sdtm/vs.xpt")
d <- function(x) as.Date(substr(x, 1, 10))

params <- tibble::tribble(~VSTESTCD, ~PARAMCD, ~PARAMN, ~PARAM,
  "SYSBP", "SYSBP", 1, "Systolic Blood Pressure, supine (mmHg)",
  "DIABP", "DIABP", 2, "Diastolic Blood Pressure, supine (mmHg)",
  "PULSE", "PULSE", 3, "Pulse Rate, supine (beats/min)")
visits <- tibble::tribble(~VISIT, ~AVISIT, ~AVISITN,
  "BASELINE", "Baseline", 0, "WEEK 2", "Week 2", 2, "WEEK 4", "Week 4", 4, "WEEK 6", "Week 6", 6,
  "WEEK 8", "Week 8", 8, "WEEK 12", "Week 12", 12, "WEEK 16", "Week 16", 16, "WEEK 20", "Week 20", 20,
  "WEEK 24", "Week 24", 24, "WEEK 26", "Week 26", 26)

advs <- vs %>%
  filter(VSPOS == "SUPINE", VSTESTCD %in% params$VSTESTCD) %>%
  inner_join(params, by = "VSTESTCD") %>%
  inner_join(adsl %>% filter(SAFFL == "Y") %>% select(USUBJID, TRT01P, TRT01PN, TRTSDT, SAFFL), by = "USUBJID") %>%
  left_join(visits, by = "VISIT") %>%
  mutate(ADT = d(VSDTC), ADY = as.numeric(ADT - TRTSDT) + ifelse(ADT >= TRTSDT, 1, 0), AVAL = VSSTRESN,
         AVALU = VSSTRESU) %>%
  filter(!is.na(AVAL)) %>%
  select(STUDYID, USUBJID, TRT01P, TRT01PN, SAFFL, PARAMCD, PARAMN, PARAM, VISIT, VISITNUM, AVISIT, AVISITN,
         ADT, ADY, AVAL, AVALU, VSSEQ)

# Baseline = last non-missing result on or before first dose in the BASELINE visit window
base <- advs %>% filter(AVISITN == 0) %>%
  inner_join(adsl %>% select(USUBJID, TRTSDT), by = "USUBJID") %>% filter(ADT <= TRTSDT) %>%
  arrange(ADT, VSSEQ) %>% group_by(USUBJID, PARAMCD) %>% slice_tail(n = 1) %>%
  ungroup() %>% transmute(USUBJID, PARAMCD, VSSEQ, ABLFL = "Y", BASE = AVAL)

advs <- advs %>%
  left_join(base %>% select(USUBJID, PARAMCD, BASE), by = c("USUBJID", "PARAMCD")) %>%
  left_join(base %>% select(USUBJID, PARAMCD, VSSEQ, ABLFL), by = c("USUBJID", "PARAMCD", "VSSEQ")) %>%
  mutate(ABLFL = ifelse(is.na(ABLFL), "", ABLFL),
         CHG  = ifelse(ABLFL == "Y" | is.na(AVISITN) | AVISITN == 0, NA_real_, AVAL - BASE),
         PCHG = ifelse(is.na(CHG), NA_real_, 100 * CHG / BASE),
         # analysis record: scheduled post-baseline visit with a baseline value
         ANL01FL = ifelse(!is.na(AVISITN) & AVISITN > 0 & !is.na(BASE) & ADY > 0, "Y", "")) %>%
  arrange(PARAMN, USUBJID, ADT, VSSEQ)

# QC: one baseline per subject/parameter, CHG arithmetic, only safety-population subjects
stopifnot(!anyDuplicated(advs %>% filter(ABLFL == "Y") %>% select(USUBJID, PARAMCD)),
          all(abs(advs$CHG - (advs$AVAL - advs$BASE)) < 1e-9, na.rm = TRUE),
          all(advs$USUBJID %in% adsl$USUBJID[adsl$SAFFL == "Y"]))
message("ADVS QC passed: ", nrow(advs), " records; ", sum(advs$ANL01FL == "Y"), " analysis records")
saveRDS(advs, "data/adam/advs.rds"); write.csv(advs, "output/advs.csv", row.names = FALSE, na = "")
