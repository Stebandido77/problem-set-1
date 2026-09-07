# 10_age_profile.R -----------------------------------------------------------
# Seccion 1: perfil edad-ingreso laboral.
#
#   (1) Incondicional:  log(w) = b1 + b2*age + b3*age^2 + u
#   (2) Condicional:    + totalHoursWorked + relab
#   (3) Edad pico = -b2 / (2*b3), con intervalo de confianza bootstrap.
#
# POR QUE EL CUADRATICO
# Las medias de log(y_total_m) por edad dibujan un perfil concavo: el ingreso
# sube, se aplana y cae (ver `views/figures/ingreso_por_edad.png`). Un termino
# lineal no puede representar ese descenso final, y sin el no existe una edad
# pico que reportar. La concavidad NO se supone: se verifica abajo mirando el
# signo y la significancia de `edad_2`, porque es la prediccion contrastable
# de la teoria de capital humano y podria no cumplirse en el dato.
#
# POR QUE LA MUESTRA ES LA COMPLETA Y NO `entrenamiento`
# Las dos especificaciones se estiman sobre las 14.751 filas de
# `muestra_analisis`. La Seccion 1 es un ejercicio de DESCRIPCION del perfil
# poblacional, no de prediccion: reservar los chunks 8-10 aqui tiraria
# informacion sin comprar nada, porque no hay ninguna eleccion de modelo que
# validar. La reestimacion sobre `particion == "entrenamiento"` pertenece a la
# Seccion 3, donde el fold de validacion si tiene un trabajo que hacer.
#
# POR QUE LA ESPECIFICACION CONDICIONAL CONTROLA POR HORAS Y POSICION
# El enunciado fija estos dos controles y ningun otro. `totalHoursWorked` y
# `relab` capturan cuanto se trabaja y en que posicion ocupacional, dos cosas
# que cambian sistematicamente a lo largo del ciclo de vida.
#
# PERO OJO: `horas` ES UN BAD CONTROL PARA ESTA PREGUNTA
# Las horas trabajadas no son una caracteristica predeterminada de la persona:
# son una decision que responde a la edad y al salario. Condicionar en ellas
# CIERRA uno de los canales por los que la edad afecta al ingreso mensual, en
# vez de aislar un efecto mas limpio. Lo mismo vale para `relab`: la
# composicion entre asalariados e independientes es un resultado del mercado
# laboral, no un rasgo fijo de la persona.
#
# La consecuencia es que las dos especificaciones NO son la misma pregunta con
# mas o menos precision. Son dos objetos distintos:
#
#   * la incondicional estima el perfil del INGRESO LABORAL MENSUAL observado:
#     el total que una persona gana en el mes, que incorpora tanto el precio de
#     su hora como cuantas horas trabaja y en que posicion lo hace;
#   * la condicional estima el perfil del PRECIO DEL TRABAJO A HORAS Y POSICION
#     FIJAS: cuanto cambia el ingreso con la edad ENTRE personas que trabajan
#     lo mismo y en la misma posicion ocupacional.
#
# Por eso la condicional no es "la version mejorada" de la incondicional, y si
# el pico se mueve al condicionar, ese desplazamiento es el resultado y hay que
# interpretarlo, no corregirlo.
#
# POR QUE LA EDAD PICO NECESITA BOOTSTRAP
# Es una razon de coeficientes, no un coeficiente: `lm()` no reporta su error
# estandar y el metodo delta se degrada porque el denominador esta cerca de
# cero. El detalle esta documentado en `scripts/functions/edad_pico.R`.
# ----------------------------------------------------------------------------

source(here::here("scripts", "02_cleaning.R"))
source(here::here("scripts", "functions", "edad_pico.R"))
source(here::here("scripts", "functions", "figuras.R"))

# 1. Las dos especificaciones -------------------------------------------------

perfil_incondicional <- lm(ingreso_log ~ age + edad_2,
                           data = muestra_analisis)

# EQUIVALENCIA CON LOS NOMBRES DEL ENUNCIADO. El PDF pide controlar por
# `totalHoursWorked` y `relab`; en la muestra de analisis esas dos columnas
# llegan renombradas por `02_cleaning.R` y hay que poder rastrear la
# correspondencia sin abrir el otro archivo:
#
#   * `horas` es `totalHoursWorked` sin ninguna transformacion, solo con un
#     nombre legible. El filtro de horas implausibles (<= 112 h/semana) ya se
#     aplico al construir la muestra.
#   * `relab_grupo` es `relab` con el nivel 8 (jornalero) plegado en el 9
#     ("otro"). El 8 tiene UNA sola observacion de entrenamiento: como dummy
#     propia se ajustaria perfectamente, no aportaria nada y romperia el LOOCV
#     de la Seccion 3 por apalancamiento 1. Es la unica diferencia entre
#     `relab_grupo` y el `relab` que nombra el enunciado.
perfil_condicional <- lm(ingreso_log ~ age + edad_2 + horas + relab_grupo,
                         data = muestra_analisis)

