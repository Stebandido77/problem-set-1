# 99_run_all.R ---------------------------------------------------------------
# Pipeline completo de reproduccion. Corre de punta a punta desde un clone
# limpio con `Rscript scripts/99_run_all.R`.
#
# ORDEN Y DEPENDENCIAS
#   00_packages     dependencias + semilla global
#   01_scraping     descarga y parsea los 10 chunks -> stores/raw/
#   02_cleaning     construye la muestra de analisis -> stores/processed/
#   03_descriptives figuras que motivan las especificaciones -> views/figures/
#   10 / 20 / 30    las tres secciones del problem set
#
# Cada script vuelve a hacer `source()` de lo que necesita, de modo que
# tambien corre por separado. Eso implica que `02_cleaning.R` se evalua varias
# veces en una corrida completa: es barato porque reutiliza el `.rds`
# almacenado mientras el hash de las reglas no cambie.
#
# TIEMPOS MEDIDOS
# Primera corrida con `stores/raw/` vacio: 1 min 59 s (incluye ~227 MB de
# descarga). Corridas siguientes: unos 20 s, sin ninguna peticion de red.
# ----------------------------------------------------------------------------

source(here::here("scripts", "00_packages.R"))
source(here::here("scripts", "01_scraping.R"))
source(here::here("scripts", "02_cleaning.R"))
source(here::here("scripts", "03_descriptives.R"))
source(here::here("scripts", "10_age_profile.R"))
source(here::here("scripts", "20_gender_gap.R"))
source(here::here("scripts", "30_prediction.R"))

message("Pipeline finished. Check views/tables and views/figures.")
