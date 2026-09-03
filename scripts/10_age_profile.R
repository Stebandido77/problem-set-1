# 10_age_profile.R -----------------------------------------------------------
# Section 1: age-labor income profile.
#   (1) log(w) = b1 + b2*age + b3*age^2 + u
#   (2) conditional profile: + totalHoursWorked + relab
# Peak age = -b2 / (2*b3), with a bootstrap confidence interval.
# ----------------------------------------------------------------------------

source(here::here("scripts", "02_cleaning.R"))
source(here::here("scripts", "functions", "peak_age.R"))
