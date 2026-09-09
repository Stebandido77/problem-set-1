# 20_gender_gap.R ------------------------------------------------------------
# Seccion 2: brecha de ingreso laboral por genero.
#
#   (1) Incondicional: log(w) = b1 + b2*mujer + u
#   (2) Condicional:   controles de trabajador y de puesto (cada uno hay que
#       justificarlo, y hay que senalar cuales son bad controls)
#   (3) Descomposicion FWL + errores estandar analiticos y bootstrap
#   (4) Perfiles edad-ingreso predichos por sexo, con edad pico e IC
#
# EL PUNTO DE PARTIDA
# La diferencia cruda de medias en log(y_total_m) es -0,2375 log points, es
# decir un 21,1% menos para las mujeres (ver `03_descriptives.R`). La pregunta
# de la seccion es cuanto de esa brecha sobrevive al condicionar.
#
# CUIDADO CON LOS BAD CONTROLS
# `oficio`, `sizeFirm` y `relab` son resultados del mercado laboral, no
# caracteristicas predeterminadas. Si la discriminacion opera empujando a las
# mujeres hacia ocupaciones, empresas o posiciones peor pagadas, controlar por
# ellas absorbe justamente el canal que se quiere medir y la brecha estimada
# baja por construccion. Van en la tabla como especificacion adicional, con la
# advertencia explicita, no como especificacion preferida.
#
# POR QUE FWL Y NO SOLO LA REGRESION LARGA
# Frisch-Waugh-Lovell devuelve exactamente el mismo coeficiente de `mujer` que
# la regresion con todos los controles. Sirve para dos cosas: mostrar de donde
# sale la identificacion (la variacion de `mujer` que queda tras purgar los
# controles) y comparar el error estandar analitico contra el bootstrap. Si se
# corre la segunda etapa de FWL a mano, los grados de libertad quedan mal
# contados y el error estandar sale subestimado; el bootstrap no tiene ese
# problema y por eso se reportan los dos.
#
# LIMITACION QUE SE REPORTA EN EL DECK
# La muestra excluye 1.778 ocupados adultos sin ingreso laboral observado, y
# entre ellos los hombres estan sobrerrepresentados (61,0% frente a 52,6%).
# Reestimando con el ingreso imputado por el DANE (`impaes`, N = 16.201) la
# brecha pasa de -0,2375 a -0,2426: se vuelve levemente MAS negativa, de modo
# que la brecha observada subestima la desventaja femenina. El detalle esta en
# `document/notas_pulso.md`.
# ----------------------------------------------------------------------------

# Se Carga los scripts auxiliares utilizando el paquete `here`
# para rutas seguras.
# - `02_cleaning.R`: Carga la muestra de analisis desde 'muestra_analisis.rds'
# - 'edad_pico.R': Carga la funcion personalizada 'edad_pico()' que calcular
# el cociente -b1/(2*b2).
source(here::here("scripts", "02_cleaning.R"))
source(here::here("scripts", "functions", "edad_pico.R"))

# -----------------------------------------------------------------------------
# 1. Especificaciones de Regresión (Evaluación de la Brecha de Ingreso Laboral)
# -----------------------------------------------------------------------------

# (1) Incondicional
# Mide la brecha salarial bruta entre hombres y mujeres, sin controlar por
# ninguna otra variable.
#'ingreso_log' es el logaritmo del ingreso laboral mensual, y 'mujer' es una
#' variable dummy que indica si el individuo es mujer (1) o hombre (0).
m1 <- lm(ingreso_log ~ mujer, data = muestra_analisis)

# (2) Condicional Preferido (Capital Humano / Predeterminadas)
#Ajusta por edad, educación y estrato socioeconómico, que son características
# predeterminadas del individuo y no resultado del mercado laboral.
# Se incluye un término cuadrático para capturar la relación no lineal entre 
# edad e ingreso.
# Desde la teoria, esta es la especificación preferida por que no incluyen bad 
# controls como oficio, tamaño de empresa o posición ocupacional.

m2 <- lm(ingreso_log ~ mujer + age + edad_2 + educ + estrato,
         data = muestra_analisis)

