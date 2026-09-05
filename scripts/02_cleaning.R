# 02_cleaning.R --------------------------------------------------------------
# Builds the analysis sample used across ALL three sections.
# Single source of truth for every cleaning decision.
#
# Fixed restrictions from the problem set: employed (ocu == 1) and age >= 18.
#
# Discretionary decisions, with the evidence behind each one:
#   * Missing labour income is EXCLUDED, never imputed. y_total_m has no exact
#     zeros, only NA. 248 of the dropped rows are relab 6/7 (unpaid family
#     and
#     unpaid non-household workers), missing by construction. The remaining
#     ~1,530 are item non-response, concentrated among employers (24.4%) and
#     own-account workers (14.0%) versus salaried employees (6.3%). Imputing
#     would require an income model, which is the object of estimation.
#   * The UPPER TAIL IS NEVER TOUCHED: no top-coding, no winsorising, no
#     percentile trim. The problem set frames a tax authority detecting income
#     under-reporting, so the high tail is the population of interest and
#     deleting it would destroy the question being asked.
#   * No income floor in the base sample. `piso_ingreso` exists so the main
#     specifications can be re-run as a robustness check (see the argument).
#   * Survey weights are NOT applied. fex_c is kept as a column so Section 2
#     can report a weighted gender gap as robustness.
# ----------------------------------------------------------------------------

source(here::here("scripts", "00_packages.R"))

dir_crudos     <- here::here("stores", "raw")
dir_procesados <- here::here("stores", "processed")
dir_tablas     <- here::here("views", "tables")

n_chunks             <- 10
chunks_entrenamiento <- 1:7
horas_max            <- 112  # 16 h/day x 7 days: physiological ceiling
oficio_n_min         <- 30   # min. training count for an occupation

# Variables that must NEVER enter a model as predictors. `mes` and `chunk_id`
# encode the calendar, and the chunks are ordered by month, so either one
# would leak the train/validation split. fex_c/fweight are design weights.
no_predictores <- c("chunk_id", "mes", "fex_c", "fweight",
                    "directorio", "secuencia_p", "orden")

# Fingerprint of the cleaning rules. -----------------------------------------
# Digests the deparsed body of construir_muestra_analisis(), where every
# filter and derived variable lives. Any edit to a rule changes the hash, so a
# stored sample built under the old rules can be detected on load.
hash_reglas_limpieza <- function() {
  digest::digest(deparse(body(construir_muestra_analisis)), algo = "sha256")
}

imprimir_meta_muestra <- function(meta) {
  message("--- analysis sample metadata ---")
  message("  N observations : ", meta$n)
  message("  generated at   : ", format(meta$generado_en, "%Y-%m-%d %H:%M:%S"))
  message("  cleaning rules : ", substr(meta$hash_reglas, 1, 16), "...")
  message("  piso_ingreso   : ",
          if (is.null(meta$piso_ingreso)) "NULL (base sample)"
          else meta$piso_ingreso)
  message("  oficio_n_min   : ", meta$oficio_n_min,
          " | horas_max: ", meta$horas_max)
  invisible(meta)
}

# Read the stored sample, print its metadata and warn when the rules that
# produced it no longer match the current 02_cleaning.R.
cargar_muestra_analisis <- function(
    ruta = file.path(dir_procesados, "muestra_analisis.rds")) {
  if (!file.exists(ruta)) {
    stop("No stored analysis sample. Run scripts/02_cleaning.R first.")
  }
  salida  <- readRDS(ruta)
  meta <- attr(salida, "meta")
  imprimir_meta_muestra(meta)

  if (!identical(meta$hash_reglas, hash_reglas_limpieza())) {
    warning(
      "muestra_analisis.rds was built with DIFFERENT cleaning rules than the ",
      "current scripts/02_cleaning.R. Re-run 02_cleaning.R and commit the ",
      "regenerated .rds together with the script.",
      call. = FALSE, immediate. = TRUE
    )
  }
  salida
}

leer_chunks_crudos <- function() {
  rutas <- file.path(dir_crudos,
                     sprintf("chunk_%02d.rds", seq_len(n_chunks)))
  if (any(!file.exists(rutas))) {
    stop("Missing raw chunks. Run scripts/01_scraping.R first.")
  }
  dplyr::bind_rows(lapply(rutas, readRDS))
}

