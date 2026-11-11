# Basic SDTM conformance checks on the source data (DM, EX, DS, VS)
suppressPackageStartupMessages({library(haven); library(dplyr)})
dir.create("output", showWarnings = FALSE)
rd <- function(x) read_xpt(file.path("data/sdtm", paste0(x, ".xpt")))
dm <- rd("dm"); ex <- rd("ex"); ds <- rd("ds"); vs <- rd("vs"); ae <- rd("ae")

iso_ok <- function(x) { x <- x[nzchar(x)]; all(grepl("^\\d{4}(-\\d{2}(-\\d{2}(T\\d{2}:\\d{2}(:\\d{2})?)?)?)?$", x)) }   # full or partial ISO 8601 dates
chk <- function(name, pass, detail = "") data.frame(check = name, result = ifelse(pass, "PASS", "FAIL"), detail = detail)

req <- list(
  dm = c("STUDYID","DOMAIN","USUBJID","SUBJID","RFSTDTC","SITEID","AGE","AGEU","SEX","RACE","ARMCD","ARM","COUNTRY"),
  ex = c("STUDYID","DOMAIN","USUBJID","EXSEQ","EXTRT","EXSTDTC"),
  ds = c("STUDYID","DOMAIN","USUBJID","DSSEQ","DSTERM","DSDECOD","DSSTDTC"),
  vs = c("STUDYID","DOMAIN","USUBJID","VSSEQ","VSTESTCD","VSTEST","VISITNUM","VSDTC"),
  ae = c("STUDYID","DOMAIN","USUBJID","AESEQ","AETERM","AEDECOD","AEBODSYS","AESEV","AESER","AESTDTC"))
dat <- list(dm = dm, ex = ex, ds = ds, vs = vs, ae = ae)

res <- bind_rows(
  chk("STUDYID is the same in all domains", n_distinct(unlist(lapply(dat, `[[`, "STUDYID"))) == 1),
  chk("DM has one record per subject", !anyDuplicated(dm$USUBJID), paste(nrow(dm), "subjects")),
  bind_rows(lapply(names(req), function(n) {
    miss <- setdiff(req[[n]], names(dat[[n]]))
    chk(paste0(toupper(n), ": required variables present"), length(miss) == 0, paste(miss, collapse = ", "))})),
  bind_rows(lapply(c("ex","ds","vs","ae"), function(n) {
    bad <- setdiff(unique(dat[[n]]$USUBJID), dm$USUBJID)
    chk(paste0(toupper(n), ": every USUBJID exists in DM"), length(bad) == 0, paste(length(bad), "orphans"))})),
  bind_rows(lapply(c("ex","ds","vs","ae"), function(n) {
    seq <- dat[[n]][[paste0(toupper(n), "SEQ")]]
    chk(paste0(toupper(n), ": --SEQ unique within subject"), !anyDuplicated(data.frame(dat[[n]]$USUBJID, seq)))})),
  chk("DM: RFSTDTC is ISO 8601", iso_ok(dm$RFSTDTC)),
  chk("EX: EXSTDTC is ISO 8601", iso_ok(ex$EXSTDTC)),
  chk("VS: VSDTC is ISO 8601", iso_ok(vs$VSDTC)),
  chk("AE: AESTDTC is ISO 8601", iso_ok(ae$AESTDTC)),
  chk("AE: AESEV within controlled terms", all(ae$AESEV %in% c("MILD","MODERATE","SEVERE"))),
  chk("DM: SEX within controlled terminology (F, M)", all(dm$SEX %in% c("F","M")), paste(unique(dm$SEX), collapse = ",")),
  chk("VS: VSSTRESN is numeric", is.numeric(vs$VSSTRESN)),
  chk("VS: no missing VSSTRESN for completed tests (count)", TRUE, paste(sum(is.na(vs$VSSTRESN)), "missing result(s) kept and flagged"))
)
write.csv(res, "output/sdtm_checks.csv", row.names = FALSE)
print(res, right = FALSE)
if (any(res$result == "FAIL")) stop("SDTM conformance checks failed")
