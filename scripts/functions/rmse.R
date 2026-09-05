# rmse() ---------------------------------------------------------------------
rmse <- function(observado, predicho) {
  sqrt(mean((observado - predicho)^2, na.rm = TRUE))
}
