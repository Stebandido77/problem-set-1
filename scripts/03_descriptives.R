# 03_descriptives.R ----------------------------------------------------------
# Descriptive evidence that MOTIVATES the modeling choices (not a data
# dictionary). Exports to views/tables/ and views/figures/.
#
# STATUS: incomplete. Only the temporal-drift check is implemented so far.
# Still to add: distribution of log(y_total_m), income by age, income by
# gender, income by hours worked.
# ----------------------------------------------------------------------------

source(here::here("scripts", "02_cleaning.R"))

figures_dir <- here::here("views", "figures")
dir.create(figures_dir, recursive = TRUE, showWarnings = FALSE)

# Temporal drift ---------------------------------------------------------------
# The 10 chunks are ordered by survey month (chunk 1 = Jan-Feb ... chunk 10 =
# Nov-Dec), so the mandated 1-7 / 8-10 split is temporal rather than random.
# This motivates two modeling decisions:
#   1. `mes` and `chunk_id` must never enter a model as predictors: either one
#      would leak the split (see `non_predictors` in 02_cleaning.R).
#   2. Whether the validation RMSE can be read as ordinary out-of-sample error
#      depends on there being no level shift between the folds. There is none:
#      December does not jump, because the prima de servicios already enters
#      y_total_m on a monthly-equivalent basis.
monthly_income <- analysis_sample |>
  dplyr::group_by(mes) |>
  dplyr::summarise(
    n       = dplyr::n(),
    mean_ly = mean(log_income),
    med_ly  = median(log_income),
    se      = sd(log_income) / sqrt(dplyr::n()),
    .groups = "drop"
  ) |>
  dplyr::mutate(lo = mean_ly - 1.96 * se, hi = mean_ly + 1.96 * se)

drift_plot <- ggplot2::ggplot(monthly_income, ggplot2::aes(mes, mean_ly)) +
  ggplot2::annotate("rect", xmin = 8.5, xmax = 12.5, ymin = -Inf, ymax = Inf,
                    fill = "grey85", alpha = 0.6) +
  ggplot2::annotate("text", x = 10.5, y = max(monthly_income$hi),
                    label = "validacion (chunks 8-10)", size = 3.1,
                    colour = "grey30", vjust = 1.4) +
  ggplot2::annotate("text", x = 4.5, y = max(monthly_income$hi),
                    label = "entrenamiento (chunks 1-7)", size = 3.1,
                    colour = "grey30", vjust = 1.4) +
  ggplot2::geom_hline(yintercept = mean(analysis_sample$log_income),
                      linetype = "dashed", colour = "grey50",
                      linewidth = 0.4) +
  ggplot2::geom_errorbar(ggplot2::aes(ymin = lo, ymax = hi), width = 0.18,
                         colour = "grey40") +
  ggplot2::geom_line(colour = "steelblue4", linewidth = 0.6) +
  ggplot2::geom_point(size = 2.1, colour = "steelblue4") +
  ggplot2::scale_x_continuous(breaks = 1:12) +
  ggplot2::labs(
    x = "Mes de la encuesta (2018)",
    y = "Media de log(ingreso laboral mensual)",
    title = "El ingreso laboral no presenta deriva temporal dentro de 2018",
    subtitle = paste(
      "Los chunks estan ordenados por mes: el corte 1-7 / 8-10 es temporal",
      "(el mes 9 se reparte entre ambos\nfolds). Diciembre no salta",
      "(+1,25%, p = 0,66): la prima de servicios ya viene mensualizada",
      "en y_total_m."
    )
  ) +
  ggplot2::theme_minimal(base_size = 11) +
  ggplot2::theme(
    plot.title       = ggplot2::element_text(face = "bold", size = 11.5),
    plot.subtitle    = ggplot2::element_text(size = 9, colour = "grey30"),
    panel.grid.minor = ggplot2::element_blank()
  )

ggplot2::ggsave(file.path(figures_dir, "temporal_drift.png"), drift_plot,
                width = 7.6, height = 4.6, dpi = 300)

# The formal test behind the subtitle: a December dummy on top of a month
# trend is null, so the temporal split introduces no detectable level shift.
drift_test <- lm(log_income ~ mes + I(mes == 11) + I(mes == 12),
                 data = analysis_sample)

message("\n--- monthly mean/median of log(y_total_m) ---")
print(as.data.frame(monthly_income[, c("mes", "n", "mean_ly", "med_ly")]))
message("\n--- December dummy on top of a month trend ---")
print(summary(drift_test)$coefficients)
