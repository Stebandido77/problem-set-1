# edad_pico() ----------------------------------------------------------------
# Implied peak age of a quadratic age profile: -b_age / (2 * b_age_sq).
# ----------------------------------------------------------------------------

edad_pico <- function(modelo, termino_edad = "age", termino_edad_2 = "edad_2") {
  b <- coef(modelo)
  unname(-b[[termino_edad]] / (2 * b[[termino_edad_2]]))
}
