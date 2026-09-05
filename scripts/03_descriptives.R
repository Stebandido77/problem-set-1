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

dir_figuras <- here::here("views", "figures")
dir.create(dir_figuras, recursive = TRUE, showWarnings = FALSE)

tema_ps <- theme_minimal(base_size = 11) +
  theme(
    plot.title       = element_text(face = "bold", size = 11.5),
    plot.subtitle    = element_text(size = 9, colour = "grey30"),
    panel.grid.minor = element_blank()
  )

guardar_fig <- function(grafico, nombre, ancho = 7.6, alto = 4.6) {
  ggsave(file.path(dir_figuras, nombre), grafico, width = ancho,
         height = alto, dpi = 300)
}

asimetria <- function(x) mean((x - mean(x))^3) / sd(x)^3

# 1. Why the outcome is logged -------------------------------------------------
# y_total_m is strongly right-skewed, so OLS in levels would be driven by the
# top of the distribution and its residuals would be badly heteroskedastic.
# The log is close to symmetric, which is what makes a linear model in
# log-income the natural specification for all three sections.
asimetria_nivel <- asimetria(muestra_analisis$y_total_m)
asimetria_log   <- asimetria(muestra_analisis$ingreso_log)

panel_log <- muestra_analisis |>
  select(y_total_m, ingreso_log) |>
  pivot_longer(everything(), names_to = "escala", values_to = "valor") |>
  mutate(escala = factor(
    escala,
    levels = c("y_total_m", "ingreso_log"),
    labels = c(sprintf("Nivel: y_total_m (asimetria = %.1f)", asimetria_nivel),
               sprintf("Log: log(y_total_m) (asimetria = %.2f)", asimetria_log))
  ))

p_log <- ggplot(panel_log, aes(valor)) +
  geom_histogram(bins = 60, fill = "steelblue4", colour = NA) +
  facet_wrap(~escala, scales = "free") +
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
  tema_ps
guardar_fig(p_log, "dist_ingreso_log.png", ancho = 8.4)

# 2. Why age enters quadratically ---------------------------------------------
# Binned means show a concave profile: income rises with age, flattens, and
# turns down. A linear term cannot represent that, so age enters with a square
# and Section 1 can report a peak age.
medias_por_edad <- muestra_analisis |>
  group_by(age) |>
  summarise(n = n(), media_log = mean(ingreso_log), .groups = "drop") |>
  filter(n >= 20)

ajuste_edad <- lm(ingreso_log ~ age + edad_2, data = muestra_analisis)
coef_edad   <- coef(ajuste_edad)
edad_pico   <- -coef_edad[["age"]] / (2 * coef_edad[["edad_2"]])
grilla_edad <- tibble(
  age = seq(min(medias_por_edad$age), max(medias_por_edad$age), by = 0.5)
)
grilla_edad$edad_2 <- grilla_edad$age^2
grilla_edad$ajuste <- predict(ajuste_edad, newdata = grilla_edad)

p_edad <- ggplot(medias_por_edad, aes(age, media_log)) +
  geom_point(aes(size = n), colour = "grey55", alpha = 0.65) +
  geom_line(data = grilla_edad, aes(age, ajuste), colour = "steelblue4",
            linewidth = 0.9) +
  geom_vline(xintercept = edad_pico, linetype = "dashed",
             colour = "firebrick", linewidth = 0.4) +
  annotate("text", x = edad_pico + 1.2, y = min(medias_por_edad$media_log),
           label = sprintf("edad pico ~ %.0f", edad_pico), hjust = 0,
           size = 3.2, colour = "firebrick") +
  scale_size_continuous(range = c(0.8, 3.4), guide = "none") +
  labs(
    x = "Edad", y = "Media de log(ingreso laboral mensual)",
    title = "El perfil edad-ingreso es concavo: hace falta el cuadratico",
    subtitle = paste(
      "Cada punto es la media por edad (solo edades con al menos 20",
      "observaciones); el tamano refleja el N.\nLa curva es el ajuste en age",
      "y edad_2. Un termino lineal no podria representar el descenso final."
    )
  ) +
  tema_ps
guardar_fig(p_edad, "ingreso_por_edad.png")

# 3. The raw gender gap Section 2 has to explain -------------------------------
# The unconditional gap is the starting point of Section 2: the question there
# is how much of it survives once we condition on observables.
resumen_brecha <- muestra_analisis |>
  group_by(mujer) |>
  summarise(n = n(), media_log = mean(ingreso_log),
            mediana_y = median(y_total_m), .groups = "drop")
