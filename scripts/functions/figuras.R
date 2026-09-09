# figuras.R ------------------------------------------------------------------
# Estilo y guardado de las figuras del proyecto.
#
# POR QUE ESTO NO VIVE DENTRO DE UN SCRIPT DE SECCION
# Las figuras de `03_descriptives.R` y las de `10_age_profile.R` terminan en el
# MISMO deck. Si cada script trae su propio tema y su propio tamano de lienzo,
# las laminas se leen como trabajos distintos: cambian el cuerpo de letra, el
# grosor de la grilla y la proporcion. Manteniendo el tema en un solo archivo,
# ajustar el estilo del deck es editar aqui y volver a correr el pipeline.
#
# `num_es()` esta aqui por la misma razon que el tema: existe para que las
# cifras de titulos y subtitulos se INTERPOLEN desde el objeto que las produjo
# en vez de teclearse, y ese es un requisito de todas las figuras, no de una.
# ----------------------------------------------------------------------------

dir_figuras <- here::here("views", "figures")
dir.create(dir_figuras, recursive = TRUE, showWarnings = FALSE)

# Un unico tema para todas las figuras del deck.
tema_ps <- theme_minimal(base_size = 11) +
  theme(
    plot.title       = element_text(face = "bold", size = 11.5),
    plot.subtitle    = element_text(size = 9, colour = "grey30"),
    panel.grid.minor = element_blank()
  )

#' Guardar una figura en views/figures/ con tamano y resolucion uniformes
#'
#' @param grafico Objeto de ggplot2.
#' @param nombre Nombre del archivo, con extension (por ejemplo
#'   `"ingreso_por_edad.png"`). La ruta la pone la funcion.
#' @param ancho,alto Pulgadas. Los defaults estan calibrados para una lamina
#'   de beamer; solo se cambian cuando la figura lleva facetas.
#' @return La ruta del archivo, de forma invisible (lo que devuelve `ggsave`).
#' @examples
#' # guardar_fig(p_edad, "ingreso_por_edad.png")
#' # guardar_fig(p_log, "dist_ingreso_log.png", ancho = 8.4)
guardar_fig <- function(grafico, nombre, ancho = 7.6, alto = 4.6) {
  ggsave(file.path(dir_figuras, nombre), grafico, width = ancho,
         height = alto, dpi = 300)
}

#' Formatear un numero para un titulo o subtitulo, en convencion espanola
#'
#' Existe para que las cifras de las figuras se INTERPOLEN desde el objeto que
#' las produjo en vez de escribirse a mano. Un numero tecleado en un subtitulo
#' sobrevive a los cambios de muestra sin avisar; uno interpolado, no.
#'
#' @param x Escalar numerico.
#' @param digitos Decimales a mostrar.
#' @param signo Si `TRUE`, fuerza el signo explicito (`+` o `-`).
#' @return Cadena con "," como separador decimal.
#' @examples
#' # num_es(0.008690, 4, signo = TRUE)  # "+0,0087"
#' # num_es(0.757700, 2)                # "0,76"
num_es <- function(x, digitos, signo = FALSE) {
  formatC(x, format = "f", digits = digitos, decimal.mark = ",",
          flag = if (signo) "+" else "")
}
