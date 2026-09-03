# 02_cleaning.R --------------------------------------------------------------
# Builds the analysis sample used across ALL three sections.
# Single source of truth for every cleaning decision.
#
# Fixed restrictions from the problem set: employed (ocu == 1) and age >= 18.
#
# Discretionary decisions, with the evidence behind each one:
#   * Missing labour income is EXCLUDED, never imputed. y_total_m has no exact
#     zeros, only NA. 248 of the dropped rows are relab 6/7 (unpaid family and
#     unpaid non-household workers), missing by construction. The remaining
#     ~1,530 are item non-response, concentrated among employers (24.4%) and
#     own-account workers (14.0%) versus salaried employees (6.3%). Imputing
#     would require an income model, which is the object of estimation.
#   * The UPPER TAIL IS NEVER TOUCHED: no top-coding, no winsorising, no
#     percentile trim. The problem set frames a tax authority detecting income
#     under-reporting, so the high tail is the population of interest and
#     deleting it would destroy the question being asked.
#   * No income floor in the base sample. `income_floor` exists so the main
#     specifications can be re-run as a robustness check (see the argument).
#   * Survey weights are NOT applied. fex_c is kept as a column so Section 2
#     can report a weighted gender gap as robustness.
# ----------------------------------------------------------------------------

source(here::here("scripts", "00_packages.R"))

raw_dir       <- here::here("stores", "raw")
processed_dir <- here::here("stores", "processed")
tables_dir    <- here::here("views", "tables")

n_chunks     <- 10
train_chunks <- 1:7
hours_max    <- 112   # 16 h/day x 7 days: physiological ceiling
oficio_min_n <- 30    # min. training count for an occupation to survive

# Variables that must NEVER enter a model as predictors. `mes` and `chunk_id`
# encode the calendar, and the chunks are ordered by month, so either one
# would leak the train/validation split. fex_c/fweight are design weights.
non_predictors <- c("chunk_id", "mes", "fex_c", "fweight",
                    "directorio", "secuencia_p", "orden")

# Fingerprint of the cleaning rules. -----------------------------------------
# Digests the deparsed body of build_analysis_sample(), which is where every
# filter and derived variable lives. Any edit to a rule changes the hash, so a
# stored sample built under the old rules can be detected on load.
cleaning_rules_hash <- function() {
  digest::digest(deparse(body(build_analysis_sample)), algo = "sha256")
}

print_sample_meta <- function(meta) {
  message("--- analysis sample metadata ---")
  message("  N observations : ", meta$n)
  message("  generated at   : ", format(meta$generated_at, "%Y-%m-%d %H:%M:%S"))
  message("  cleaning rules : ", substr(meta$rules_hash, 1, 16), "...")
  message("  income_floor   : ",
          if (is.null(meta$income_floor)) "NULL (base sample)"
          else meta$income_floor)
  message("  oficio_min_n   : ", meta$oficio_min_n,
          " | hours_max: ", meta$hours_max)
  invisible(meta)
}

# Read the stored sample, print its metadata and warn when the rules that
# produced it no longer match the current 02_cleaning.R.
load_analysis_sample <- function(
    path = file.path(processed_dir, "analysis_sample.rds")) {
  if (!file.exists(path)) {
    stop("No stored analysis sample. Run scripts/02_cleaning.R first.")
  }
  out  <- readRDS(path)
  meta <- attr(out, "meta")
  print_sample_meta(meta)

  if (!identical(meta$rules_hash, cleaning_rules_hash())) {
    warning(
      "analysis_sample.rds was built with DIFFERENT cleaning rules than the ",
      "current scripts/02_cleaning.R. Re-run 02_cleaning.R and commit the ",
      "regenerated .rds together with the script.",
      call. = FALSE, immediate. = TRUE
    )
  }
  out
}

read_raw_chunks <- function() {
  paths <- file.path(raw_dir, sprintf("chunk_%02d.rds", seq_len(n_chunks)))
  if (any(!file.exists(paths))) {
    stop("Missing raw chunks. Run scripts/01_scraping.R first.")
  }
  dplyr::bind_rows(lapply(paths, readRDS))
}

