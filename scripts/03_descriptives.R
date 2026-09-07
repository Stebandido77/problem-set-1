# 03_descriptives.R ----------------------------------------------------------
# Evidencia descriptiva que MOTIVA las decisiones de modelacion. No es un
# diccionario de datos: cada figura responde "por que el modelo esta
# especificado asi", nunca "que contiene esta variable". Lo segundo va en el
# glosario del README.
#
#   1. distribucion de y_total_m -> por que el outcome va en logaritmos
#   2. ingreso por edad          -> por que la edad entra al cuadrado
#   3. ingreso por sexo          -> la brecha cruda que explica la Seccion 2
#   4. ingreso por horas         -> por que la Seccion 1 controla por horas
#   5. ingreso por mes           -> por que `mes`/`chunk_id` no son predictores
#
# El criterio para que una figura viva aqui es que alguna decision del
# pipeline dependa de ella. Una descriptiva que no cambia ninguna decision no
# entra al codigo: va a las slides como contexto.
#
# Exporta a views/figures/ en PNG a 300 dpi. Nunca se pegan capturas de la
# consola de R en las slides.
# ----------------------------------------------------------------------------

source(here::here("scripts", "02_cleaning.R"))
source(here::here("scripts", "functions", "edad_pico.R"))
# `tema_ps`, `guardar_fig()` y `num_es()`: las figuras de esta seccion y las de
# la Seccion 1 van al mismo deck y comparten estilo.
source(here::here("scripts", "functions", "figuras.R"))

#' Coeficiente de asimetria muestral (tercer momento estandarizado)
#'
#' Se escribe a mano en lugar de sumar un paquete solo por esto. Usa el `sd()`
#' de R (denominador n-1) mientras el momento va con denominador n, de modo
#' que difiere levemente de la formula g1 de los libros de texto. No importa:
#' el numero se usa para decidir si la distribucion esta gruesamente sesgada,
#' no para hacer inferencia sobre la asimetria.
#'
#' @param x Vector numerico sin `NA`.
#' @return Escalar. Positivo = cola derecha larga, 0 = simetrica.
#' @examples
#' # asimetria(muestra_analisis$y_total_m)    # 8,49 en niveles
#' # asimetria(muestra_analisis$ingreso_log)  # -0,348 en logaritmos
asimetria <- function(x) mean((x - mean(x))^3) / sd(x)^3

# 1. Por que el outcome va en logaritmos --------------------------------------
# `y_total_m` esta fuertemente sesgada a la derecha (asimetria 8,49): en
# niveles, OLS quedaria dominado por la cola alta y los residuos serian
# gravemente heterocedasticos. En logaritmos la distribucion es casi simetrica
# (-0,348), y eso es lo que vuelve natural un modelo lineal en log-ingreso
# para las tres secciones.
#
# Tomar logaritmos tiene ademas dos consecuencias que conviene decir en las
# slides: los coeficientes se leen como cambios porcentuales aproximados, y el
# modelo predice la MEDIA del log, no el log de la media. Volver a pesos con
# `exp(prediccion)` subestima el ingreso esperado.
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

# 2. Por que la edad entra al cuadrado ----------------------------------------
# Las medias por edad dibujan un perfil concavo: el ingreso sube, se aplana y
# cae. Un termino lineal no puede representar ese descenso final, asi que la
# edad entra con su cuadrado y la Seccion 1 puede reportar una edad pico.
#
# Se exigen al menos 20 observaciones por edad para dibujar un punto: en las
# edades muy altas quedan poquisimas personas y sus medias saltan tanto que
# sugieren un patron que no esta ahi. El ajuste, en cambio, se estima sobre la
# muestra COMPLETA y no sobre las medias por edad: los puntos son evidencia
# visual, no el insumo de la regresion.
medias_por_edad <- muestra_analisis |>
  group_by(age) |>
  summarise(n = n(), media_log = mean(ingreso_log), .groups = "drop") |>
  filter(n >= 20)

# La razon -b_age / (2 * b_edad_2) se calcula con `edad_pico()` y no a mano:
# la formula vive en un solo archivo para que la figura descriptiva y la
# Seccion 1 no puedan discrepar. El objeto se llama `edad_pico_ajuste` y no
# `edad_pico` justamente para no sombrear a la funcion en el global env.
ajuste_edad      <- lm(ingreso_log ~ age + edad_2, data = muestra_analisis)
edad_pico_ajuste <- edad_pico(ajuste_edad)
grilla_edad <- tibble(
  age = seq(min(medias_por_edad$age), max(medias_por_edad$age), by = 0.5)
)
grilla_edad$edad_2 <- grilla_edad$age^2
grilla_edad$ajuste <- predict(ajuste_edad, newdata = grilla_edad)

