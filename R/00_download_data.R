# Download the public CDISC Pilot 01 SDTM datasets (PHUSE test data repository)
base <- "https://raw.githubusercontent.com/phuse-org/phuse-scripts/master/data/sdtm/cdiscpilot01/"
dir.create("data/sdtm", recursive = TRUE, showWarnings = FALSE)
for (d in c("dm", "ex", "ds", "vs", "ae")) {
  dest <- file.path("data/sdtm", paste0(d, ".xpt"))
  if (!file.exists(dest)) download.file(paste0(base, d, ".xpt"), dest, mode = "wb", quiet = TRUE)
}
message("SDTM files ready in data/sdtm")