# Build the analysis sample. -------------------------------------------------
#
# @param income_floor NULL (default, the base sample) or a numeric hourly wage
#   in COP. When numeric, rows whose y_total_m_ha falls below it are dropped.
#   This is a ROBUSTNESS switch, not part of the base sample: it lets the main
#   specifications be re-estimated with and without implausibly low wages.
# @param oficio_min_n Minimum number of TRAINING observations for an `oficio`
#   level to survive; rarer levels collapse into "otros". The threshold is
#   computed on chunks 1-7 only and then applied to 8-10, so the validation
#   fold never informs the encoding.
# @return A tibble, with the construction waterfall in attr(., "waterfall").
build_analysis_sample <- function(income_floor = NULL,
                                  oficio_min_n = 30,
                                  hours_max = 112) {
  raw <- read_raw_chunks()

  n_raw <- nrow(raw)
  steps <- list(tibble::tibble(step = "Datos crudos (10 chunks)",
                               n = n_raw, dropped = NA_integer_))
  track <- function(label, data, prev_n) {
    steps[[length(steps) + 1]] <<- tibble::tibble(
      step = label, n = nrow(data), dropped = prev_n - nrow(data)
    )
    nrow(data)
  }

  s <- raw |> dplyr::filter(ocu == 1)
  n <- track("Ocupados (ocu = 1)", s, n_raw)

  s <- s |> dplyr::filter(age >= 18)
  n <- track("Edad 18 o mas", s, n)

  s <- s |> dplyr::filter(!is.na(y_total_m))
  n <- track("Ingreso laboral observado", s, n)

  s <- s |> dplyr::filter(totalHoursWorked <= hours_max)
  n <- track(sprintf("Horas semanales hasta %d", hours_max), s, n)

  s <- s |> dplyr::filter(!is.na(maxEducLevel))
  n <- track("Nivel educativo observado", s, n)

  if (!is.null(income_floor)) {
    s <- s |> dplyr::filter(y_total_m_ha >= income_floor)
    n <- track(sprintf("Salario horario desde %s COP",
                       formatC(income_floor, format = "d", big.mark = ".",
                               decimal.mark = ",")), s, n)
  }

  # Occupation grouping: threshold learned on the training chunks only. -------
  train_counts <- s |>
    dplyr::filter(chunk_id %in% train_chunks) |>
    dplyr::count(oficio)
  keep_oficio <- train_counts$oficio[train_counts$n >= oficio_min_n]
  oficio_levels <- c(as.character(sort(keep_oficio)), "otros")

  out <- s |>
    dplyr::mutate(
      log_income = log(y_total_m),
      female     = as.integer(sex == 0),  # dictionary: sex = 1 male, 0 female
      age_sq     = age^2,
      # relab 8 (jornalero) has a single training observation: it would be
      # fitted perfectly and would vanish under LOOCV. Fold it into "otro".
      relab_grp  = factor(dplyr::if_else(relab %in% c(8, 9), 9L,
                                         as.integer(relab))),
      oficio_grp = factor(
        dplyr::if_else(oficio %in% keep_oficio, as.character(oficio), "otros"),
        levels = oficio_levels
      ),
      educ          = factor(maxEducLevel),
      size_firm     = factor(sizeFirm),
      estrato       = factor(estrato1),
      cot_pension   = factor(cotPension),
      formal        = as.integer(formal),
      college       = as.integer(college),
      cuenta_propia = as.integer(cuentaPropia),
      micro_empresa = as.integer(microEmpresa),
      tenure_months = p6426,
      hours         = totalHoursWorked,
      hours_usual   = hoursWorkUsual,
      split         = dplyr::if_else(chunk_id %in% train_chunks,
                                     "train", "validation")
    ) |>
    dplyr::select(
      chunk_id, split, mes, directorio, secuencia_p, orden,
      y_total_m, y_total_m_ha, log_income,
      female, age, age_sq,
      educ, college, relab_grp, oficio_grp, size_firm, estrato,
      formal, cot_pension, cuenta_propia, micro_empresa,
      hours, hours_usual, tenure_months,
      fex_c, fweight
    )

  waterfall <- dplyr::bind_rows(steps) |>
    dplyr::mutate(
      pct_prev = round(100 * dropped / dplyr::lag(n), 2),
      pct_raw  = round(100 * n / n_raw, 2)
    )

  attr(out, "waterfall")      <- waterfall
  attr(out, "oficio_dropped") <- setdiff(sort(unique(s$oficio)), keep_oficio)
  attr(out, "oficio_kept")    <- sort(keep_oficio)
  attr(out, "income_floor")   <- income_floor
  attr(out, "meta") <- list(
    n            = nrow(out),
    generated_at = Sys.time(),
    rules_hash   = cleaning_rules_hash(),
    income_floor = income_floor,
    oficio_min_n = oficio_min_n,
    hours_max    = hours_max,
    r_version    = paste(R.version$major, R.version$minor, sep = ".")
  )
  out
}

