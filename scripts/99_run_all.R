# 99_run_all.R ---------------------------------------------------------------
# Full reproduction pipeline. Runs end to end from a clean clone.
# ----------------------------------------------------------------------------

source(here::here("scripts", "00_packages.R"))
source(here::here("scripts", "01_scraping.R"))
source(here::here("scripts", "02_cleaning.R"))
source(here::here("scripts", "03_descriptives.R"))
source(here::here("scripts", "10_age_profile.R"))
source(here::here("scripts", "20_gender_gap.R"))
source(here::here("scripts", "30_prediction.R"))

message("Pipeline finished. Check views/tables and views/figures.")
