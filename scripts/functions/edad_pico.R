# edad_pico() ----------------------------------------------------------------
# Edad que maximiza el perfil cuadratico edad-ingreso.
#
# POR QUE EL INTERVALO DE CONFIANZA DE ESTA CANTIDAD SE BOOTSTRAPEA
# La edad pico no es un coeficiente: es la RAZON -b_edad / (2 * b_edad_2), una
# funcion no lineal de dos coeficientes ademas correlacionados entre si. De
# ahi salen tres problemas que el bootstrap resuelve y la salida de `lm()` no:
#
#   1. `lm()` no reporta el error estandar de una razon de coeficientes. Hay
#      que construirlo aparte; no se lee de la tabla de regresion.
#   2. El metodo delta lo aproxima linealizando alrededor de las estimaciones,
#      y esa aproximacion se degrada a medida que el denominador
#      (2 * b_edad_2) se acerca a cero. Aqui b_edad_2 es pequeno y negativo,
#      de modo que la razon tiene cola pesada y el intervalo delta queda
#      demasiado angosto.
#   3. La distribucion muestral de una razon no es simetrica, asi que no hay
#      motivo para que el intervalo quede centrado en la estimacion puntual.
#      El metodo delta impone esa simetria por construccion; el bootstrap no.
#
# Por eso la Seccion 1 reporta un intervalo BOOTSTRAP por percentiles: se
# remuestrea la muestra con reemplazo, se reestima el modelo, se recalcula la
# razon con esta misma funcion y se leen los percentiles de las B replicas. La
# semilla queda fijada en `00_packages.R` (`set.seed(1234)`) para que el
# intervalo sea reproducible.
# ----------------------------------------------------------------------------

#' Edad pico implicada por un perfil cuadratico de ingreso
#'
#' Resuelve la condicion de primer orden del perfil
#' `E[log(w) | edad] = b0 + b_edad * edad + b_edad_2 * edad^2`, cuyo maximo
#' esta en `-b_edad / (2 * b_edad_2)`.
#'
#' @param modelo Objeto ajustado por `lm()` (sirve cualquiera con metodo
#'   `coef()`) que incluya el termino lineal y el cuadratico de la edad.
#' @param termino_edad Nombre del coeficiente lineal. Por defecto `"age"`:
#'   `age` viene del dato del DANE y por eso conserva su nombre original.
#' @param termino_edad_2 Nombre del coeficiente cuadratico. Por defecto
#'   `"edad_2"`, la variable derivada que construye `02_cleaning.R`.
#' @return Escalar: la edad, en anos, que maximiza el perfil. Se devuelve sin
#'   nombre (`unname()`) para poder apilar directamente las replicas del
#'   bootstrap. Si el perfil resultara convexo (`b_edad_2 > 0`) la funcion no
#'   falla: devuelve un minimo, no un maximo. Conviene revisar el signo del
#'   termino cuadratico antes de reportar el numero.
#' @examples
#' modelo <- lm(ingreso_log ~ age + edad_2, data = muestra_analisis)
#' edad_pico(modelo)  # 40,6 en la muestra base
#'
#' # Perfiles separados por sexo (Seccion 2): los terminos cambian de nombre.
#' # edad_pico(modelo_interactuado, termino_edad = "age:mujer",
#' #           termino_edad_2 = "edad_2:mujer")
edad_pico <- function(modelo, termino_edad = "age", termino_edad_2 = "edad_2") {
  b <- coef(modelo)
  unname(-b[[termino_edad]] / (2 * b[[termino_edad_2]]))
}
