# 02_cleaning.R --------------------------------------------------------------
# Construye la muestra de analisis que usan LAS TRES SECCIONES.
# Es la unica fuente de verdad de cada decision de limpieza: nada se filtra ni
# se deriva dentro de 10_, 20_ o 30_. Si una seccion necesitara otra muestra,
# se agrega aqui como argumento, no alla como filtro suelto.
#
# RESTRICCIONES FIJAS DEL ENUNCIADO
#   ocupados (ocu == 1) y edad >= 18.
#
# DECISIONES DISCRECIONALES, CON SU COSTO Y SU RAZON
# El detalle fila por fila esta en la cascada que se exporta a
# `views/tables/construccion_muestra.tex`; aqui va el porque.
#
#   * EL INGRESO FALTANTE SE EXCLUYE, NUNCA SE IMPUTA. Cuesta 1.778 filas
#     (10,75%). `y_total_m` no registra ceros exactos, solo NA. De esas filas,
#     248 son `relab` 6 y 7 (trabajo familiar y no remunerado): faltan por
#     construccion, no por no respuesta. Las ~1.530 restantes son no respuesta
#     de item, concentrada entre patrones (24,4%) y cuenta propia (14,0%)
#     frente a asalariados (6,3%). Imputarlas exigiria un modelo de ingreso,
#     que es exactamente el objeto de estimacion: usarlo para llenar la
#     variable dependiente seria circular.
#     El costo NO es neutral y se reporta: entre los excluidos los hombres
#     estan sobrerrepresentados (61,0% frente a 52,6% en la muestra), de modo
#     que la Seccion 2 estima la brecha sobre una muestra masculina depurada.
#     La cuantificacion con el ingreso imputado del DANE esta en
#     `document/notas_pulso.md` y va en el deck de la Seccion 2.
#
#   * LA COLA ALTA NO SE TOCA. Cuesta 0 filas, y esa es la decision. Sin
#     top-coding, sin winsorizacion, sin recorte por percentil. El problem set
#     plantea una autoridad tributaria que busca subreporte de ingresos: la
#     cola alta ES la poblacion de interes y borrarla destruiria la pregunta.
#     Es el caso raro en que la practica habitual (recortar el 1% superior)
#     seria justamente el error.
#
#   * NO HAY PISO DE INGRESO EN LA MUESTRA BASE. Cuesta 0 filas. El argumento
#     `piso_ingreso` existe para reestimar como chequeo de robustez, no para
#     usarse por defecto: con `piso_ingreso = 500` la muestra baja a 14.680.
#
#   * HORAS IMPLAUSIBLES: `totalHoursWorked <= 112`. Cuesta 12 filas (0,08%).
#     16 h/dia x 7 dias es un techo fisiologico, no estadistico. En esos casos
#     el ingreso reportado es plausible y el error esta en las horas, que son
#     control en la Seccion 1 y predictor en la Seccion 3.
#
#   * EDUCACION FALTANTE SE EXCLUYE. Cuesta 1 fila (0,01%). Es un control
#     central de las tres secciones y no vale la pena una categoria "NA" por
#     una sola observacion.
#
#   * EL FACTOR DE EXPANSION NO SE APLICA. Cuesta 0 filas. Tres razones: la
#     Seccion 3 se evalua por RMSE no ponderado, la inferencia ponderada
#     valida exige estratos y UPM que este sample no publica, y ponderar
#     cambiaria la poblacion objetivo sin que el enunciado lo pida. `fex_c` y
#     `fweight` se conservan como columnas para que la Seccion 2 pueda
#     reportar la brecha ponderada como robustez, y quedan listadas en
#     `no_predictores` para que nunca entren como regresores.
#
# ORDEN DE LOS FILTROS
# El orden importa para la cascada, no para el resultado: los filtros son
# conjunciones y el N final es el mismo en cualquier orden. Se aplican de mas
# general a mas especifico para que la tabla se lea como un embudo.
# ----------------------------------------------------------------------------

source(here::here("scripts", "00_packages.R"))