# Render the waterfall as a standalone LaTeX table. ---------------------------
write_waterfall_tex <- function(waterfall, path) {
  bs  <- "\\"
  # Spanish convention: "." groups thousands, "," is the decimal separator.
  # Setting both explicitly also silences formatC's ambiguity warning.
  fmt <- function(x) {
    formatC(x, format = "d", big.mark = ".", decimal.mark = ",")
  }
  eol <- paste0(bs, bs)

  body <- vapply(seq_len(nrow(waterfall)), function(i) {
    r <- waterfall[i, ]
    if (is.na(r$dropped)) {
      sprintf("%s & %s & --- & --- & %.2f %s", r$step, fmt(r$n),
              r$pct_raw, eol)
    } else {
      sprintf("%s & %s & %s & %.2f & %.2f %s", r$step, fmt(r$n),
              fmt(r$dropped), r$pct_prev, r$pct_raw, eol)
    }
  }, character(1))

  notes <- paste(
    "Notas: GEIH 2018, Bogota. Los ingresos laborales no se recortan por",
    "arriba: no hay top-coding, winsorizacion ni recorte por percentil. El",
    "ejercicio del problem set es la deteccion de subreporte de ingresos por",
    "parte de una autoridad tributaria, de modo que la cola alta es la",
    "poblacion de interes y eliminarla sesgaria justamente el objeto de",
    "estudio. Tampoco se aplica un piso de ingreso en la muestra base; el",
    "argumento income_floor permite reestimar las especificaciones",
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
    paste0(bs, "label{tab:sample-construction}"),
    paste0(bs, "begin{tabular}{lrrrr}"),
    paste0(bs, "toprule"),
    paste0("Filtro & $N$ & Excluidas & \\% del paso previo & ",
           "\\% del crudo ", eol),
    paste0(bs, "midrule"),
    body,
    paste0(bs, "bottomrule"),
    paste0(bs, "end{tabular}"),
    paste0(bs, "begin{minipage}{0.95", bs, "textwidth}"),
    paste0(bs, "footnotesize"),
    paste0(bs, "textit{", notes, "}"),
    paste0(bs, "end{minipage}"),
    paste0(bs, "end{table}")
  )
  writeLines(tex, path)
}

# Run -------------------------------------------------------------------------
dir.create(processed_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(tables_dir, recursive = TRUE, showWarnings = FALSE)

sample_path <- file.path(processed_dir, "analysis_sample.rds")

# Reuse the stored sample when the cleaning rules are unchanged; rebuild (and
# say so) the moment any rule in build_analysis_sample() is edited.
analysis_sample <- NULL
if (file.exists(sample_path)) {
  cached <- readRDS(sample_path)
  if (identical(attr(cached, "meta")$rules_hash, cleaning_rules_hash())) {
    message("cleaning rules unchanged: reusing the stored analysis sample.")
    print_sample_meta(attr(cached, "meta"))
    analysis_sample <- cached
  } else {
    message("cleaning rules CHANGED since the stored sample: rebuilding.")
  }
  rm(cached)
}

if (is.null(analysis_sample)) {
  analysis_sample <- build_analysis_sample(
    income_floor = NULL,
    oficio_min_n = oficio_min_n,
    hours_max    = hours_max
  )
  saveRDS(analysis_sample, sample_path)
  write_waterfall_tex(attr(analysis_sample, "waterfall"),
                      file.path(tables_dir, "sample_construction.tex"))
  print_sample_meta(attr(analysis_sample, "meta"))
}

message("\n--- sample construction waterfall ---")
print(as.data.frame(attr(analysis_sample, "waterfall")))

message("\n--- oficio grouping (threshold on chunks 1-7 only) ---")
message("levels kept: ", length(attr(analysis_sample, "oficio_kept")),
        " | collapsed into 'otros': ",
        length(attr(analysis_sample, "oficio_dropped")))
message("share of sample in 'otros': ",
        round(100 * mean(analysis_sample$oficio_grp == "otros"), 2), "%")

message("\n--- final N by chunk ---")
print(analysis_sample |> dplyr::count(split, chunk_id) |> as.data.frame())

message("analysis_sample.rds written: ", nrow(analysis_sample), " x ",
        ncol(analysis_sample))
