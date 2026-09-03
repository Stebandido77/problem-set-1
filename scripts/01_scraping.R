# 01_scraping.R --------------------------------------------------------------
# Scrapes the 10 GEIH 2018 chunks and stores them in stores/raw/.
# Be polite: cache locally and do not re-download if the file already exists.
# ----------------------------------------------------------------------------

source(here::here("scripts", "00_packages.R"))

base_url <- "https://ignaciomsarmiento.github.io/GEIH2018_sample/"
raw_dir  <- here::here("stores", "raw")

# TODO: loop over pages 1:10, parse the html table, write one .rds per chunk.
# Keep the chunk id as a column: it defines the train/validation split later.