dir_crudos     <- here::here("stores", "raw")
dir_procesados <- here::here("stores", "processed")
dir_tablas     <- here::here("views", "tables")

n_chunks             <- 10
chunks_entrenamiento <- 1:7
horas_max            <- 112  # 16 h/dia x 7 dias: techo fisiologico
oficio_n_min         <- 30   # minimo de obs. de entrenamiento por oficio

# Variables que NUNCA pueden entrar a un modelo como predictores.
# `mes` y `chunk_id` codifican el calendario y los chunks estan ordenados por
# mes, de modo que cualquiera de los dos filtra la particion entrenamiento /
# validacion y volveria el RMSE de validacion un numero sin sentido.
# `fex_c` y `fweight` son factores de expansion del diseno muestral: describen
# a cuanta gente representa cada fila, no una caracteristica de esa persona.
# `directorio`, `secuencia_p` y `orden` son identificadores de vivienda, hogar
# y persona; se conservan solo para poder rastrear una fila hasta el dato
# crudo.
no_predictores <- c("chunk_id", "mes", "fex_c", "fweight",
                    "directorio", "secuencia_p", "orden")

# Huella digital de las reglas de limpieza. ----------------------------------
#
# EL PROBLEMA QUE RESUELVE
# `stores/processed/muestra_analisis.rds` SI se versiona (ver el README), y un
# archivo de datos versionado se desincroniza del codigo que lo produjo sin
# hacer ruido: alguien edita un filtro, no vuelve a correr el script, y las
# tres secciones siguen estimando sobre la muestra vieja sin que nada falle.
#
# COMO
# Se digiere con SHA-256 el cuerpo deparseado de `construir_muestra_analisis()`,
# que es donde vive cada filtro y cada variable derivada. El hash se guarda en
# `attr(., "meta")` junto a la muestra. Al cargarla se recalcula y se compara.
#
# QUE CUBRE Y QUE NO (verificado, no supuesto)
#   * `deparse(body())` trabaja sobre el ARBOL de la funcion, no sobre su
#     texto: agregar comentarios o reindentar NO cambia el hash. Es la
#     propiedad que se quiere, porque documentar no deberia invalidar el .rds.
#   * Cambiar un filtro, un umbral escrito dentro del cuerpo o una variable
#     derivada SI cambia el hash.
#   * PUNTO CIEGO: el hash cubre el cuerpo, no los `formals` ni las constantes
#     globales. Editar el default de un argumento, o `horas_max`,
#     `oficio_n_min` o `chunks_entrenamiento` aqui arriba, cambia la muestra
#     SIN cambiar el hash. Ese es el motivo de que `meta` guarde tambien los
#     valores efectivos y de que `imprimir_meta_muestra()` los imprima en cada
#     corrida: contra ese caso, el chequeo es visual y no automatico.
hash_reglas_limpieza <- function() {
  digest::digest(deparse(body(construir_muestra_analisis)), algo = "sha256")
}

#' Imprimir la metadata de una muestra almacenada
#'
#' Se llama en cada corrida, tanto si la muestra se reconstruye como si se
#' reutiliza del disco, para que el log diga siempre sobre que se estimo.
#'
#' @param meta La lista de `attr(muestra, "meta")`: `n`, `generado_en`,
#'   `hash_reglas`, `piso_ingreso`, `oficio_n_min`, `horas_max`, `version_r`.
#' @return `meta`, de forma invisible, para poder encadenar la llamada.
#' @examples
#' # imprimir_meta_muestra(attr(muestra_analisis, "meta"))
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

#' Cargar la muestra almacenada y avisar si quedo desactualizada
#'
#' Es el punto de entrada para trabajar sobre la muestra sin reconstruirla.
#' La advertencia por hash desfasado se emite con `immediate. = TRUE` para que
#' aparezca en el momento y no al final de un script largo.
#'
#' @param ruta Ruta al `.rds`. Por defecto
#'   `stores/processed/muestra_analisis.rds`.
#' @return El tibble de la muestra, con todos sus atributos. Falla con
#'   `stop()` si el archivo no existe, y advierte (sin fallar) si el hash de
#'   las reglas guardado no coincide con el de este script.
#' @examples
#' # muestra <- cargar_muestra_analisis()
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