# Build the analysis sample. -------------------------------------------------
#
# @param piso_ingreso NULL (default, the base sample) or a numeric hourly wage
#   in COP. When numeric, rows whose y_total_m_ha falls below it are
#   dropped.
#   This is a ROBUSTNESS switch, not part of the base sample: it lets the main
#   specifications be re-estimated with and without implausibly low wages.
# @param oficio_n_min Minimum number of TRAINING observations for an `oficio`
#   level to survive; rarer levels collapse into "otros". The threshold is
#   computed on chunks 1-7 only and then applied to 8-10, so the validation
#   fold never informs the encoding.
# @return A tibble, with the construction waterfall in attr(., "cascada").
construir_muestra_analisis <- function(piso_ingreso = NULL,
                                       oficio_n_min = 30,
                                       horas_max = 112) {
  crudo <- leer_chunks_crudos()

  n_crudo <- nrow(crudo)
  pasos <- list(tibble::tibble(paso = "Datos crudos (10 chunks)",
                               n = n_crudo, excluidas = NA_integer_))
  registrar <- function(etiqueta, datos, n_previo) {
    pasos[[length(pasos) + 1]] <<- tibble::tibble(
      paso = etiqueta, n = nrow(datos), excluidas = n_previo - nrow(datos)
    )
    nrow(datos)
  }

  m <- crudo |> dplyr::filter(ocu == 1)
  n <- registrar("Ocupados (ocu = 1)", m, n_crudo)

  m <- m |> dplyr::filter(age >= 18)
  n <- registrar("Edad 18 o mas", m, n)

  m <- m |> dplyr::filter(!is.na(y_total_m))
  n <- registrar("Ingreso laboral observado", m, n)

  m <- m |> dplyr::filter(totalHoursWorked <= horas_max)
  n <- registrar(sprintf("Horas semanales hasta %d", horas_max), m, n)

  m <- m |> dplyr::filter(!is.na(maxEducLevel))
  n <- registrar("Nivel educativo observado", m, n)

  if (!is.null(piso_ingreso)) {
    m <- m |> dplyr::filter(y_total_m_ha >= piso_ingreso)
    n <- registrar(sprintf("Salario horario desde %s COP",
                           formatC(piso_ingreso, format = "d",
                                   big.mark = ".", decimal.mark = ",")),
                   m, n)
  }

  # Occupation grouping: threshold learned on the training chunks only. -------
  conteos_oficio <- m |>
    dplyr::filter(chunk_id %in% chunks_entrenamiento) |>
    dplyr::count(oficio)
  oficio_frec <- conteos_oficio$oficio[conteos_oficio$n >= oficio_n_min]
  niveles_oficio <- c(as.character(sort(oficio_frec)), "otros")

  salida <- m |>
    dplyr::mutate(
      ingreso_log = log(y_total_m),
      mujer       = as.integer(sex == 0),  # dictionary: sex 1 = male
      edad_2      = age^2,
      # relab 8 (jornalero) has a single training observation: it would be
      # fitted perfectly and would vanish under LOOCV. Fold it into "otro".
      relab_grupo  = factor(dplyr::if_else(relab %in% c(8, 9), 9L,
                                           as.integer(relab))),
      oficio_grupo = factor(
        dplyr::if_else(oficio %in% oficio_frec, as.character(oficio), "otros"),
        levels = niveles_oficio
      ),
      educ             = factor(maxEducLevel),
      tamano_empresa   = factor(sizeFirm),
      estrato          = factor(estrato1),
      cot_pension      = factor(cotPension),
      formal           = as.integer(formal),
      college          = as.integer(college),
      cuenta_propia    = as.integer(cuentaPropia),
      micro_empresa    = as.integer(microEmpresa),
      antiguedad_meses = p6426,
      horas            = totalHoursWorked,
      horas_usuales    = hoursWorkUsual,
      particion        = dplyr::if_else(chunk_id %in% chunks_entrenamiento,
                                        "entrenamiento", "validacion")
    ) |>
    dplyr::select(
      chunk_id, particion, mes, directorio, secuencia_p, orden,
      y_total_m, y_total_m_ha, ingreso_log,
      mujer, age, edad_2,
      educ, college, relab_grupo, oficio_grupo, tamano_empresa, estrato,
      formal, cot_pension, cuenta_propia, micro_empresa,
      horas, horas_usuales, antiguedad_meses,
      fex_c, fweight
    )

  cascada <- dplyr::bind_rows(pasos) |>
    dplyr::mutate(
      pct_previo = round(100 * excluidas / dplyr::lag(n), 2),
      pct_crudo  = round(100 * n / n_crudo, 2)
    )

  attr(salida, "cascada")            <- cascada
  attr(salida, "oficio_colapsados")  <- setdiff(sort(unique(m$oficio)),
                                                oficio_frec)
  attr(salida, "oficio_conservados") <- sort(oficio_frec)
  attr(salida, "piso_ingreso")       <- piso_ingreso
  attr(salida, "meta") <- list(
    n            = nrow(salida),
    generado_en  = Sys.time(),
    hash_reglas  = hash_reglas_limpieza(),
    piso_ingreso = piso_ingreso,
    oficio_n_min = oficio_n_min,
    horas_max    = horas_max,
    version_r    = paste(R.version$major, R.version$minor, sep = ".")
  )
  salida
}