# (3) Modelo Condicional con Bad Controls (Características del Puesto):
#Incluye variables que son resultado del mercado laboral, como oficio, tamaño
# de la empresa y posición ocupacional.
# Exlicación teórica: Este modelo se especifica para mostrar cómo la inclusión
# de estas variables pueden absorber la discriminación estructural y la
# segregación ocupacional, lo que puede llevar a una subestimación de la
# brecha de ingreso laboral por género.
m3 <- lm(
  ingreso_log ~ mujer + age + edad_2 + educ + estrato +
    factor(oficio_grupo) + tamano_empresa + factor(relab_grupo),
  data = muestra_analisis
)

# -----------------------------------------------------------------------------
# 2. Descomposición Frisch-Waugh-Lovell (FWL)
# -----------------------------------------------------------------------------

# Paso 1: Se purga la variación de 'mujer' respecto a los controles
# Se obtiene el residuo de la regresión de 'mujer' sobre los controles.
res_mujer <- residuals(lm(mujer ~ age + edad_2 + educ + estrato,
                          data = muestra_analisis))

# Paso 2: Se purga la variación de 'ingreso_log' respecto a los controles
# Se obtiene el residuo de la regresión de 'ingreso_log' sobre los controles.
res_y <- residuals(lm(ingreso_log ~ age + edad_2 + educ + estrato,
                      data = muestra_analisis))

# Paso 3: Estimar una regresión simple sin intercepto de los residuos obtenidos
# Que fueron purgados
m2_fwl <- lm(res_y ~ res_mujer - 1)

# Imprimir los resultados de la regresión. Se busca comprobar que el coeficiente
# de regresión multiple en 'm2', y el coeficiente de la regresión FWL, 'm2_fwl',
# sean iguales, observando la identidad matemática al limpiar la variable 
# dependiente de ingreso y 'mujer' de la influencia de otros factores.
cat("--- VERIFICACIÓN TEORÍA FWL ---\n")
cat("Coeficiente de 'mujer' en regresión múltiple (m2): ",
    coef(m2)["mujer"], "\n")
cat("Coeficiente de 'res_mujer' en regresión FWL:        ",
    coef(m2_fwl)["res_mujer"], "\n\n")

# -----------------------------------------------------------------------------
# 3. Errores Estándar Analíticos (HC1) vs. Bootstrap para brecha salarial
# -----------------------------------------------------------------------------

# Función estadistica para realizar remuestreo bootstrap de la brecha salarial
# por género.
#Esta función recibe el conjunto de datos de muestra original 'muestra_analisis'
# definido como data, y un vector de índices de remuestreo 'indices'.
boot_brecha <- function(data, indices) {
#Extrae la submuetrea con reemplazo usando los índices proporcionados.
  d <- data[indices, ]
#Se reestima el modelo 'm2 con la submuestra en la submuestra bootstrap.
  m <- lm(ingreso_log ~ mujer + age + edad_2 + educ + estrato, data = d)
#Se retorna el coeficiente de la variable 'mujer' del modelo reestimado.
  coef(m)["mujer"]
}

#Fijamos la semilla para garantizar la reproducibilidad de los resultados del
# remuestreo bootstrap con 10.000 iteraciones.
set.seed(1234)

#Ejecutamos el bootstrap no paramétrico con 10.000 repeticiones para estimar 
#la distribución de la brecha salarial por género.
res_boot_brecha <- boot(data = muestra_analisis,
                        statistic = boot_brecha, R = 10000)

#Calculo del error estándar analítico robusto a heterocedasticidad (HC1).
se_analitico_m2 <- sqrt(diag(vcovHC(m2, type = "HC1")))["mujer"]

#Calculo del error estándar bootstrap como la desviación estándar de los
# 10.000 coeficientes estimados. 
se_bootstrap_m2 <- sd(res_boot_brecha$t)

#Imprimir: Verificación de que las propiedades asintoticas del estimador MCO
#se cumplen, confirmando que el error estandár analítico HC1 y el bootstrap
#convergen con mínima diferencia.
cat("--- ERRORES ESTÁNDAR PARA LA BRECHA EN M2 ---\n")
cat("Error estándar HC1 analítico: ", se_analitico_m2, "\n")
cat("Error estándar Bootstrap:     ", se_bootstrap_m2, "\n\n")

# -----------------------------------------------------------------------------
# 4. Exportar Tabla Comparativa de Regresiones a views/tables/
# -----------------------------------------------------------------------------

# Empaquetamos las 3 especificaciones de regresión en una lista nombrada.
modelos <- list(
  "(1) Incondicional" = m1,
  "(2) Preferido"     = m2,
  "(3) Bad Controls"  = m3
)

