# loocv_rmse() ---------------------------------------------------------------
# Closed-form LOOCV for OLS: e_(-i) = e_i / (1 - h_ii), avoiding n refits.
# ----------------------------------------------------------------------------

loocv_rmse <- function(model) {
  e <- residuals(model)
  h <- stats::hatvalues(model)
  sqrt(mean((e / (1 - h))^2))
}
