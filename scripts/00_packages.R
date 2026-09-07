# 00_packages.R --------------------------------------------------------------
# Carga (e instala si hace falta) todos los paquetes del proyecto y fija la
# semilla global.
#
# Este archivo es el UNICO lugar donde se declaran dependencias. Cualquier
# paquete nuevo se registra aqui, no con un `library()` suelto a mitad de otro
# script: de lo contrario un clone limpio falla en un `source()` intermedio y
# el pipeline deja de ser reproducible.
#
# POR QUE LA SEMILLA VIVE AQUI
# `set.seed(1234)` se ejecuta al final del archivo, y todos los demas scripts
# empiezan con `source("00_packages.R")`. Asi cualquier cosa aleatoria
# (bootstrap de la Seccion 1 y de la Seccion 2, remuestreos de la Seccion 3)
# arranca del mismo estado sin que cada script tenga que acordarse de fijarla.
# La particion entrenamiento/validacion NO usa la semilla: es determinista,
# viene dada por `chunk_id` (ver `02_cleaning.R`).
# ----------------------------------------------------------------------------

if (!require("pacman")) install.packages("pacman")

pacman::p_load(
  tidyverse,   # manipulacion de datos y ggplot2
  rvest,       # scraping: extraccion de la tabla HTML
  httr2,       # peticiones con reintentos y user agent identificable
  here,        # rutas relativas al proyecto (nada de setwd())
  janitor,     # clean_names(): se carga, pero NO se usa (ver 01_scraping.R)
  digest,      # hash SHA-256 de las reglas de limpieza
  boot,        # bootstrap
  fixest,      # regresiones rapidas con efectos fijos
  modelsummary, # tablas con calidad de publicacion
  skimr,       # descriptivas
  caret,       # utilidades de validacion cruzada
  lmtest,      # Ajuste de modelo Lineal
  sandwich,    # errores robustos
  marginaleffects # efectos marginales y predicciones
  )

set.seed(1234)