# Creamos el directorio 'views/tables' si no existe, para guardar la tabla
dir.create(here::here("views", "tables"),
           showWarnings = FALSE, recursive = TRUE)

# Se contruye y exporta la tabla de regresión estilizada a LaTeX,
# usando la función `msummary()` del paquete `modelsummary`.
msummary(
  modelos,
  vcov = "HC1",   # Aplicación de errores estándar robustos (HC1)
  stars = TRUE,    # Muestra significancia estadística con asteriscos
  gof_omit = "AIC|BIC|Log.Lik|F",    # No mostrar métricas de bondad de ajuste
  title = "Comparación de la Brecha de Ingreso Laboral por Género",
  output = here::here("views", "tables", "tabla_brecha_genero.tex")
)



# -----------------------------------------------------------------------------
# 4b. Tabla COMPACTA para el deck
# -----------------------------------------------------------------------------
# La tabla completa tiene ~30 filas de coeficientes y no cabe en una lamina de
# beamer: un flotante no se puede partir entre laminas. El enunciado no pide
# todos los coeficientes, pide el de genero con sus DOS errores estandar y una
# medida de ajuste, de modo que esta version reporta exactamente eso.
#
# El error bootstrap se calculo solo para la especificacion preferida (2), que
# es la que se estima por FWL. Las otras dos celdas quedan vacias a proposito:
# poner un numero ahi seria inventarlo.

filas_extra <- data.frame(
  term = c(
    "EE bootstrap",
    "Controles"
  ),
  m1 = c(
    "",
    "Ninguno"
  ),
  m2 = c(
    sprintf("(%.5f)", se_bootstrap_m2),
    "Edad, educ, estrato"
  ),
  m3 = c(
    "",
    "+ puesto"
  ),
  stringsAsFactors = FALSE
)

attr(filas_extra, "position") <- c(3, 4)

msummary(
  modelos,
  vcov      = "HC1",
  stars     = TRUE,
  coef_map  = c("mujer" = "Mujer"),
  gof_map   = c("r.squared", "nobs"),
  add_rows  = filas_extra,
  title     = paste(
    "Brecha de ingreso laboral por genero:",
    "errores estandar analiticos y bootstrap"
  ),
  notes = paste(
    "Entre parentesis, errores estandar. La fila EE bootstrap corresponde a",
    sprintf("%s replicas y se calculo solo para la", 
            formatC(nrow(res_boot_brecha$t), format = "d", big.mark = ".")),
    "especificacion preferida. Variable dependiente: log del ingreso laboral",
    "mensual. GEIH 2018, Bogota."
  ),
  output = here::here("views", "tables", "brecha_compacta.tex")
)

message("brecha_compacta.tex written.")


# -----------------------------------------------------------------------------
# 5. Estimación Edad Pico e Intervalos de Confianza por Percentiles (Bootstrap)
# -----------------------------------------------------------------------------

# Función estadística para calcular la edad pico de ingreso laboral por género
# por cada iteración en una muestra bootstrap.
boot_edad_pico <- function(data, indices) {
  # Extrae la submuestra con reemplazo usando los índices proporcionados.
  d <- data[indices, ]

  # Filtrado con base en el género para estimar modelos separados para hombres y
  # mujeres.
  d_hombres <- d[d$mujer == 0, ]
  d_mujeres <- d[d$mujer == 1, ]

  # Estimación del perfil cuadratico de experiencia /edad por genero
  m_h <- lm(
    ingreso_log ~ age + edad_2 + educ + estrato,
    data = d_hombres
  )
  m_m <- lm(
    ingreso_log ~ age + edad_2 + educ + estrato,
    data = d_mujeres
  )

  # Carga de la función personalizada 'edad_pico()' que calcula la edad
  # pico de ingreso con la CPO: - b_edad / (2*b_edad_2).
  edad_pico_fn <- get("edad_pico", mode = "function")
  pico_h <- edad_pico_fn(m_h, termino_edad = "age", termino_edad_2 = "edad_2")
  pico_m <- edad_pico_fn(m_m, termino_edad = "age", termino_edad_2 = "edad_2")

  # Retorna un vector con los dos valores calculados en la iteración.
  c(pico_hombres = pico_h, pico_mujeres = pico_m)
}

  # Se fija la semilla para asegurar reproducibilidad.
set.seed(1234)

  # Ejecutar el bootstrap con 10.000 repeticiones para estimar la
  # razón no lineal de los coeficientes de edad y edad^2.
