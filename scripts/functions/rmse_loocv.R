# rmse_loocv() ---------------------------------------------------------------
# Closed-form LOOCV for OLS: e_(-i) = e_i / (1 - h_ii), avoiding n refits.
# ----------------------------------------------------------------------------

rmse_loocv <- function(modelo) {
  e <- residuals(modelo)
  h <- stats::hatvalues(modelo)
  sqrt(mean((e / (1 - h))^2))
}
