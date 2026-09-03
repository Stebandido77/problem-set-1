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

base_url <- "https://ignaciomsarmiento.github.io/GEIH2018_sample"
raw_dir  <- here::here("stores", "raw")
html_dir <- file.path(raw_dir, "html")

dir.create(html_dir, recursive = TRUE, showWarnings = FALSE)

n_chunks     <- 10
polite_pause <- 1.5      # seconds between live requests
min_bytes    <- 1e6      # sanity floor: a real chunk is ~22 MB
user_agent   <- paste(
  "MECA4107-PS1/1.0 (Universidad de los Andes coursework;",
  "R httr2; contact via course staff)"
)

# Fetch one chunk's HTML to disk, with retries and exponential backoff. -------
fetch_chunk_html <- function(chunk, dest) {
  url <- sprintf("%s/pages/geih_page_%d.html", base_url, chunk)

  httr2::request(url) |>
    httr2::req_user_agent(user_agent) |>
    httr2::req_timeout(900) |>
    httr2::req_retry(max_tries = 4, backoff = \(tries) 2^tries) |>
    httr2::req_perform(path = dest)

  if (file.size(dest) < min_bytes) {
    unlink(dest)
    stop("Chunk ", chunk, " came back too small; deleted partial download.")
  }

  invisible(dest)
}

# Parse the embedded <table> into a tibble. -----------------------------------
# Column names are kept verbatim (camelCase included) so they keep matching
# the course data dictionary; janitor::clean_names() would break that.
parse_chunk_html <- function(path, chunk) {
  tbl <- xml2::read_html(path) |>
    rvest::html_element("table") |>
    rvest::html_table(header = TRUE, convert = TRUE)

  # tableHTML emits an unnamed leading column holding the row names.
  if (!nzchar(names(tbl)[1]) || is.na(names(tbl)[1])) {
    tbl <- tbl[, -1]
  }

  tbl |> dplyr::mutate(chunk_id = chunk, .before = 1)
}

# Download-or-reuse, parse-or-reuse, one chunk at a time. ---------------------
scrape_chunk <- function(chunk) {
  rds_path  <- file.path(raw_dir, sprintf("chunk_%02d.rds", chunk))
  html_path <- file.path(html_dir, sprintf("geih_page_%d.html", chunk))

  if (file.exists(rds_path)) {
    message("chunk ", chunk, ": cached .rds, skipping.")
    return(readRDS(rds_path))
  }

  if (file.exists(html_path) && file.size(html_path) >= min_bytes) {
    message("chunk ", chunk, ": cached html, parsing (no request).")
  } else {
    message("chunk ", chunk, ": downloading ...")
    fetch_chunk_html(chunk, html_path)
    Sys.sleep(polite_pause)
  }

  out <- parse_chunk_html(html_path, chunk)
  saveRDS(out, rds_path)
  message("chunk ", chunk, ": saved ", nrow(out), " x ", ncol(out), ".")
  out
}

chunks <- lapply(seq_len(n_chunks), scrape_chunk)

# Report ----------------------------------------------------------------------
sizes <- vapply(chunks, nrow, integer(1))
names_by_chunk <- lapply(chunks, names)
same_schema <- all(vapply(
  names_by_chunk, identical, logical(1), names_by_chunk[[1]]
))

message("\n--- scraping report ---")
print(tibble::tibble(
  chunk = seq_len(n_chunks),
  rows  = sizes,
  cols  = vapply(chunks, ncol, integer(1))
))
message("total rows: ", sum(sizes))
message("identical column schema across the 10 chunks: ", same_schema)

if (!same_schema) {
  ref <- names_by_chunk[[1]]
  for (i in seq_len(n_chunks)) {
    d <- c(setdiff(names_by_chunk[[i]], ref), setdiff(ref, names_by_chunk[[i]]))
    if (length(d)) {
      message("chunk ", i, " deviates: ", paste(d, collapse = ", "))
    }
  }
}

rm(chunks)
invisible(gc())
