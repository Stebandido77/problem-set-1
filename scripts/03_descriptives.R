# 03_descriptives.R ----------------------------------------------------------
# Descriptive evidence that MOTIVATES the modeling choices (not a data
# dictionary). Every figure here answers "why is the model specified this
# way?", never "what does this variable contain?".
#
#   1. distribution of y_total_m -> why the outcome is logged
#   2. income by age            -> why age enters quadratically
#   3. income by gender         -> the raw gap Section 2 has to explain
#   4. income by hours worked   -> why Section 1 conditions on hours
#   5. income by survey month   -> why `mes`/`chunk_id` never become predictors
#
# Exports figures to views/figures/.
# ----------------------------------------------------------------------------

source(here::here("scripts", "02_cleaning.R"))

figures_dir <- here::here("views", "figures")
dir.create(figures_dir, recursive = TRUE, showWarnings = FALSE)

ps_theme <- theme_minimal(base_size = 11) +
  theme(
    plot.title       = element_text(face = "bold", size = 11.5),
    plot.subtitle    = element_text(size = 9, colour = "grey30"),
    panel.grid.minor = element_blank()
  )

save_fig <- function(plot, name, width = 7.6, height = 4.6) {
  ggsave(file.path(figures_dir, name), plot, width = width,
         height = height, dpi = 300)
}

skewness <- function(x) mean((x - mean(x))^3) / sd(x)^3

# 1. Why the outcome is logged -------------------------------------------------
# y_total_m is strongly right-skewed, so OLS in levels would be driven by the
# top of the distribution and its residuals would be badly heteroskedastic.
# The log is close to symmetric, which is what makes a linear model in
# log-income the natural specification for all three sections.
skew_level <- skewness(analysis_sample$y_total_m)
skew_log   <- skewness(analysis_sample$log_income)

log_panel <- analysis_sample |>
  select(y_total_m, log_income) |>
  pivot_longer(everything(), names_to = "scale", values_to = "value") |>
  mutate(scale = factor(
    scale,
    levels = c("y_total_m", "log_income"),
    labels = c(sprintf("Nivel: y_total_m (asimetria = %.1f)", skew_level),
               sprintf("Log: log(y_total_m) (asimetria = %.2f)", skew_log))
  ))

p_log <- ggplot(log_panel, aes(value)) +
  geom_histogram(bins = 60, fill = "steelblue4", colour = NA) +
  facet_wrap(~scale, scales = "free") +
  scale_x_continuous(labels = scales::label_comma()) +
  labs(
    x = NULL, y = "Frecuencia",
    title = "La transformacion log es lo que hace viable un modelo lineal",
    subtitle = paste(
      "En niveles la distribucion es fuertemente asimetrica a la derecha, de",
      "modo que OLS quedaria dominado por\nla cola alta. En logaritmos es",
      "aproximadamente simetrica. Por eso el outcome de las tres secciones",
      "es log(y_total_m)."
    )
  ) +
  ps_theme
save_fig(p_log, "dist_log_income.png", width = 8.4)

# 2. Why age enters quadratically ---------------------------------------------
# Binned means show a concave profile: income rises with age, flattens, and
# turns down. A linear term cannot represent that, so age enters with a square
# and Section 1 can report a peak age.
age_bins <- analysis_sample |>
  group_by(age) |>
  summarise(n = n(), mean_ly = mean(log_income), .groups = "drop") |>
  filter(n >= 20)

age_fit  <- lm(log_income ~ age + age_sq, data = analysis_sample)
age_cf   <- coef(age_fit)
peak_age <- -age_cf[["age"]] / (2 * age_cf[["age_sq"]])
age_grid <- tibble(
  age = seq(min(age_bins$age), max(age_bins$age), by = 0.5)
)
age_grid$age_sq <- age_grid$age^2
age_grid$fit    <- predict(age_fit, newdata = age_grid)

p_age <- ggplot(age_bins, aes(age, mean_ly)) +
  geom_point(aes(size = n), colour = "grey55", alpha = 0.65) +
  geom_line(data = age_grid, aes(age, fit), colour = "steelblue4",
            linewidth = 0.9) +
  geom_vline(xintercept = peak_age, linetype = "dashed",
             colour = "firebrick", linewidth = 0.4) +
  annotate("text", x = peak_age + 1.2, y = min(age_bins$mean_ly),
           label = sprintf("edad pico ~ %.0f", peak_age), hjust = 0,
           size = 3.2, colour = "firebrick") +
  scale_size_continuous(range = c(0.8, 3.4), guide = "none") +
  labs(
    x = "Edad", y = "Media de log(ingreso laboral mensual)",
    title = "El perfil edad-ingreso es concavo: hace falta el cuadratico",
    subtitle = paste(
      "Cada punto es la media por edad (solo edades con al menos 20",
      "observaciones); el tamano refleja el N.\nLa curva es el ajuste en age",
      "y age_sq. Un termino lineal no podria representar el descenso final."
    )
  ) +
  ps_theme
save_fig(p_age, "income_by_age.png")

# 3. The raw gender gap Section 2 has to explain -------------------------------
# The unconditional gap is the starting point of Section 2: the question there
# is how much of it survives once we condition on observables.
gap_stats <- analysis_sample |>
  group_by(female) |>
  summarise(n = n(), mean_ly = mean(log_income),
            median_y = median(y_total_m), .groups = "drop")
raw_gap <- gap_stats$mean_ly[gap_stats$female == 1] -
  gap_stats$mean_ly[gap_stats$female == 0]

