# 20_gender_gap.R ------------------------------------------------------------
# Section 2: gender labor income gap.
#   (1) unconditional: log(w) = b1 + b2*female + u
#   (2) conditional: worker and job controls (justify each one; flag bad controls)
#   (3) FWL decomposition + analytical and bootstrap standard errors
#   (4) predicted age-income profiles by gender with peak ages and CIs
# ----------------------------------------------------------------------------

source(here::here("scripts", "02_cleaning.R"))
source(here::here("scripts", "functions", "peak_age.R"))