p_edad <- ggplot(medias_por_edad, aes(age, media_log)) +
  geom_point(aes(size = n), colour = "grey55", alpha = 0.65) +
  geom_line(data = grilla_edad, aes(age, ajuste), colour = "steelblue4",
            linewidth = 0.9) +
  geom_vline(xintercept = edad_pico_ajuste, linetype = "dashed",
             colour = "firebrick", linewidth = 0.4) +
  annotate("text", x = edad_pico_ajuste + 1.2,
           y = min(medias_por_edad$media_log),
           label = sprintf("edad pico ~ %.0f", edad_pico_ajuste), hjust = 0,
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

# 3. La brecha de genero cruda que la Seccion 2 tiene que explicar ------------
# La brecha incondicional es el punto de partida de la Seccion 2: la pregunta
# alla es cuanto de ella sobrevive al condicionar por observables.
#
# Se grafican las densidades completas y no solo las dos medias a proposito:
# una diferencia de medias puede venir de un desplazamiento de toda la
# distribucion o de una cola distinta, y esas dos historias piden modelos
# distintos. Aqui se ve que las densidades tienen forma parecida y estan
# corridas, que es lo que justifica leer la brecha como un desplazamiento.
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

# 4. Por que la Seccion 1 controla por horas ----------------------------------
# La relacion ingreso-horas es concava: empinada por debajo de la jornada
# completa y practicamente plana por encima. Dos consecuencias para la
# Seccion 1. Primera: las horas varian a lo largo del ciclo de vida, de modo
# que omitirlas hace que el perfil de edad absorba variacion en OFERTA LABORAL
# y no en el salario. Segunda: el aplanamiento por encima de ~40 h advierte
# contra suponer que las horas entran linealmente.
#
# El suavizado es loess y no una recta: la pregunta es justamente que forma
# tiene la relacion, y responderla con una recta seria dar por sentada la
# respuesta. La transparencia de los puntos (alpha = 0,05) hace falta porque
# con 14.751 observaciones una nube opaca no deja ver donde esta la masa.
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

# 5. Por que `mes` y `chunk_id` nunca son predictores -------------------------
# Los 10 chunks estan ordenados por mes de encuesta (chunk 1 = enero-febrero
# ... chunk 10 = noviembre-diciembre), de modo que el corte 1-7 / 8-10 que
# fija el enunciado es TEMPORAL y no aleatorio. El mes 9 se reparte entre los
# chunks 7 y 8, asi que la frontera cae dentro de septiembre.
#
# Dos consecuencias:
#   a. Ni `mes` ni `chunk_id` pueden entrar a un modelo: cualquiera de los dos
#      filtra la particion (ver `no_predictores` en 02_cleaning.R).
#   b. Leer el RMSE de validacion como error fuera de muestra ordinario exige
#      que no haya salto de nivel entre folds. No lo hay: diciembre no se
#      dispara, porque la prima de servicios ya entra en `y_total_m`
#      mensualizada. Se prueba de dos formas, `test_dic` y `test_deriva`, y
#      ninguna encuentra el salto (ambas se imprimen al final).
#
# Esta figura es la que habilita a la Seccion 3 a interpretar su RMSE de
# validacion: sin ella, un salto de nivel entre folds seria una explicacion
# alternativa de cualquier deterioro fuera de muestra.
# Dos especificaciones distintas del mismo chequeo, y conviene no
# confundirlas al citarlas:
#   * `test_dic`    : diciembre como dummy sola. Es la que cita el subtitulo
#                     de la figura, porque la figura muestra medias por mes
#                     sin ninguna tendencia de fondo.
#   * `test_deriva` : diciembre y noviembre sobre una tendencia mensual. Es la
#                     que se imprime al final y la que cita `30_prediction.R`.
# Ninguna de las dos encuentra un salto en diciembre.
test_dic <- lm(ingreso_log ~ I(mes == 12), data = muestra_analisis)
coef_dic <- summary(test_dic)$coefficients["I(mes == 12)TRUE", ]
b_dic    <- coef_dic[["Estimate"]]
p_dic    <- coef_dic[["Pr(>|t|)"]]

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
    subtitle = sprintf(
      paste(
        "Los chunks estan ordenados por mes: el corte 1-7 / 8-10 es",
        "temporal.\nEl mes 9 se reparte entre ambos folds. Diciembre no",
        "salta: b = %s log points (%s%%), p = %s.\nLa prima de servicios ya",
        "viene mensualizada en y_total_m."
      ),
      num_es(b_dic, 4, signo = TRUE),
      num_es(100 * (exp(b_dic) - 1), 2, signo = TRUE),
      num_es(p_dic, 2)
    )
  ) +
  tema_ps
guardar_fig(p_deriva, "deriva_temporal.png")

test_deriva <- lm(ingreso_log ~ mes + I(mes == 11) + I(mes == 12),
                  data = muestra_analisis)

# Resumen en consola ----------------------------------------------------------
# Los mensajes del pipeline quedan en ingles a proposito: son log, no
# documentacion. De aqui salen los numeros que se citan en el README y en los
# decks, asi que no se transcriben a mano a ningun lado.
message("\n--- 1. skewness of the outcome ---")
message("  level: ", round(asimetria_nivel, 2),
        " | log: ", round(asimetria_log, 3))
message("\n--- 2. age profile ---")
message("  peak age from the quadratic: ", round(edad_pico_ajuste, 1))
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
message("\n--- December dummy alone (cited in the figure subtitle) ---")
print(summary(test_dic)$coefficients)
message("\n--- December dummy on top of a month trend ---")
print(summary(test_deriva)$coefficients)