p_gap <- analysis_sample |>
  mutate(sexo = if_else(female == 1, "Mujeres", "Hombres")) |>
  ggplot(aes(log_income, fill = sexo, colour = sexo)) +
  geom_density(alpha = 0.28, linewidth = 0.6) +
  geom_vline(data = gap_stats |>
               mutate(sexo = if_else(female == 1, "Mujeres", "Hombres")),
             aes(xintercept = mean_ly, colour = sexo), linetype = "dashed",
             linewidth = 0.5, show.legend = FALSE) +
  scale_fill_manual(values = c(Hombres = "steelblue4", Mujeres = "firebrick")) +
  scale_colour_manual(values = c(Hombres = "steelblue4",
                                 Mujeres = "firebrick")) +
  labs(
    x = "log(ingreso laboral mensual)", y = "Densidad", fill = NULL,
    colour = NULL,
    title = "Brecha de genero incondicional: el punto de partida de la Sec. 2",
    subtitle = sprintf(
      paste("Diferencia cruda en medias: %.4f log points (%.1f%%) a favor de",
            "los hombres.\nLas lineas punteadas son las medias. La Seccion 2",
            "estima cuanto sobrevive al condicionar por observables."),
      raw_gap, 100 * (exp(raw_gap) - 1)
    )
  ) +
  coord_cartesian(xlim = c(10.5, 17)) +
  ps_theme + theme(legend.position = "top")
save_fig(p_gap, "income_by_gender.png")

# 4. Why Section 1 conditions on hours -----------------------------------------
# The income-hours relationship is concave: steep below the full-time week and
# essentially flat above it. Two consequences for Section 1. First, hours vary
# over the life cycle, so leaving them out lets the age profile absorb
# variation in labour supply rather than in the wage. Second, the flattening
# above ~40 h means hours should not be assumed to enter linearly.
p_hours <- ggplot(analysis_sample, aes(hours, log_income)) +
  geom_point(alpha = 0.05, colour = "grey45", size = 0.5) +
  geom_smooth(method = "loess", formula = y ~ x, se = TRUE,
              colour = "steelblue4", fill = "steelblue4", linewidth = 0.9) +
  labs(
    x = "Horas trabajadas por semana", y = "log(ingreso laboral mensual)",
    title = "Ingreso y horas: concava, se aplana en la jornada completa",
    subtitle = paste(
      "Sin controlar por horas, el perfil edad-ingreso absorbe variacion en",
      "oferta laboral y no en el salario.\nEl aplanamiento por encima de las",
      "~40 h advierte ademas contra imponer linealidad. Suavizado loess."
    )
  ) +
  coord_cartesian(ylim = c(10.5, 17)) +
  ps_theme
save_fig(p_hours, "income_by_hours.png")

# 5. Why `mes` and `chunk_id` never become predictors --------------------------
# The 10 chunks are ordered by survey month (chunk 1 = Jan-Feb ... chunk 10 =
# Nov-Dec), so the mandated 1-7 / 8-10 split is temporal rather than random.
# Two consequences:
#   a. `mes` and `chunk_id` must never enter a model: either one would leak the
#      split (see `non_predictors` in 02_cleaning.R).
#   b. Reading the validation RMSE as ordinary out-of-sample error requires no
#      level shift between folds. There is none: December does not jump,
#      because the prima de servicios already enters y_total_m on a
#      monthly-equivalent basis.
monthly_income <- analysis_sample |>
  group_by(mes) |>
  summarise(n = n(), mean_ly = mean(log_income), med_ly = median(log_income),
            se = sd(log_income) / sqrt(n()), .groups = "drop") |>
  mutate(lo = mean_ly - 1.96 * se, hi = mean_ly + 1.96 * se)

p_drift <- ggplot(monthly_income, aes(mes, mean_ly)) +
  annotate("rect", xmin = 8.5, xmax = 12.5, ymin = -Inf, ymax = Inf,
           fill = "grey85", alpha = 0.6) +
  annotate("text", x = 10.5, y = max(monthly_income$hi),
           label = "validacion (chunks 8-10)", size = 3.1, colour = "grey30",
           vjust = 1.4) +
  annotate("text", x = 4.5, y = max(monthly_income$hi),
           label = "entrenamiento (chunks 1-7)", size = 3.1, colour = "grey30",
           vjust = 1.4) +
  geom_hline(yintercept = mean(analysis_sample$log_income),
             linetype = "dashed", colour = "grey50", linewidth = 0.4) +
  geom_errorbar(aes(ymin = lo, ymax = hi), width = 0.18, colour = "grey40") +
  geom_line(colour = "steelblue4", linewidth = 0.6) +
  geom_point(size = 2.1, colour = "steelblue4") +
  scale_x_continuous(breaks = 1:12) +
  labs(
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
  ps_theme
save_fig(p_drift, "temporal_drift.png")

drift_test <- lm(log_income ~ mes + I(mes == 11) + I(mes == 12),
                 data = analysis_sample)

# Console summary --------------------------------------------------------------
message("\n--- 1. skewness of the outcome ---")
message("  level: ", round(skew_level, 2), " | log: ", round(skew_log, 3))
message("\n--- 2. age profile ---")
message("  peak age from the quadratic: ", round(peak_age, 1))
message("\n--- 3. unconditional gender gap ---")
print(as.data.frame(gap_stats))
message("  raw gap (log points): ", round(raw_gap, 4),
        "  => ", round(100 * (exp(raw_gap) - 1), 1), "%")
message("\n--- 4. hours ---")
message("  correlation hours vs log income: ",
        round(cor(analysis_sample$hours, analysis_sample$log_income), 3))
message("\n--- 5. monthly mean/median of log(y_total_m) ---")
print(as.data.frame(monthly_income[, c("mes", "n", "mean_ly", "med_ly")]))
message("\n--- December dummy on top of a month trend ---")
print(summary(drift_test)$coefficients)