# "and no other controls": el enunciado es explicito y un control de mas no es
# una mejora, es una especificacion equivocada. La guarda falla en la corrida
# si alguien agrega un regresor, en vez de dejar que la tabla salga mal en
# silencio.
stopifnot(identical(
  attr(terms(perfil_condicional), "term.labels"),
  c("age", "edad_2", "horas", "relab_grupo")
))

# 2. La forma del perfil: concavidad y edad pico ------------------------------
# La teoria de capital humano predice un perfil concavo (b3 < 0). Es una
# prediccion contrastable, no un supuesto: si `edad_2` saliera positiva o
# indistinguible de cero, `edad_pico()` devolveria igual un numero, y ese
# numero seria un MINIMO o puro ruido. Por eso el signo y la significancia se
# verifican y se reportan ANTES que la edad pico.

#' Extraer estimacion, error estandar, t y p de un coeficiente
#'
#' @param modelo Objeto ajustado por `lm()`.
#' @param termino Nombre del coeficiente. Por defecto `"edad_2"`, el termino
#'   cuadratico cuya negatividad hace que exista una edad pico.
#' @return Lista con `estimacion`, `ee`, `t` y `p`.
#' @examples
#' # resumen_coeficiente(perfil_incondicional, "edad_2")
resumen_coeficiente <- function(modelo, termino = "edad_2") {
  fila <- summary(modelo)$coefficients[termino, ]
  list(estimacion = unname(fila[["Estimate"]]),
       ee         = unname(fila[["Std. Error"]]),
       t          = unname(fila[["t value"]]),
       p          = unname(fila[["Pr(>|t|)"]]))
}

cuadratico_incondicional <- resumen_coeficiente(perfil_incondicional)
cuadratico_condicional   <- resumen_coeficiente(perfil_condicional)

rango_edad <- range(muestra_analisis$age)

pico_incondicional <- edad_pico(perfil_incondicional)
pico_condicional   <- edad_pico(perfil_condicional)

#' Verificar si la edad pico cae dentro del rango de edad observado
#'
#' Una edad pico fuera del rango de los datos es una EXTRAPOLACION: el maximo
#' de la parabola caeria donde no hay observaciones y, dentro del rango que si
#' se observa, el perfil seria monotono. En ese caso no se puede hablar de un
#' pico del ciclo de vida y hay que decirlo en vez de reportar el numero.
#'
#' @param pico Escalar devuelto por `edad_pico()`.
#' @param rango Vector de dos elementos: `range(muestra_analisis$age)`.
#' @return `TRUE` si el pico cae estrictamente dentro del rango observado.
#' @examples
#' # pico_dentro_del_rango(40.6, c(18, 91))
pico_dentro_del_rango <- function(pico, rango) {
  pico > rango[[1]] && pico < rango[[2]]
}

dentro_incondicional <- pico_dentro_del_rango(pico_incondicional, rango_edad)
dentro_condicional   <- pico_dentro_del_rango(pico_condicional, rango_edad)

# 3. Figuras ------------------------------------------------------------------
# El perfil condicional se evalua en un trabajador de referencia: horas en su
# media muestral y la posicion ocupacional modal. Esa eleccion mueve el NIVEL
# de la curva, no su forma ni la edad pico, porque `horas` y `relab_grupo`
# entran sin interactuar con la edad.
horas_referencia <- mean(muestra_analisis$horas)
relab_referencia <- names(which.max(table(muestra_analisis$relab_grupo)))

grilla_edad <- tibble(age = seq(rango_edad[[1]], rango_edad[[2]], by = 0.5)) |>
  mutate(
    edad_2      = age^2,
    horas       = horas_referencia,
    relab_grupo = factor(relab_referencia,
                         levels = levels(muestra_analisis$relab_grupo))
  )

#' Predecir un perfil sobre la grilla de edad, con banda de confianza
#'
#' @param modelo Objeto ajustado por `lm()`.
#' @param grilla Tibble con todas las columnas que pide el modelo.
#' @return La grilla con `ajuste`, `lo` y `hi` (banda al 95%).
#' @examples
#' # predecir_perfil(perfil_condicional, grilla_edad)
predecir_perfil <- function(modelo, grilla) {
  pred <- predict(modelo, newdata = grilla, interval = "confidence")
  grilla |>
    mutate(ajuste = pred[, "fit"], lo = pred[, "lwr"], hi = pred[, "upr"])
}

perfil_inc_pred  <- predecir_perfil(perfil_incondicional, grilla_edad)
perfil_cond_pred <- predecir_perfil(perfil_condicional, grilla_edad)

