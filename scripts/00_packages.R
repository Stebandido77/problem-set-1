# 00_packages.R --------------------------------------------------------------
# Loads (and installs if needed) every package used in the project.
# ----------------------------------------------------------------------------

if (!require("pacman")) install.packages("pacman")

pacman::p_load(
  tidyverse,   # data wrangling and ggplot2
  rvest,       # web scraping
  httr2,       # polite requests
  here,        # project-relative paths
  janitor,     # clean_names()
  digest,      # hash of the cleaning rules stored with the sample
  boot,        # bootstrap
  fixest,      # fast regressions
  modelsummary, # publication-quality tables
  skimr,       # descriptives
  caret        # validation / CV helpers
)

set.seed(1234)