res_boot_picos <- boot(
  data = muestra_analisis,
  statistic = boot_edad_pico,
  R = 10000
)

 # Calculo de los intervalos de confianza al 95% por el método de
 #percentiles ((2.5%, 97.5%)) para hombres y mujeres.
 #Index 1 corresponde a hombres y index 2 a mujeres.
ic_hombres <- boot.ci(res_boot_picos, type = "perc", index = 1)
ic_mujeres <- boot.ci(res_boot_picos, type = "perc", index = 2)

# Imprimir resultados de la estimación puntual y sus respectivos IC al 95%
# Aquí utilizamos bootstrap por que la edad pico es una razón no lineal de
# dos coeficientes aleatorios y correlacionados En este sentido, el método
# delta impone una simetría que no es realista, mientras bootstrap respeta
# la asímetria real de la distribución muestral del cociente. 
cat("--- EDAD PICO E INTERVALOS DE CONFIANZA (BOOTSTRAP) ---\n")
cat("Edad pico hombres: ", round(res_boot_picos$t0[1], 4),
    "con IC 95%: [", round(ic_hombres$percent[4], 4), ", ",
    round(ic_hombres$percent[5], 4), "]\n")
cat("Edad pico mujeres: ", round(res_boot_picos$t0[2], 4),
    "con IC 95%: [", round(ic_mujeres$percent[4], 4), ", ",
    round(ic_mujeres$percent[5], 4), "]\n\n")

# -----------------------------------------------------------------------------
# 6. Gráfico de Perfiles Edad-Ingreso Predichos y Exportación (CORREGIDO)
# -----------------------------------------------------------------------------

# Se estima un modelo con termino de interacción y la especificación cuadrática 
# para capturar la relación no lineal entre edad e ingreso, y permitir que esta
# relación difiera por género.
#Usamos I(age^2) para asegurar que las funciones de predicción(marginal effects)
# reconozcan la dependencia de una función cuadrática.
m2_interact <- lm(
  ingreso_log ~ mujer * (age + I(age^2)) + educ + estrato,
  data = muestra_analisis
)

# Se define el rango máximo de edad para la gráfica (70 años
# fuerza laboral activa)
edad_max_grafica <- min(max(muestra_analisis$age, na.rm = TRUE), 70)

# Se genera la grilla de predicción marginal promedio usando 
# 'marginaleffects::predictions()' para obtener las predicciones promedio
# La edad varía de 18 a 70 años para ambos sexos, manteniendo los controles
# en su valor promedio distribucional. Esto permite visualizar cómo cambia
# el ingreso predicho con la edad para hombres y mujeres.
grid_edad_preds <- predictions(
  m2_interact,
  newdata = datagrid(
    age = seq(18, edad_max_grafica, by = 1),
    mujer = c(0, 1)
  )
)

# Construcción de la gráfica con ggplot2.
p_edad <- ggplot(
  grid_edad_preds,
  aes(x = age, y = estimate, color = factor(mujer))
) +
  geom_line(size = 1.2) + #líneas continuas para la trayectoria de ingreso
  
  #Linea vertical punteada para la edad pico de hombres.
  geom_vline(
    xintercept = res_boot_picos$t0[1],
    linetype = "dashed",
    color = "navy"
  ) +

  # Linea vertical punteada para la edad pico de mujeres.
  geom_vline(
    xintercept = res_boot_picos$t0[2],
    linetype = "dashed",
    color = "darkred"
  ) +

  #Asignación manual de color y leyendas según género.
  scale_color_manual(
    values = c("0" = "navy", "1" = "darkred"),
    labels = c("Hombres", "Mujeres")
  ) +

  # Etiqueta de títulos, subtítulos y ejes.
  labs(
    title = "Perfiles Edad-Ingreso Predichos por Género",
    subtitle = paste(
      "Predicciones promedio ajustadas sobre las características de la",
      "muestra (Líneas punteadas = Edades pico)"
    ),
    x = "Edad (Años)",
    y = "Log(Ingreso Laboral Mensual)",
    color = "Género"
  ) +
  theme_minimal()  # Tema visual minimalista para la gráfica.

# Creación del directorio de salida para guardar la figura si no existe.
dir.create(here::here("views", "figures"),
           showWarnings = FALSE, recursive = TRUE)

# Guardar archivo en formato png.
ggsave(
  here::here("views", "figures", "perfil_edad_ingreso.png"),
  plot = p_edad,
  width = 8,
  height = 5
)

