# 30_prediction.R ------------------------------------------------------------
# Section 3: out-of-sample prediction.
#   - split: chunks 1-7 train / chunks 8-10 validation
#   - baseline: specifications from sections 1 and 2
#   - >= 5 additional specifications (non-linearities, interactions, new controls)
#   - best model by validation RMSE, then LOOCV on the training sample
#     (use the hat-matrix shortcut, not brute force refitting)
#   - variable importance: define the measure and justify it
# ----------------------------------------------------------------------------

source(here::here("scripts", "02_cleaning.R"))
source(here::here("scripts", "functions", "rmse.R"))
source(here::here("scripts", "functions", "loocv.R"))
