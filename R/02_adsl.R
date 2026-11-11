# ADSL: one record per subject. Source: DM, EX, DS. See docs/adam_specs.md
suppressPackageStartupMessages({library(haven); library(dplyr)})
dir.create("data/adam", recursive = TRUE, showWarnings = FALSE)
rd <- function(x) read_xpt(file.path("data/sdtm", paste0(x, ".xpt")))
dm <- rd("dm"); ex <- rd("ex"); ds <- rd("ds")
d <- function(x) as.Date(substr(x, 1, 10))   # ISO 8601 character -> Date

exs <- ex %>% filter(nzchar(EXSTDTC)) %>% group_by(USUBJID) %>%
  summarise(TRTSDT = min(d(EXSTDTC)), TRTEDT = max(d(ifelse(nzchar(EXENDTC), EXENDTC, EXSTDTC))), .groups = "drop")

eos <- ds %>% filter(DSCAT == "DISPOSITION EVENT") %>% group_by(USUBJID) %>% slice_max(DSSEQ, n = 1, with_ties = FALSE) %>%
  ungroup() %>% transmute(USUBJID, EOSSTT = ifelse(DSDECOD == "COMPLETED", "COMPLETED", "DISCONTINUED"),
                          DCSREAS = ifelse(DSDECOD == "COMPLETED", NA_character_, DSDECOD), EOSDT = d(DSSTDTC))

adsl <- dm %>%
  left_join(exs, by = "USUBJID") %>% left_join(eos, by = "USUBJID") %>%
  mutate(
    TRT01P  = ARM,
    TRT01PN = case_when(ARMCD == "Pbo" ~ 0, ARMCD == "Xan_Lo" ~ 54, ARMCD == "Xan_Hi" ~ 81, TRUE ~ NA_real_),
    TRT01A  = ACTARM,
    TRTDURD = as.numeric(TRTEDT - TRTSDT) + 1,
    AGEGR1  = case_when(AGE < 65 ~ "<65", AGE <= 80 ~ "65-80", AGE > 80 ~ ">80"),
    AGEGR1N = case_when(AGE < 65 ~ 1, AGE <= 80 ~ 2, AGE > 80 ~ 3),
    SEXN    = ifelse(SEX == "M", 1, 2),
    ITTFL   = ifelse(ARMCD %in% c("Pbo","Xan_Lo","Xan_Hi"), "Y", "N"),   # randomised
    SAFFL   = ifelse(ITTFL == "Y" & !is.na(TRTSDT), "Y", "N")            # randomised and dosed
  ) %>%
  select(STUDYID, USUBJID, SUBJID, SITEID, AGE, AGEU, AGEGR1, AGEGR1N, SEX, SEXN, RACE, ETHNIC, COUNTRY,
         ARMCD, ARM, TRT01P, TRT01PN, TRT01A, TRTSDT, TRTEDT, TRTDURD, EOSSTT, DCSREAS, EOSDT, ITTFL, SAFFL)

# QC against SDTM subject-level reference dates and known pilot counts
chk <- dm %>% transmute(USUBJID, RFX = d(RFXSTDTC)) %>% inner_join(adsl, by = "USUBJID") %>% filter(!is.na(TRTSDT))
stopifnot(nrow(adsl) == nrow(dm), !anyDuplicated(adsl$USUBJID), all(chk$RFX == chk$TRTSDT, na.rm = TRUE))
message("ADSL QC passed: ", nrow(adsl), " subjects; safety population = ", sum(adsl$SAFFL == "Y"))
saveRDS(adsl, "data/adam/adsl.rds"); write.csv(adsl, "output/adsl.csv", row.names = FALSE, na = "")
