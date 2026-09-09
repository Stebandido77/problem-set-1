# 01_scraping.R --------------------------------------------------------------
# Descarga los 10 chunks de la GEIH 2018 y los guarda en stores/raw/.
#
# COMO SE COMPORTA EL SCRAPER
# El scraper cachea en disco y no vuelve a pedir un archivo que ya existe, deja
# 1,5 s entre peticiones vivas y se identifica con un user agent que dice de
# que curso viene y como contactarnos. Son ~227 MB en un servidor de GitHub
# Pages que no es nuestro: reventarlo a peticiones seria gratuito para
# nosotros y caro para el.
#
# COMO ESTA ARMADO EL SITIO
# Las paginas enlazadas (page1.html ... page10.html) son cascaras vacias: la
# tabla la inyecta el navegador con un shim XHR `w3-include-html`, asi que
# parsearlas devuelve CERO tablas. El contenido real vive en
# pages/geih_page_N.html (~22,7 MB de <table> crudo cada uno) y se sirve por
# HTTP plano, de modo que no hace falta un navegador headless: basta httr2.
# Ese hallazgo es la razon de que este script sea corto.
#
# POR QUE NO SE USA janitor::clean_names()
# `clean_names()` convertiria `totalHoursWorked` en `total_hours_worked`,
# `maxEducLevel` en `max_educ_level` y `y_total_m` en `y_total_m` (esta ultima
# sobrevive, pero las camelCase no). Los nombres del DANE se conservan
# VERBATIM, camelCase incluido, por dos razones: mantienen la correspondencia
# uno a uno con el diccionario de variables del curso, y el enunciado nombra
# las variables tal cual. El precio es convivir con dos convenciones de
# nomenclatura en el mismo data frame, y se paga a proposito: las columnas
# del DANE quedan en su forma original y las que construye el equipo van en
# snake_case y en espanol (ver `02_cleaning.R`). Que el estilo cambie es la
# senal visual de que la columna no es nuestra.
#
# Las 178 columnas crudas se conservan intactas en stores/raw/; la seleccion
# ocurre despues, en `02_cleaning.R`.
# ----------------------------------------------------------------------------

source(here::here("scripts", "00_packages.R"))

url_base   <- "https://ignaciomsarmiento.github.io/GEIH2018_sample"
dir_crudos <- here::here("stores", "raw")
dir_html   <- file.path(dir_crudos, "html")

dir.create(dir_html, recursive = TRUE, showWarnings = FALSE)

n_chunks       <- 10
pausa_cortesia <- 1.5    # segundos entre peticiones vivas
bytes_min      <- 1e6    # piso de cordura: un chunk real pesa ~22 MB
agente_usuario <- paste(
  "MECA4107-PS1/1.0 (Universidad de los Andes coursework;",
  "R httr2; contact via course staff)"
)

#' Descargar a disco el HTML de un chunk
#'
#' Reintenta hasta 4 veces con backoff exponencial (2, 4, 8, 16 s) porque los
#' archivos son grandes y una descarga cortada es el modo de falla tipico.
#' El timeout de 900 s esta calibrado para eso, no para un servidor lento.
#'
#' @param chunk Entero de 1 a 10: el numero de chunk en la URL.
#' @param destino Ruta del archivo donde se escribe el HTML.
#' @return La ruta `destino`, de forma invisible. Falla con `stop()` si el
#'   archivo bajado pesa menos de `bytes_min`, y borra antes el parcial: un
#'   archivo truncado en disco seria peor que no tenerlo, porque las corridas
#'   siguientes lo tomarian por cache valido.
#' @examples
#' # descargar_chunk_html(1, file.path(dir_html, "geih_page_1.html"))
descargar_chunk_html <- function(chunk, destino) {
  url <- sprintf("%s/pages/geih_page_%d.html", url_base, chunk)

  httr2::request(url) |>
    httr2::req_user_agent(agente_usuario) |>
    httr2::req_timeout(900) |>
    httr2::req_retry(max_tries = 4, backoff = \(tries) 2^tries) |>
    httr2::req_perform(path = destino)

  if (file.size(destino) < bytes_min) {
    unlink(destino)
    stop("Chunk ", chunk, " came back too small; deleted partial download.")
  }

  invisible(destino)
}