brecha_cruda <- resumen_brecha$media_log[resumen_brecha$mujer == 1] -
  resumen_brecha$media_log[resumen_brecha$mujer == 0]

p_brecha <- muestra_analisis |>
  mutate(sexo = if_else(mujer == 1, "Mujeres", "Hombres")) |>
  ggplot(aes(ingreso_log, fill = sexo, colour = sexo)) +
  geom_density(alpha = 0.28, linewidth = 0.6) +
  geom_vline(data = resumen_brecha |>
               mutate(sexo = if_else(mujer == 1, "Mujeres", "Hombres")),
             aes(xintercept = media_log, colour = sexo), linetype = "dashed",
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
      brecha_cruda, 100 * (exp(brecha_cruda) - 1)
    )
  ) +
  coord_cartesian(xlim = c(10.5, 17)) +
  tema_ps + theme(legend.position = "top")
guardar_fig(p_brecha, "ingreso_por_genero.png")

# 4. Why Section 1 conditions on hours -----------------------------------------
# The income-hours relationship is concave: steep below the full-time week and
# essentially flat above it. Two consequences for Section 1. First, hours
# vary
# over the life cycle, so leaving them out lets the age profile absorb
# variation in labour supply rather than in the wage. Second, the flattening
# above ~40 h means hours should not be assumed to enter linearly.
p_horas <- ggplot(muestra_analisis, aes(horas, ingreso_log)) +
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
  tema_ps
guardar_fig(p_horas, "ingreso_por_horas.png")

# 5. Why `mes` and `chunk_id` never become predictors --------------------------
# The 10 chunks are ordered by survey month (chunk 1 = Jan-Feb ... chunk 10 =
# Nov-Dec), so the mandated 1-7 / 8-10 split is temporal rather than
# random.
# Two consequences:
#   a. `mes` and `chunk_id` must never enter a model: either one would leak the
#      split (see `no_predictores` in 02_cleaning.R).
#   b. Reading the validation RMSE as ordinary out-of-sample error requires no
#      level shift between folds. There is none: December does not jump,
#      because the prima de servicios already enters y_total_m on a
#      monthly-equivalent basis.
ingreso_mensual <- muestra_analisis |>
  group_by(mes) |>
  summarise(n = n(), media_log = mean(ingreso_log),
            mediana_log = median(ingreso_log),
            se = sd(ingreso_log) / sqrt(n()), .groups = "drop") |>
  mutate(lo = media_log - 1.96 * se, hi = media_log + 1.96 * se)

p_deriva <- ggplot(ingreso_mensual, aes(mes, media_log)) +
  annotate("rect", xmin = 8.5, xmax = 12.5, ymin = -Inf, ymax = Inf,
           fill = "grey85", alpha = 0.6) +
  annotate("text", x = 10.5, y = max(ingreso_mensual$hi),
           label = "validacion (chunks 8-10)", size = 3.1, colour = "grey30",
           vjust = 1.4) +
  annotate("text", x = 4.5, y = max(ingreso_mensual$hi),
           label = "entrenamiento (chunks 1-7)", size = 3.1, colour = "grey30",
           vjust = 1.4) +
  geom_hline(yintercept = mean(muestra_analisis$ingreso_log),
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
  tema_ps
guardar_fig(p_deriva, "deriva_temporal.png")

test_deriva <- lm(ingreso_log ~ mes + I(mes == 11) + I(mes == 12),
                  data = muestra_analisis)

# Console summary --------------------------------------------------------------
message("\n--- 1. skewness of the outcome ---")
message("  level: ", round(asimetria_nivel, 2),
        " | log: ", round(asimetria_log, 3))
message("\n--- 2. age profile ---")
message("  peak age from the quadratic: ", round(edad_pico, 1))
message("\n--- 3. unconditional gender gap ---")
print(as.data.frame(resumen_brecha))
message("  raw gap (log points): ", round(brecha_cruda, 4),
        "  => ", round(100 * (exp(brecha_cruda) - 1), 1), "%")
message("\n--- 4. hours ---")
message("  correlation hours vs log income: ",
        round(cor(muestra_analisis$horas, muestra_analisis$ingreso_log), 3))
message("\n--- 5. monthly mean/median of log(y_total_m) ---")
print(as.data.frame(
  ingreso_mensual[, c("mes", "n", "media_log", "mediana_log")]
))
message("\n--- December dummy on top of a month trend ---")
print(summary(test_deriva)$coefficients)
