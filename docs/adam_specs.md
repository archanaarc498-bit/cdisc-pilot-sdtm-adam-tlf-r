# ADaM derivation specifications

Source data: CDISC Pilot 01 SDTM (DM, EX, DS, VS, AE), public PHUSE test data. All derivations are in `R/`. The analysis datasets are created locally when the project is run and are not stored in this repository.

## ADSL (one record per subject, 306 records)

| Variable | Label | Derivation | Source |
|---|---|---|---|
| USUBJID, SUBJID, SITEID, AGE, AGEU, SEX, RACE, ETHNIC, COUNTRY, ARMCD, ARM | as in SDTM | Copied from DM | DM |
| TRT01P | Planned Treatment | ARM | DM.ARM |
| TRT01PN | Planned Treatment (N) | Pbo = 0, Xan_Lo = 54, Xan_Hi = 81 (daily dose, mg) | DM.ARMCD |
| TRT01A | Actual Treatment | ACTARM | DM.ACTARM |
| TRTSDT | Date of First Exposure | Earliest EXSTDTC (date part) | EX |
| TRTEDT | Date of Last Exposure | Latest EXENDTC; EXSTDTC if EXENDTC is blank (6 records) | EX |
| TRTDURD | Treatment Duration (days) | TRTEDT - TRTSDT + 1 | derived |
| AGEGR1 / AGEGR1N | Pooled Age Group | <65 = 1, 65-80 = 2, >80 = 3 | DM.AGE |
| SEXN | Sex (N) | M = 1, F = 2 | DM.SEX |
| EOSSTT, DCSREAS, EOSDT | End of Study status, reason, date | Last DISPOSITION EVENT record in DS; COMPLETED, or DISCONTINUED with the DSDECOD as reason | DS |
| ITTFL | Intent-to-Treat Flag | Y if randomised (ARMCD not Screen Failure) | DM.ARMCD |
| SAFFL | Safety Population Flag | Y if ITTFL = Y and at least one dose record (TRTSDT not missing) | EX |

QC: TRTSDT is compared with the SDTM reference date DM.RFXSTDTC; the safety population is 254 subjects (Placebo 86, Low Dose 84, High Dose 84).

## ADVS (BDS, supine vital signs)

| Variable | Derivation |
|---|---|
| PARAMCD / PARAM | SYSBP, DIABP, PULSE (supine position only, VSPOS = SUPINE) from VS.VSTESTCD |
| AVAL | VSSTRESN; missing results are dropped (8 records) |
| AVISIT / AVISITN | Scheduled visits mapped from VISIT: Baseline (0) and Weeks 2 to 26. Screening, ambulatory ECG, retrieval and unscheduled visits get no analysis visit |
| ADT, ADY | ADT = date of VSDTC; ADY = ADT - TRTSDT + 1 if ADT >= TRTSDT, otherwise ADT - TRTSDT |
| ABLFL / BASE | Baseline = last non-missing result in the BASELINE visit on or before TRTSDT, per subject and parameter |
| CHG / PCHG | AVAL - BASE and 100 x CHG / BASE for post-baseline analysis visits |
| ANL01FL | Y for scheduled post-baseline visits with a baseline value and ADY > 0 |
| Population | Safety population only (SAFFL = Y) |

QC checks in `R/03_advs.R`: one baseline per subject and parameter, CHG = AVAL - BASE, and all subjects belong to the safety population.

## ADAE (OCCDS, adverse events)

ADAE follows the Occurrence Data Structure (OCCDS), used for events, not the Basic Data Structure (BDS) used for measurements such as ADVS. One record per adverse event in the safety population (1,191 records).

| Variable | Derivation |
|---|---|
| USUBJID, AESEQ, AETERM, AEDECOD, AEBODSYS, AESEV, AESER, AEREL, AEACN, AEOUT | Copied from SDTM AE |
| TRT01P, TRT01PN, SAFFL | From ADSL (safety population only) |
| ASTDT, AENDT | Date part of AESTDTC and AEENDTC. Only complete dates are converted. Partial dates (year only or year-month) are left missing and are not imputed (26 records) |
| ASTDY | ASTDT - TRTSDT + 1 if ASTDT >= TRTSDT, otherwise ASTDT - TRTSDT |
| TRTEMFL | Y if ASTDT is on or after TRTSDT and no later than TRTEDT + 30 days |
| AESEVN | MILD = 1, MODERATE = 2, SEVERE = 3 |
| RELFL | Y if AEREL is POSSIBLE or PROBABLE. REMOTE and NONE are treated as not related (an assumption, stated in the table footnote) |
| AESERFL, AEWDFL | Y if AESER = Y; Y if AEACN = DRUG WITHDRAWN |
| AOCCFL | Y on the first treatment-emergent record per subject |
| AOCCSFL | Y on the first treatment-emergent record per subject and system organ class |
| AOCCPFL | Y on the first treatment-emergent record per subject, system organ class and preferred term |

QC checks in `R/05_adae.R`: one AOCCFL per subject with a treatment-emergent AE, no AOCCFL on non-treatment-emergent records, SOC flags never outnumber preferred-term flags, and all subjects belong to the safety population. Subject counts in the tables were also recomputed outside R and matched.

Result: 1,116 of the 1,191 records are treatment-emergent, in 217 of the 254 subjects.

## TLFs

| ID | Title | Source |
|---|---|---|
| T1 (Table 14-2.01) | Summary of demographic characteristics | ADSL, SAFFL = Y |
| T2 (Table 14-5.01) | Change from baseline in supine systolic BP, n, mean and SD by visit | ADVS, PARAMCD = SYSBP, ANL01FL = Y |
| F1 (Figure 14-5.01) | Mean (SE) change from baseline in supine SBP over time | ADVS, as T2 |
| T3 (Table 14-3.01) | Overall summary of treatment-emergent adverse events | ADAE, TRTEMFL = Y |
| T4 (Table 14-3.02) | Treatment-emergent AEs by system organ class and preferred term (>= 5% in any group) | ADAE, AOCCSFL and AOCCPFL |