#' Leer y apilar los 10 chunks crudos
#'
#' `01_scraping.R` ya verifico que los 10 chunks comparten esquema, de modo
#' que el `bind_rows()` no puede rellenar columnas con NA en silencio.
#'
#' @return Un tibble de 32.177 x 178: las 10 particiones apiladas, con
#'   `chunk_id` al frente.
#' @examples
#' # crudo <- leer_chunks_crudos()
leer_chunks_crudos <- function() {
  rutas <- file.path(dir_crudos,
                     sprintf("chunk_%02d.rds", seq_len(n_chunks)))
  if (any(!file.exists(rutas))) {
    stop("Missing raw chunks. Run scripts/01_scraping.R first.")
  }
  dplyr::bind_rows(lapply(rutas, readRDS))
}

#' Construir la muestra de analisis
#'
#' Aplica, en orden, los filtros documentados en el encabezado de este archivo
#' y deriva las variables que usan las tres secciones. Cada filtro queda
#' registrado en la cascada con su N y su costo.
#'
#' @param piso_ingreso `NULL` (default: la muestra base) o un salario horario
#'   en COP. Si es numerico, se excluyen las filas cuyo `y_total_m_ha` cae por
#'   debajo. Es un interruptor de ROBUSTEZ, no parte de la muestra base:
#'   permite reestimar las especificaciones principales con y sin salarios
#'   horarios implausibles. Con `piso_ingreso = 500` la muestra baja a 14.680.
#' @param oficio_n_min Minimo de observaciones DE ENTRENAMIENTO para que un
#'   nivel de `oficio` sobreviva; los mas raros se colapsan en `"otros"`. El
#'   umbral se calcula solo sobre los chunks 1-7 y despues se aplica a los
#'   chunks 8-10, de modo que el fold de validacion nunca informa la
#'   codificacion. Con el default (30) sobreviven 50 niveles, se colapsan 29 y
#'   `"otros"` se queda con el 2,8% de la muestra.
#' @param horas_max Techo de horas semanales. Default 112 = 16 h/dia x 7 dias.
#' @return Un tibble de 14.751 x 27 con los defaults. Lleva cuatro atributos
#'   ademas de `meta`: `cascada` (la tabla de construccion),
#'   `oficio_conservados`, `oficio_colapsados` y `piso_ingreso`.
#' @examples
#' # muestra <- construir_muestra_analisis()
#' # attr(muestra, "cascada")
#' # robustez <- construir_muestra_analisis(piso_ingreso = 500)
construir_muestra_analisis <- function(piso_ingreso = NULL,
                                       oficio_n_min = 30,
                                       horas_max = 112) {
  crudo <- leer_chunks_crudos()

  # La cascada se arma sobre la marcha para que la tabla no pueda
  # desincronizarse de los filtros: cada `registrar()` va inmediatamente
  # despues del `filter()` que describe. Si alguien agrega un filtro y olvida
  # su `registrar()`, los N de la tabla dejan de cuadrar y salta a la vista.
  n_crudo <- nrow(crudo)
  pasos <- list(tibble::tibble(paso = "Datos crudos (10 chunks)",
                               n = n_crudo, excluidas = NA_integer_))
  registrar <- function(etiqueta, datos, n_previo) {
    pasos[[length(pasos) + 1]] <<- tibble::tibble(
      paso = etiqueta, n = nrow(datos), excluidas = n_previo - nrow(datos)
    )
    nrow(datos)
  }

  # Enunciado. Es el filtro caro: la mitad de la GEIH no esta ocupada.
  # -15.495 filas (48,16%).
  m <- crudo |> dplyr::filter(ocu == 1)
  n <- registrar("Ocupados (ocu = 1)", m, n_crudo)

  # Enunciado. Barato porque el filtro de ocupacion ya saco a casi todos los
  # menores de edad. -140 filas (0,84%).
  m <- m |> dplyr::filter(age >= 18)
  n <- registrar("Edad 18 o mas", m, n)

  # Decision del equipo: excluir, nunca imputar. Ver el encabezado.
  # -1.778 filas (10,75%): es el filtro discrecional que mas cuesta y el unico
  # que impone una limitacion que hay que reportar en el deck.
  m <- m |> dplyr::filter(!is.na(y_total_m))
  n <- registrar("Ingreso laboral observado", m, n)

  # Techo fisiologico, no estadistico. El ingreso de esas filas es plausible;
  # lo implausible son las horas. -12 filas (0,08%).
  m <- m |> dplyr::filter(totalHoursWorked <= horas_max)
  n <- registrar(sprintf("Horas semanales hasta %d", horas_max), m, n)

  # Control central de las tres secciones. -1 fila (0,01%): no vale la pena
  # una categoria "sin dato" por una sola observacion.
  m <- m |> dplyr::filter(!is.na(maxEducLevel))
  n <- registrar("Nivel educativo observado", m, n)

  # Solo si se pide explicitamente: NO forma parte de la muestra base.
  if (!is.null(piso_ingreso)) {
    m <- m |> dplyr::filter(y_total_m_ha >= piso_ingreso)
    n <- registrar(sprintf("Salario horario desde %s COP",
                           formatC(piso_ingreso, format = "d",
                                   big.mark = ".", decimal.mark = ",")),
                   m, n)
  }

  # Agrupacion de oficios: el umbral se aprende SOLO en entrenamiento. -------
  # `oficio` llega con 79 niveles a este punto, muchos con un punado de
  # observaciones. Dejarlos sueltos produce dummies casi singulares que se
  # ajustan perfectamente en entrenamiento y no generalizan; ademas rompen
  # el LOOCV (apalancamiento 1).
  # El umbral se calcula sobre los chunks 1-7 y se APLICA a los 8-10: si se
  # calculara sobre la muestra completa, el fold de validacion estaria
  # informando la codificacion y el RMSE de validacion quedaria contaminado.
  # `niveles_oficio` fija el orden de los niveles con "otros" al final, para
  # que la categoria de referencia no cambie entre corridas.
  conteos_oficio <- m |>
    dplyr::filter(chunk_id %in% chunks_entrenamiento) |>
    dplyr::count(oficio)
  oficio_frec <- conteos_oficio$oficio[conteos_oficio$n >= oficio_n_min]
  niveles_oficio <- c(as.character(sort(oficio_frec)), "otros")

  # Variables derivadas. Las que crea el equipo van en espanol y snake_case;
  # las columnas del DANE conservan su nombre original (ver 01_scraping.R).
  salida <- m |>
    dplyr::mutate(
      # El outcome de las tres secciones. En niveles la distribucion es
      # fuertemente asimetrica (asimetria 8,5) y OLS quedaria dominado por la
      # cola alta; en logaritmos es casi simetrica (-0,35). Es seguro tomar
      # logs porque el filtro anterior ya garantizo que no hay ceros ni NA.
      ingreso_log = log(y_total_m),
      # El diccionario codifica sex = 1 hombre, 0 mujer. Se invierte para que
      # el coeficiente de la Seccion 2 se lea directamente como la brecha
      # femenina, sin cambiarle el signo mentalmente al reportarlo.
      mujer       = as.integer(sex == 0),
      # Sin el cuadratico no existe una edad pico que estimar: el perfil
      # edad-ingreso es concavo (ver views/figures/ingreso_por_edad.png).
      edad_2      = age^2,
      # relab 8 (jornalero) tiene UNA sola observacion de entrenamiento: se
      # ajustaria perfectamente y desapareceria bajo LOOCV. Se pliega en el 9
      # ("otro"), que es donde conceptualmente pertenece.
      relab_grupo  = factor(dplyr::if_else(relab %in% c(8, 9), 9L,
                                           as.integer(relab))),
      oficio_grupo = factor(
        dplyr::if_else(oficio %in% oficio_frec, as.character(oficio), "otros"),
        levels = niveles_oficio
      ),
      # Los codigos del DANE se convierten a factor para que R no los trate
      # como numeros: la distancia entre el estrato 1 y el 2 no es la misma
      # que entre el 5 y el 6, y `maxEducLevel` ni siquiera es ordinal en su
      # codificacion (ver el glosario del README).
      educ             = factor(maxEducLevel),
      tamano_empresa   = factor(sizeFirm),
      estrato          = factor(estrato1),
      cot_pension      = factor(cotPension),
      # Estas ya vienen como 0/1 desde el dato: solo se fija el tipo.
      formal           = as.integer(formal),
      college          = as.integer(college),
      cuenta_propia    = as.integer(cuentaPropia),
      micro_empresa    = as.integer(microEmpresa),
      # Renombres de conveniencia: mismo contenido, nombre legible.
      antiguedad_meses = p6426,
      horas            = totalHoursWorked,
      horas_usuales    = hoursWorkUsual,
      # La particion la fija `chunk_id`, no una semilla: es DETERMINISTA y
      # temporal, no aleatoria. Ver `30_prediction.R`.
      particion        = dplyr::if_else(chunk_id %in% chunks_entrenamiento,
                                        "entrenamiento", "validacion")
    ) |>
    # Se conservan 27 columnas de las 178 crudas. Las que no aparecen aqui no
    # se perdieron: siguen en stores/raw/ y se pueden agregar a esta seleccion
    # si alguna seccion las necesita.
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

  # Todo lo que hace falta para auditar la muestra viaja PEGADO a la muestra,
  # no en un archivo aparte que se pueda desincronizar.
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

#' Escribir la cascada como tabla LaTeX independiente
#'
#' Se emite una tabla completa (`\\begin{table}` incluido) y no un fragmento,
#' para que el `.qmd` la incluya con `\\input{}` sin envolverla en nada. Las
#' notas al pie viajan dentro del archivo: la justificacion metodologica tiene
#' que llegar al lector de la tabla, no quedarse en el codigo.
#'
#' @param cascada El tibble de `attr(muestra, "cascada")`: columnas `paso`,
#'   `n`, `excluidas`, `pct_previo`, `pct_crudo`.
#' @param ruta Archivo `.tex` de destino; se sobrescribe.
#' @return `NULL`, de forma invisible. Se llama por su efecto en disco.
#' @examples
#' # escribir_cascada_tex(attr(muestra_analisis, "cascada"),
#' #                      file.path(dir_tablas, "construccion_muestra.tex"))
escribir_cascada_tex <- function(cascada, ruta) {
  bs  <- "\\"
  # Convencion en espanol: "." agrupa miles y "," es el separador decimal.
  # Declarar ambos explicitamente ademas silencia el warning de ambiguedad de
  # formatC cuando solo se fija uno de los dos.
  fmt <- function(x) {
    formatC(x, format = "d", big.mark = ".", decimal.mark = ",")
  }
  eol <- paste0(bs, bs)

  # La primera fila (datos crudos) no tiene paso previo, asi que sus dos
  # columnas de porcentaje van con "---" en lugar de un NA impreso.
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

# Ejecucion -------------------------------------------------------------------
dir.create(dir_procesados, recursive = TRUE, showWarnings = FALSE)
dir.create(dir_tablas, recursive = TRUE, showWarnings = FALSE)

ruta_muestra <- file.path(dir_procesados, "muestra_analisis.rds")

# Se reutiliza la muestra almacenada mientras las reglas no cambien, y se
# reconstruye (diciendolo en el log) en cuanto se edita cualquier regla dentro
# de `construir_muestra_analisis()`. Esto es lo que hace que `03_`, `10_`,
# `20_` y `30_` puedan hacer `source()` de este archivo sin pagar la
# reconstruccion cada vez, que es lo que baja la corrida completa a ~20 s.
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

# Se escribe en CADA corrida, no solo cuando se reconstruye: la tabla es una
# salida del pipeline y tiene que reaparecer desde un clone limpio aunque la
# muestra se haya reutilizado del disco.
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