# Render the waterfall as a standalone LaTeX table. -------------------------
escribir_cascada_tex <- function(cascada, ruta) {
  bs  <- "\\"
  # Spanish convention: "." groups thousands, "," is the decimal separator.
  # Setting both explicitly also silences formatC's ambiguity warning.
  fmt <- function(x) {
    formatC(x, format = "d", big.mark = ".", decimal.mark = ",")
  }
  eol <- paste0(bs, bs)

  cuerpo <- vapply(seq_len(nrow(cascada)), function(i) {
    r <- cascada[i, ]
    if (is.na(r$excluidas)) {
      sprintf("%s & %s & --- & --- & %.2f %s", r$paso, fmt(r$n),
              r$pct_crudo, eol)
    } else {
      sprintf("%s & %s & %s & %.2f & %.2f %s", r$paso, fmt(r$n),
              fmt(r$excluidas), r$pct_previo, r$pct_crudo, eol)
    }
  }, character(1))

  notas <- paste(
    "Notas: GEIH 2018, Bogota. Los ingresos laborales no se recortan por",
    "arriba: no hay top-coding, winsorizacion ni recorte por percentil. El",
    "ejercicio del problem set es la deteccion de subreporte de ingresos por",
    "parte de una autoridad tributaria, de modo que la cola alta es la",
    "poblacion de interes y eliminarla sesgaria justamente el objeto de",
    "estudio. Tampoco se aplica un piso de ingreso en la muestra base; el",
    "argumento piso_ingreso permite reestimar las especificaciones",
    "principales excluyendo salarios horarios implausibles como chequeo de",
    "robustez. La ausencia de ingreso se excluye y nunca se imputa:",
    "y_total_m no registra ceros exactos, solo valores faltantes. No se",
    "aplica el factor de expansion fex_c, que se conserva como columna para",
    "los chequeos ponderados."
  )

  tex <- c(
    paste0(bs, "begin{table}[htbp]"),
    paste0(bs, "centering"),
    paste0(bs, "caption{Construccion de la muestra de analisis}"),
    paste0(bs, "label{tab:construccion-muestra}"),
    paste0(bs, "begin{tabular}{lrrrr}"),
    paste0(bs, "toprule"),
    paste0("Filtro & $N$ & Excluidas & \\% del paso previo & ",
           "\\% del crudo ", eol),
    paste0(bs, "midrule"),
    cuerpo,
    paste0(bs, "bottomrule"),
    paste0(bs, "end{tabular}"),
    paste0(bs, "begin{minipage}{0.95", bs, "textwidth}"),
    paste0(bs, "footnotesize"),
    paste0(bs, "textit{", notas, "}"),
    paste0(bs, "end{minipage}"),
    paste0(bs, "end{table}")
  )
  writeLines(tex, ruta)
}

# Run -------------------------------------------------------------------------
dir.create(dir_procesados, recursive = TRUE, showWarnings = FALSE)
dir.create(dir_tablas, recursive = TRUE, showWarnings = FALSE)

ruta_muestra <- file.path(dir_procesados, "muestra_analisis.rds")

# Reuse the stored sample when the cleaning rules are unchanged; rebuild (and
# say so) the moment any rule in construir_muestra_analisis() is edited.
muestra_analisis <- NULL
if (file.exists(ruta_muestra)) {
  en_cache <- readRDS(ruta_muestra)
  if (identical(attr(en_cache, "meta")$hash_reglas, hash_reglas_limpieza())) {
    message("cleaning rules unchanged: reusing the stored analysis sample.")
    imprimir_meta_muestra(attr(en_cache, "meta"))
    muestra_analisis <- en_cache
  } else {
    message("cleaning rules CHANGED since the stored sample: rebuilding.")
  }
  rm(en_cache)
}

if (is.null(muestra_analisis)) {
  muestra_analisis <- construir_muestra_analisis(
    piso_ingreso = NULL,
    oficio_n_min = oficio_n_min,
    horas_max    = horas_max
  )
  saveRDS(muestra_analisis, ruta_muestra)
  imprimir_meta_muestra(attr(muestra_analisis, "meta"))
}

# Written on every run, not only on a rebuild: the table is a pipeline output
# and must reappear from a clean clone even when the stored sample is reused.
escribir_cascada_tex(attr(muestra_analisis, "cascada"),
                     file.path(dir_tablas, "construccion_muestra.tex"))

message("\n--- sample construction waterfall ---")
print(as.data.frame(attr(muestra_analisis, "cascada")))

message("\n--- oficio grouping (threshold on chunks 1-7 only) ---")
message("levels kept: ", length(attr(muestra_analisis, "oficio_conservados")),
        " | collapsed into 'otros': ",
        length(attr(muestra_analisis, "oficio_colapsados")))
message("share of sample in 'otros': ",
        round(100 * mean(muestra_analisis$oficio_grupo == "otros"), 2), "%")

message("\n--- final N by chunk ---")
print(muestra_analisis |> dplyr::count(particion, chunk_id) |> as.data.frame())

message("muestra_analisis.rds written: ", nrow(muestra_analisis), " x ",
        ncol(muestra_analisis))