# =============================================================================
# 7. DIAGNOSTICO DE SELECCION POR NO RESPUESTA DE INGRESO
# =============================================================================
# La muestra analitica excluye a los ocupados adultos sin `y_total_m`. Si esa
# exclusion no fuera neutral por sexo, la brecha estimada estaria sesgada.
#
# El DANE publica una serie imputada (`impaes`) para una parte de esas
# personas, de modo que el sesgo se puede ACOTAR en vez de solo mencionarlo:
# se reestima la brecha cruda sobre una muestra ampliada que usa el ingreso
# imputado donde el observado falta.
#
# Es un analisis de SENSIBILIDAD, no una cota formal: descansa en que la
# imputacion del DANE sea correcta.
#
# Este bloque lee los chunks crudos porque necesita las filas que
# `02_cleaning.R` ya descarto.

crudo_seleccion <- do.call(
  rbind,
  lapply(
    seq_len(10),
    function(i) {
      readRDS(here::here("stores", "raw", sprintf("chunk_%02d.rds", i)))
    }
  )
)

# Ocupados de 18 anos o mas: el universo ANTES del filtro de ingreso.
universo_ocupados <- crudo_seleccion |>
  dplyr::filter(ocu == 1, age >= 18)

excluidos_ingreso <- universo_ocupados |>
  dplyr::filter(is.na(y_total_m))

# De los excluidos, aquellos a los que el DANE si imputo ingreso.
excluidos_imputados <- excluidos_ingreso |>
  dplyr::filter(!is.na(impaes))

# `sex` viene 1 = hombre en el diccionario del DANE.
pct_hombres_imputados <- 100 * mean(excluidos_imputados$sex == 1, na.rm = TRUE)
pct_hombres_muestra   <- 100 * mean(muestra_analisis$mujer == 0)

# Independientes = cuenta propia (relab 4) + patron o empleador (relab 5).
# Es la definicion amplia: son los dos grupos cuyo ingreso no pasa por una
# nomina y que por eso mismo puede no quedar registrado.
pct_independientes_imputados <- 100 * mean(
  excluidos_imputados$relab %in% c(4, 5),
  na.rm = TRUE
)

# Muestra ampliada: mismos filtros de `02_cleaning.R`, pero usando el ingreso
# imputado donde el observado falta.
muestra_ampliada <- universo_ocupados |>
  dplyr::mutate(
    y_ampliado = dplyr::coalesce(y_total_m, impaes)
  ) |>
  dplyr::filter(
    !is.na(y_ampliado),
    y_ampliado > 0,
    totalHoursWorked <= 112,
    !is.na(maxEducLevel)
  ) |>
  dplyr::mutate(
    ingreso_log = log(y_ampliado),
    mujer       = as.integer(sex == 0)
  )

brecha_base     <- coef(m1)[["mujer"]]
brecha_ampliada <- coef(
  lm(ingreso_log ~ mujer, data = muestra_ampliada)
)[["mujer"]]

cat("\n--- SELECCION POR NO RESPUESTA DE INGRESO ---\n")
cat(sprintf("  excluidos por ingreso no observado : %d\n",
            nrow(excluidos_ingreso)))
cat(sprintf("  de ellos, con imputacion del DANE  : %d\n",
            nrow(excluidos_imputados)))
cat(sprintf("  %% hombres entre los imputados      : %.1f\n",
            pct_hombres_imputados))
cat(sprintf("  %% hombres en la muestra analitica  : %.1f\n",
            pct_hombres_muestra))
cat(sprintf("  %% independientes entre imputados   : %.1f\n",
            pct_independientes_imputados))
cat(sprintf("  brecha cruda base      (N = %5d) : %.4f\n",
            nrow(muestra_analisis), brecha_base))
cat(sprintf("  brecha cruda ampliada  (N = %5d) : %.4f\n",
            nrow(muestra_ampliada), brecha_ampliada))
cat(sprintf("  desplazamiento                     : %+.4f\n",
            brecha_ampliada - brecha_base))


# =============================================================================
# 8. MACROS DE LATEX CON LAS CIFRAS DE LA SECCION
# =============================================================================
# El deck interpola estas macros en vez de teclear las cifras. Si la muestra
# cambia, las laminas cambian solas.

num_es_gap <- function(x, digitos, signo = FALSE) {
  formatC(
    x,
    format = "f",
    digits = digitos,
    decimal.mark = ",",
    big.mark = ".",
    flag = if (signo) "+" else ""
  )
}

