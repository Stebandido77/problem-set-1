# rmse_loocv() ---------------------------------------------------------------
# Validacion cruzada dejando uno fuera (LOOCV) en forma cerrada para OLS.
#
# POR QUE NO SE REESTIMA EL MODELO n VECES
# En un modelo lineal ajustado por minimos cuadrados, el residuo de dejar
# fuera la observacion i tiene solucion analitica:
#
#     e_(-i) = e_i / (1 - h_ii)
#
# donde h_ii es el i-esimo elemento de la diagonal de la matriz sombrero
# H = X (X'X)^(-1) X'. La identidad es EXACTA, no una aproximacion: sale de
# actualizar (X'X)^(-1) por rango uno (Sherman-Morrison) al quitar una fila.
#
# El ahorro no es cosmetico. Con las 10.255 filas de entrenamiento, la version
# por fuerza bruta exige 10.255 ajustes; esta exige uno solo, mas la diagonal
# de H que `lm()` ya dejo calculada. El enunciado pide explicitamente el atajo
# por la matriz sombrero.
#
# DOS ADVERTENCIAS
#   * h_ii = 1 hace estallar el cociente. Ocurre cuando una observacion se
#     ajusta perfectamente, tipicamente un nivel de factor con una sola
#     observacion. Por eso `02_cleaning.R` colapsa `relab == 8` (un unico
#     caso en entrenamiento) y agrupa los niveles raros de `oficio`: sin eso,
#     el LOOCV de cualquier especificacion que los incluya seria infinito.
#   * La identidad vale para OLS sobre una matriz de diseno FIJA. Los pasos de
#     preprocesamiento estimados con los datos (el umbral de `oficio`, por
#     ejemplo) quedan fuera del ciclo de validacion, de modo que este LOOCV es
#     apenas optimista frente a uno que reprocesara en cada iteracion.
# ----------------------------------------------------------------------------

#' RMSE de validacion cruzada dejando uno fuera, para OLS
#'
#' @param modelo Objeto ajustado por `lm()`. Debe ser OLS: la identidad del
#'   residuo PRESS no vale para modelos ajustados de otra manera.
#' @return Escalar: la raiz del error cuadratico medio de los n residuos
#'   dejando uno fuera, en las unidades del outcome (log-puntos, aqui).
#'   Devuelve `Inf` si alguna observacion tiene apalancamiento h_ii = 1.
#' @examples
#' entrena <- dplyr::filter(muestra_analisis, particion == "entrenamiento")
#' modelo  <- lm(ingreso_log ~ age + edad_2 + horas, data = entrena)
#' rmse_loocv(modelo)
#'
#' # Equivalencia con la fuerza bruta (10.255 ajustes en lugar de 1):
#' # sqrt(mean(vapply(seq_len(nrow(entrena)), function(i) {
#' #   (entrena$ingreso_log[i] -
#' #      predict(update(modelo, data = entrena[-i, ]), entrena[i, ]))^2
#' # }, numeric(1))))
rmse_loocv <- function(modelo) {
  e <- residuals(modelo)
  h <- stats::hatvalues(modelo)
  sqrt(mean((e / (1 - h))^2))
}
