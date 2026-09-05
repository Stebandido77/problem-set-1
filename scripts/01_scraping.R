# 01_scraping.R --------------------------------------------------------------
# Scrapes the 10 GEIH 2018 chunks and stores them in stores/raw/.
# Be polite: cache locally and do not re-download if the file already exists.
#
# NOTE ON THE SITE STRUCTURE
# The linked pages (page1.html ... page10.html) are empty shells: the table is
# injected client-side by a `w3-include-html` XHR shim, so parsing them yields
# zero tables. The actual payload lives at pages/geih_page_N.html (~22.7 MB of
# raw <table> each) and is served over plain HTTP, so no browser is needed.
# ----------------------------------------------------------------------------

source(here::here("scripts", "00_packages.R"))

url_base   <- "https://ignaciomsarmiento.github.io/GEIH2018_sample"
dir_crudos <- here::here("stores", "raw")
dir_html   <- file.path(dir_crudos, "html")

dir.create(dir_html, recursive = TRUE, showWarnings = FALSE)

n_chunks       <- 10
pausa_cortesia <- 1.5    # seconds between live requests
bytes_min      <- 1e6    # sanity floor: a real chunk is ~22 MB
agente_usuario <- paste(
  "MECA4107-PS1/1.0 (Universidad de los Andes coursework;",
  "R httr2; contact via course staff)"
)

# Fetch one chunk's HTML to disk, with retries and exponential backoff. -------
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

# Parse the embedded <table> into a tibble. -----------------------------------
# Column names are kept verbatim (camelCase included) so they keep matching
# the course data dictionary; janitor::clean_names() would break that.
parsear_chunk_html <- function(ruta, chunk) {
  tabla <- xml2::read_html(ruta) |>
    rvest::html_element("table") |>
    rvest::html_table(header = TRUE, convert = TRUE)

  # tableHTML emits an unnamed leading column holding the row names.
  if (!nzchar(names(tabla)[1]) || is.na(names(tabla)[1])) {
    tabla <- tabla[, -1]
  }

  tabla |> dplyr::mutate(chunk_id = chunk, .before = 1)
}

# Download-or-reuse, parse-or-reuse, one chunk at a time. ---------------------
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

# Report ----------------------------------------------------------------------
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

rm(chunks)
invisible(gc())
