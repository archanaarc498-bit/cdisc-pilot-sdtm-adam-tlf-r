# ADAE: Occurrence Data Structure (OCCDS) for adverse events. Source: AE + ADSL. See docs/adam_specs.md
suppressPackageStartupMessages({library(haven); library(dplyr)})
adsl <- readRDS("data/adam/adsl.rds")
ae <- read_xpt("data/sdtm/ae.xpt")
d <- function(x) as.Date(ifelse(nchar(x) >= 10, substr(x, 1, 10), NA_character_))   # complete dates only, no imputation

adae <- ae %>%
  inner_join(adsl %>% filter(SAFFL == "Y") %>% select(USUBJID, TRT01P, TRT01PN, TRTSDT, TRTEDT, SAFFL), by = "USUBJID") %>%
  mutate(
    ASTDT = d(AESTDTC), AENDT = d(AEENDTC),
    ASTDY = ifelse(is.na(ASTDT), NA_real_, as.numeric(ASTDT - TRTSDT) + ifelse(ASTDT >= TRTSDT, 1, 0)),
    # Treatment-emergent: starts on or after first dose and no later than 30 days after last dose
    TRTEMFL = ifelse(!is.na(ASTDT) & ASTDT >= TRTSDT & ASTDT <= TRTEDT + 30, "Y", ""),
    AESEVN  = case_when(AESEV == "MILD" ~ 1, AESEV == "MODERATE" ~ 2, AESEV == "SEVERE" ~ 3),
    RELFL   = ifelse(AEREL %in% c("POSSIBLE", "PROBABLE"), "Y", ""),   # REMOTE and NONE = not related
    AESERFL = ifelse(AESER == "Y", "Y", ""),
    AEWDFL  = ifelse(AEACN == "DRUG WITHDRAWN", "Y", "")) %>%
  arrange(USUBJID, ASTDT, AESEQ)

# Occurrence flags: first treatment-emergent record per subject, per SOC and per preferred term
first_flag <- function(df, keys) {
  df %>% group_by(across(all_of(keys))) %>% mutate(flag = ifelse(TRTEMFL == "Y" & row_number(ifelse(TRTEMFL == "Y", 0, 1)) == 1, "Y", "")) %>% ungroup() %>% pull(flag)
}
adae <- adae %>% mutate(AOCCFL = first_flag(., "USUBJID"), AOCCSFL = first_flag(., c("USUBJID", "AEBODSYS")),
                        AOCCPFL = first_flag(., c("USUBJID", "AEBODSYS", "AEDECOD"))) %>%
  select(STUDYID, USUBJID, TRT01P, TRT01PN, SAFFL, AESEQ, AETERM, AEDECOD, AEBODSYS, AESEV, AESEVN, AESER, AESERFL,
         AEREL, RELFL, AEACN, AEWDFL, AEOUT, ASTDT, AENDT, ASTDY, TRTEMFL, AOCCFL, AOCCSFL, AOCCPFL)

# QC: exactly one AOCCFL per subject with a TEAE; PT flags cannot exceed SOC flags; all subjects in safety population
n_teae_subj <- n_distinct(adae$USUBJID[adae$TRTEMFL == "Y"])
stopifnot(sum(adae$AOCCFL == "Y") == n_teae_subj,
          sum(adae$AOCCSFL == "Y") <= sum(adae$AOCCPFL == "Y"),
          all(adae$USUBJID %in% adsl$USUBJID[adsl$SAFFL == "Y"]),
          !any(adae$AOCCFL == "Y" & adae$TRTEMFL != "Y"))
message("ADAE QC passed: ", nrow(adae), " AE records; ", sum(adae$TRTEMFL == "Y"), " treatment-emergent; ",
        n_teae_subj, " subjects with a TEAE; ", sum(is.na(adae$ASTDT)), " records with incomplete start date")
saveRDS(adae, "data/adam/adae.rds"); write.csv(adae, "output/adae.csv", row.names = FALSE, na = "")
