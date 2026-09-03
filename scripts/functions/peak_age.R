# peak_age() -----------------------------------------------------------------
# Implied peak age of a quadratic age profile: -b_age / (2 * b_age_sq).
# ----------------------------------------------------------------------------

peak_age <- function(model, term_age = "age", term_age_sq = "age_sq") {
  b <- coef(model)
  unname(-b[[term_age]] / (2 * b[[term_age_sq]]))
}
