# Run the full workflow from the project root: Rscript run_all.R
for (f in c("R/00_download_data.R", "R/01_sdtm_checks.R", "R/02_adsl.R", "R/03_advs.R", "R/04_tlf.R", "R/05_adae.R", "R/06_tlf_ae.R")) {
  message("== ", f); source(f, local = new.env())
}