#' Parsear la <table> incrustada y devolverla como tibble
#'
#' Los nombres de columna se dejan tal como vienen: ver la nota sobre
#' `clean_names()` en el encabezado del archivo.
#'
#' @param ruta Ruta al HTML ya descargado.
#' @param chunk Entero de 1 a 10; se agrega como primera columna `chunk_id`.
#' @return Un tibble de ~3.218 x 178 con `chunk_id` al frente. `chunk_id` es
#'   la unica columna que agregamos aqui, y queda registrada en
#'   `no_predictores` (`02_cleaning.R`) porque codifica el calendario.
#' @examples
#' # parsear_chunk_html(file.path(dir_html, "geih_page_1.html"), 1)
parsear_chunk_html <- function(ruta, chunk) {
  tabla <- xml2::read_html(ruta) |>
    rvest::html_element("table") |>
    rvest::html_table(header = TRUE, convert = TRUE)

  # tableHTML emite una primera columna sin nombre con los nombres de fila.
  if (!nzchar(names(tabla)[1]) || is.na(names(tabla)[1])) {
    tabla <- tabla[, -1]
  }

  tabla |> dplyr::mutate(chunk_id = chunk, .before = 1)
}

#' Obtener un chunk, reutilizando lo que ya este en disco
#'
#' Cache en dos niveles: si existe el `.rds` no se parsea nada; si existe el
#' HTML completo se parsea sin pedir nada a la red; solo si no hay ninguno de
#' los dos se hace una peticion viva. Por eso una segunda corrida del pipeline
#' no emite ni una peticion.
#'
#' @param chunk Entero de 1 a 10.
#' @return El tibble del chunk. Como efecto secundario deja
#'   `stores/raw/chunk_NN.rds` (y el HTML) escritos en disco.
#' @examples
#' # chunks <- lapply(seq_len(n_chunks), scrapear_chunk)
scrapear_chunk <- function(chunk) {
  ruta_rds  <- file.path(dir_crudos, sprintf("chunk_%02d.rds", chunk))
  ruta_html <- file.path(dir_html, sprintf("geih_page_%d.html", chunk))

  if (file.exists(ruta_rds)) {
    message("chunk ", chunk, ": cached .rds, skipping.")
    return(readRDS(ruta_rds))
  }

  if (file.exists(ruta_html) && file.size(ruta_html) >= bytes_min) {
    message("chunk ", chunk, ": cached html, parsing (no request).")
  } else {
    message("chunk ", chunk, ": downloading ...")
    descargar_chunk_html(chunk, ruta_html)
    Sys.sleep(pausa_cortesia)
  }

  salida <- parsear_chunk_html(ruta_html, chunk)
  saveRDS(salida, ruta_rds)
  message("chunk ", chunk, ": saved ", nrow(salida), " x ", ncol(salida), ".")
  salida
}

chunks <- lapply(seq_len(n_chunks), scrapear_chunk)

# Reporte ---------------------------------------------------------------------
# El chequeo que importa es el de esquema: si un chunk trajera columnas
# distintas, el `bind_rows()` de `02_cleaning.R` las rellenaria con NA en
# silencio y la muestra quedaria mal sin que nadie se entere. Por eso se
# compara la lista de nombres contra el chunk 1 y, si difiere, se imprime
# exactamente que columna sobra o falta.
tamanos <- vapply(chunks, nrow, integer(1))
nombres_por_chunk <- lapply(chunks, names)
mismo_esquema <- all(vapply(
  nombres_por_chunk, identical, logical(1), nombres_por_chunk[[1]]
))

message("\n--- scraping report ---")
print(tibble::tibble(
  chunk = seq_len(n_chunks),
  rows  = tamanos,
  cols  = vapply(chunks, ncol, integer(1))
))
message("total rows: ", sum(tamanos))
message("identical column schema across the 10 chunks: ", mismo_esquema)

if (!mismo_esquema) {
  ref <- nombres_por_chunk[[1]]
  for (i in seq_len(n_chunks)) {
    d <- c(setdiff(nombres_por_chunk[[i]], ref),
           setdiff(ref, nombres_por_chunk[[i]]))
    if (length(d)) {
      message("chunk ", i, " deviates: ", paste(d, collapse = ", "))
    }
  }
}

# Los 10 chunks juntos ocupan ~31 MB en memoria y este script ya no los
# usa: quien los necesita es `02_cleaning.R`, que los relee del `.rds`.
rm(chunks)
invisible(gc())