p_condicional <- ggplot(perfil_cond_pred, aes(age, ajuste)) +
  geom_ribbon(aes(ymin = lo, ymax = hi), fill = "steelblue4", alpha = 0.18) +
  geom_line(colour = "steelblue4", linewidth = 0.9) +
  geom_vline(xintercept = pico_condicional, linetype = "dashed",
             colour = "firebrick", linewidth = 0.4) +
  annotate("text", x = pico_condicional + 1.2, y = min(perfil_cond_pred$lo),
           label = sprintf("edad pico = %s", num_es(pico_condicional, 1)),
           hjust = 0, size = 3.2, colour = "firebrick") +
  labs(
    x = "Edad", y = "log(ingreso laboral mensual) predicho",
    title = "Perfil condicional: el precio del trabajo a horas y posicion fijas",
    subtitle = sprintf(paste(
      "Control por horas trabajadas y posicion ocupacional, y ningun otro.",
      "Evaluado en horas = %s h/semana\n(la media muestral) y posicion",
      "ocupacional modal: esa eleccion fija el nivel de la curva, no su forma.",
      "Banda: IC al 95%%\nde la media condicional."
    ), num_es(horas_referencia, 1))
  ) +
  tema_ps
guardar_fig(p_condicional, "perfil_edad_condicional.png")

# La comparacion se dibuja sobre curvas CENTRADAS en su propio promedio. Los
# dos perfiles viven en niveles distintos (el condicional depende del punto de
# evaluacion), y superponerlos sin centrar invita a leer la distancia vertical
# como si significara algo. Lo comparable es la forma y la posicion del pico.
comparacion <- bind_rows(
  perfil_inc_pred  |> mutate(especificacion = "Incondicional"),
  perfil_cond_pred |> mutate(especificacion = "Condicional (horas + posicion)")
) |>
  group_by(especificacion) |>
  mutate(ajuste_centrado = ajuste - mean(ajuste)) |>
  ungroup() |>
  mutate(especificacion = factor(
    especificacion,
    levels = c("Incondicional", "Condicional (horas + posicion)")
  ))

picos <- tibble(
  especificacion = factor(
    c("Incondicional", "Condicional (horas + posicion)"),
    levels = levels(comparacion$especificacion)
  ),
  pico = c(pico_incondicional, pico_condicional)
)

p_comparacion <- ggplot(comparacion,
                        aes(age, ajuste_centrado, colour = especificacion)) +
  geom_line(linewidth = 0.9) +
  geom_vline(data = picos, aes(xintercept = pico, colour = especificacion),
             linetype = "dashed", linewidth = 0.4, show.legend = FALSE) +
  scale_colour_manual(
    values = c("Incondicional" = "grey35",
               "Condicional (horas + posicion)" = "steelblue4")
  ) +
  labs(
    x = "Edad", y = "log(ingreso) centrado en el promedio de cada perfil",
    colour = NULL,
    title = "Condicionar en horas no mejora el perfil: cambia la pregunta",
    subtitle = sprintf(paste(
      "El pico pasa de %s a %s anos al fijar horas y posicion ocupacional.",
      "Cada curva esta centrada en su\npropio promedio: entre",
      "especificaciones el nivel no es comparable, la forma y el pico si."
    ), num_es(pico_incondicional, 1), num_es(pico_condicional, 1))
  ) +
  tema_ps +
  theme(legend.position = "top")
guardar_fig(p_comparacion, "perfiles_edad_comparacion.png")

# 4. Resumen en consola -------------------------------------------------------
# Los mensajes del pipeline quedan en ingles a proposito: son log, no
# documentacion. De aqui salen los numeros que se citan en el deck, asi que no
# se transcriben a mano a ningun lado.
message("\n--- 1. sample used for section 1 ---")
message("  N: ", nrow(muestra_analisis), " (full analysis sample, NOT train)")
message("  observed age range: ", rango_edad[[1]], " to ", rango_edad[[2]])

message("\n--- 2. concavity check (edad_2 must be negative) ---")
message("  unconditional: b = ", signif(cuadratico_incondicional$estimacion, 4),
        " | t = ", round(cuadratico_incondicional$t, 2),
        " | p = ", format.pval(cuadratico_incondicional$p, digits = 3))
message("  conditional  : b = ", signif(cuadratico_condicional$estimacion, 4),
        " | t = ", round(cuadratico_condicional$t, 2),
        " | p = ", format.pval(cuadratico_condicional$p, digits = 3))

message("\n--- 3. peak age ---")
message("  unconditional: ", round(pico_incondicional, 2),
        " | inside observed range: ", dentro_incondicional)
message("  conditional  : ", round(pico_condicional, 2),
        " | inside observed range: ", dentro_condicional)

message("\n--- 4. in-sample fit (R2) ---")
message("  unconditional: ", round(summary(perfil_incondicional)$r.squared, 4))
message("  conditional  : ", round(summary(perfil_condicional)$r.squared, 4))
