# rmse() ---------------------------------------------------------------------
# Raiz del error cuadratico medio: la metrica que fija el enunciado para
# comparar especificaciones en la Seccion 3.
#
# POR QUE RMSE Y NO ERROR ABSOLUTO MEDIO
# El RMSE eleva el error al cuadrado y por eso castiga mas los errores
# grandes. Eso es justo lo que quiere el ejercicio: el interes esta en
# detectar subreporte de ingresos, y quien subreporta produce precisamente un
# error grande. Una metrica en valor absoluto lo diluiria entre muchos errores
# pequenos.
#
# CUIDADO CON LA ESCALA
# Todas las especificaciones modelan log(y_total_m), de modo que el RMSE sale
# en log-puntos y solo es comparable entre modelos con el MISMO outcome. Un
# RMSE en logaritmos y uno en pesos no se pueden poner en la misma tabla.
# ----------------------------------------------------------------------------

#' Raiz del error cuadratico medio
#'
#' @param observado Vector numerico con los valores realizados del outcome.
#' @param predicho Vector numerico de predicciones, de la misma longitud y en
#'   la misma escala que `observado`.
#' @return Escalar no negativo, en las unidades de `observado`. Los pares con
#'   `NA` se descartan (`na.rm = TRUE`): eso evita que una prediccion faltante
#'   rompa el calculo, pero tambien significa que un modelo que no predice
#'   sobre parte de la muestra no queda penalizado por ello. Hay que verificar
#'   aparte que ambos vectores tengan la misma longitud.
#' @examples
#' rmse(c(1, 2, 3), c(1.5, 2.5, 2.5))  # 0.5
#'
#' # Uso tipico en la Seccion 3: error fuera de muestra sobre validacion.
#' # valida <- dplyr::filter(muestra_analisis, particion == "validacion")
#' # rmse(valida$ingreso_log, predict(modelo, newdata = valida))
rmse <- function(observado, predicho) {
  sqrt(mean((observado - predicho)^2, na.rm = TRUE))
}
