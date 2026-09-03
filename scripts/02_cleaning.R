# 02_cleaning.R --------------------------------------------------------------
# Builds the analysis sample used across ALL three sections.
# Single source of truth for every cleaning decision.
# ----------------------------------------------------------------------------

source(here::here("scripts", "00_packages.R"))

# Sample restrictions (documented in README.md):
#   - employed individuals (ocu == 1)
#   - age >= 18
#   - positive total monthly labor income (y_total_m > 0) before logs
#
# TODO: read chunks, bind rows, apply restrictions, build derived variables
#       (log_income, female, age_sq, education, firm size, formality, ...)
#       and save to stores/processed/analysis_sample.rds