cifras_gap <- c(
  sprintf("\\newcommand{\\BrechaCruda}{%s}",
          num_es_gap(coef(m1)[["mujer"]], 4)),
  sprintf("\\newcommand{\\BrechaCrudaPct}{%s}",
          num_es_gap(100 * (exp(coef(m1)[["mujer"]]) - 1), 1)),
  sprintf("\\newcommand{\\BrechaCond}{%s}",
          num_es_gap(coef(m2)[["mujer"]], 4)),
  sprintf("\\newcommand{\\BrechaCondPct}{%s}",
          num_es_gap(100 * (exp(coef(m2)[["mujer"]]) - 1), 1)),
  sprintf("\\newcommand{\\BrechaBadControls}{%s}",
          num_es_gap(coef(m3)[["mujer"]], 4)),
  sprintf("\\newcommand{\\SEAnalitico}{%s}",
          num_es_gap(se_analitico_m2, 5)),
  sprintf("\\newcommand{\\SEBootstrap}{%s}",
          num_es_gap(se_bootstrap_m2, 5)),
  sprintf("\\newcommand{\\PicoHombres}{%s}",
          num_es_gap(res_boot_picos$t0[1], 1)),
  sprintf("\\newcommand{\\PicoMujeres}{%s}",
          num_es_gap(res_boot_picos$t0[2], 1)),
  sprintf("\\newcommand{\\ICPicoHombres}{[%s; %s]}",
          num_es_gap(ic_hombres$percent[4], 1),
          num_es_gap(ic_hombres$percent[5], 1)),
  sprintf("\\newcommand{\\ICPicoMujeres}{[%s; %s]}",
          num_es_gap(ic_mujeres$percent[4], 1),
          num_es_gap(ic_mujeres$percent[5], 1)),
  sprintf("\\newcommand{\\RCuadCrudo}{%s}",
          num_es_gap(summary(m1)$r.squared, 4)),
  sprintf("\\newcommand{\\RCuadCondGap}{%s}",
          num_es_gap(summary(m2)$r.squared, 4)),
  sprintf("\\newcommand{\\NGap}{%s}",
          formatC(nrow(muestra_analisis), format = "d", big.mark = ".")),
  sprintf("\\newcommand{\\NExcluidos}{%s}",
          formatC(nrow(excluidos_ingreso), format = "d", big.mark = ".")),
  sprintf("\\newcommand{\\NImputados}{%s}",
          formatC(nrow(excluidos_imputados), format = "d", big.mark = ".")),
  sprintf("\\newcommand{\\NAmpliada}{%s}",
          formatC(nrow(muestra_ampliada), format = "d", big.mark = ".")),
  sprintf("\\newcommand{\\PctHombresImputados}{%s}",
          num_es_gap(pct_hombres_imputados, 1)),
  sprintf("\\newcommand{\\PctHombresMuestra}{%s}",
          num_es_gap(pct_hombres_muestra, 1)),
  sprintf("\\newcommand{\\PctIndependientes}{%s}",
          num_es_gap(pct_independientes_imputados, 1)),
  sprintf("\\newcommand{\\BrechaAmpliada}{%s}",
          num_es_gap(brecha_ampliada, 4)),
  sprintf("\\newcommand{\\DesplazaBrecha}{%s}",
          num_es_gap(brecha_ampliada - brecha_base, 4, signo = TRUE)),
  # Por que la brecha CRECE al condicionar: las mujeres de la muestra estan
  # mas educadas que los hombres, de modo que compararlas a educacion igual
  # deja a la vista una desventaja mayor.
  sprintf("\\newcommand{\\PctSuperiorMujeres}{%s}",
          num_es_gap(100 * mean(
            muestra_analisis$educ[muestra_analisis$mujer == 1] == "7"), 1)),
  sprintf("\\newcommand{\\PctSuperiorHombres}{%s}",
          num_es_gap(100 * mean(
            muestra_analisis$educ[muestra_analisis$mujer == 0] == "7"), 1)),
  sprintf("\\newcommand{\\BootRepsGap}{%s}",
          formatC(nrow(res_boot_brecha$t), format = "d", big.mark = "."))
)

writeLines(
  cifras_gap,
  here::here("views", "tables", "cifras_gap.tex")
)

message("cifras_gap.tex written: ", length(cifras_gap), " macros.")
