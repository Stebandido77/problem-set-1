# 30_prediction.R ------------------------------------------------------------
# Seccion 3: prediccion fuera de muestra.
#
# Objetivo de esta seccion:
#   1. Separar entrenamiento y validacion segun la particion definida.
#   2. Reestimar los baselines de las Secciones 1 y 2 sobre train.
#   3. Estimar al menos cinco especificaciones adicionales.
#   4. Compararlas por RMSE de validacion.
#   5. Aplicar LOOCV al mejor modelo.
#   6. Definir una medida de importancia predictiva y encontrar la variable
#      mas importante.
#   7. Caracterizar como dependen las predicciones de esa variable.
#
# POR QUE LA PARTICION ES TEMPORAL Y NO ALEATORIA
# Los 10 chunks estan ordenados por mes de encuesta: el chunk 1 cubre enero y
# febrero, el chunk 10 noviembre y diciembre (el mes 9 se reparte entre los
# chunks 7 y 8, de modo que el corte cae dentro de septiembre). El corte 1-7 /
# 8-10 que fija el enunciado es entonces un corte en el TIEMPO, no una
# asignacion al azar. Dos consecuencias operativas:
#
#   a. `mes` y `chunk_id` no pueden entrar como predictores: cualquiera de los
#      dos filtra la particion y el RMSE de validacion dejaria de medir error
#      fuera de muestra. Estan en `no_predictores` dentro de `02_cleaning.R`.
#   b. Leer el RMSE de validacion como error fuera de muestra ordinario exige
#      que no haya salto de nivel entre los dos folds. No lo hay, y las dos
#      especificaciones de `03_descriptives.R` coinciden: como dummy sola,
#      diciembre da b = +0,0087 (p = 0,76); sobre una tendencia mensual,
#      b = -0,018 (p = 0,59). Ninguna se distingue de cero, porque la prima
#      de servicios ya entra en `y_total_m` mensualizada. La evidencia esta
#      en `views/figures/deriva_temporal.png`, cuyo subtitulo cita la primera
#      de las dos.
#
# El mismo razonamiento vale para la agrupacion de `oficio`: el umbral de 30
# observaciones se calcula SOLO sobre los chunks 1-7 y despues se aplica a los
# chunks 8-10, para que el fold de validacion nunca informe la codificacion.
#
# POR QUE EL RMSE DE VALIDACION Y EL LOOCV NO SOBRAN UNO DEL OTRO
# El RMSE de validacion se calcula sobre un periodo distinto y, siendo un solo
# corte de 4.496 filas, es ruidoso. El LOOCV usa las 10.255 filas de
# entrenamiento y es mucho mas estable, pero mide error dentro del MISMO
# periodo. Se reportan los dos: si ordenan los modelos igual, la eleccion es
# robusta; si no, la discrepancia misma es el resultado interesante.
# ----------------------------------------------------------------------------

source(here::here("scripts", "02_cleaning.R"))
source(here::here("scripts", "functions", "rmse.R"))
source(here::here("scripts", "functions", "rmse_loocv.R"))
source(here::here("scripts", "functions", "figuras.R"))
source(here::here("scripts", "20_gender_gap.R"))


# =============================================================================
# 1. PARTICION ENTRENAMIENTO / VALIDACION
# =============================================================================
# Separamos la muestra en dos grupos:
#
# - train: observaciones utilizadas para estimar los modelos.
# - validation: observaciones reservadas para evaluar capacidad predictiva
#   fuera de muestra.
#
# La variable `particion` ya define esta separacion en la base, por lo que no
# hacemos un split aleatorio adicional.

train <- muestra_analisis |>
  dplyr::filter(particion == "entrenamiento")

validation <- muestra_analisis |>
  dplyr::filter(particion == "validacion")

# Verificamos el numero de observaciones y los chunks asignados a cada grupo.
nrow(train)
nrow(validation)

table(train$chunk_id)
table(validation$chunk_id)


# =============================================================================
# 2. BASELINE DE LA SECCION 1, REESTIMADO SOBRE TRAIN
# =============================================================================
# La Seccion 1 estima el perfil edad-ingreso sobre la muestra COMPLETA, porque
# alli la pregunta es descriptiva y no hay ninguna eleccion de modelo que
# validar. Aqui la pregunta es otra: cuanto predice esa especificacion fuera de
# muestra. Por eso se reestima sobre train y se evalua en validation, igual que
# todos los demas modelos de esta seccion.
#
# Se reestiman las DOS especificaciones de la Seccion 1:
#   (1) incondicional: ingreso_log ~ age + edad_2
#   (2) condicional  : + horas + relab_grupo
#
# OJO CON LA EDAD PICO: la de esta seccion NO tiene por que coincidir con la
# que reporta la Seccion 1. Aquella se estima sobre las 14.751 observaciones;
# esta, sobre los chunks 1-7 solamente. Una diferencia entre las dos es
# variabilidad muestral, no un error: son dos muestras distintas.

base_s1_incond <- lm(
  ingreso_log ~ age + edad_2,
  data = train
)

base_s1_cond <- lm(
  ingreso_log ~ age + edad_2 + horas + relab_grupo,
  data = train
)

pred_s1_incond <- predict(base_s1_incond, newdata = validation)
pred_s1_cond   <- predict(base_s1_cond,   newdata = validation)

rmse_s1_incond <- rmse(validation$ingreso_log, pred_s1_incond)
rmse_s1_cond   <- rmse(validation$ingreso_log, pred_s1_cond)

rmse_s1_incond
rmse_s1_cond

# Edad pico sobre train, contrastada con la de la muestra completa. Se imprimen
# las dos para dejar el contraste a la vista y que nadie lea la diferencia como
# una inconsistencia entre secciones.

edad_pico_train_incond <- edad_pico(base_s1_incond)
edad_pico_train_cond   <- edad_pico(base_s1_cond)

edad_pico_full_incond <- edad_pico(
  lm(ingreso_log ~ age + edad_2, data = muestra_analisis)
)
edad_pico_full_cond <- edad_pico(
  lm(ingreso_log ~ age + edad_2 + horas + relab_grupo,
     data = muestra_analisis)
)

cat("\n--- edad pico: train (chunks 1-7) vs muestra completa ---\n")
cat(sprintf("  incondicional  train %.2f | completa %.2f | dif %+.2f\n",
            edad_pico_train_incond, edad_pico_full_incond,
            edad_pico_train_incond - edad_pico_full_incond))
cat(sprintf("  condicional    train %.2f | completa %.2f | dif %+.2f\n",
            edad_pico_train_cond, edad_pico_full_cond,
            edad_pico_train_cond - edad_pico_full_cond))


# =============================================================================
# 3. BASELINE DE LA SECCION 2, REESTIMADO SOBRE TRAIN
# =============================================================================
# El baseline de la Seccion 2 fue estimado originalmente como `m2`.
# Para evaluar prediccion fuera de muestra, reestimamos exactamente la misma
# especificacion usando exclusivamente las observaciones de train.

m2_train <- update(
  m2,
  data = train
)

m2_train

# Usamos los coeficientes estimados en train para predecir ingreso_log en
# validation. Las observaciones de validation no participan en la estimacion.

pred_m2 <- predict(
  m2_train,
  newdata = validation
)


# El error predictivo del baseline se mide con el RMSE:
#
#   RMSE = sqrt(mean((y_observado - y_predicho)^2))
#
# Un RMSE menor indica predicciones mas cercanas a los valores observados,
# siempre que comparemos la misma variable objetivo y la misma muestra.

rmse_m2 <- rmse(
  validation$ingreso_log,
  pred_m2
)

rmse_m2


# =============================================================================
# 4. CINCO ESPECIFICACIONES PREDICTIVAS ADICIONALES
# =============================================================================
# Partimos del baseline de la Seccion 2 y aumentamos progresivamente la
# flexibilidad y la informacion disponible para el predictor.
#
# Todos los modelos se estiman sobre train. La seleccion NO se hace por R2,
# significancia individual de coeficientes o ajuste dentro de muestra, sino
# por RMSE en validation.


# -----------------------------------------------------------------------------
# MODEL 1: HOURS WORKED + EMPLOYMENT RELATIONSHIP
# -----------------------------------------------------------------------------
# Agregamos `horas` y `relab_grupo`.
#
# Motivacion:
# Personas con caracteristicas demograficas similares pueden tener ingresos
# diferentes por la cantidad de horas trabajadas y por su posicion o relacion
# laboral.
#
# No introducimos una nueva no linealidad en este paso.

mod_pred_1 <- lm(
  ingreso_log ~ mujer + age + edad_2 + educ + estrato +
    horas + relab_grupo,
  data = train
)


# -----------------------------------------------------------------------------
# MODEL 2: NONLINEAR TENURE PROFILE
# -----------------------------------------------------------------------------
# Conservamos el Modelo 1 y agregamos antiguedad laboral en forma lineal y
# cuadratica:
#
#   antiguedad_meses + antiguedad_meses^2
#
# Esto permite que la relacion entre antiguedad e ingreso sea curva en lugar
# de imponer una pendiente constante.

mod_pred_2 <- lm(
  ingreso_log ~ mujer + age + edad_2 + educ + estrato +
    horas + relab_grupo +
    antiguedad_meses + I(antiguedad_meses^2),
  data = train
)


# -----------------------------------------------------------------------------
# MODEL 3: EMPLOYMENT AND FIRM CHARACTERISTICS
# -----------------------------------------------------------------------------
# Agregamos informacion sobre la estructura del empleo y de la empresa:
# `tamano_empresa`, `formal`, `cuenta_propia` y `micro_empresa`.
#
# Estas variables buscan capturar heterogeneidad laboral que no estaba
# contenida en las caracteristicas demograficas del baseline.

mod_pred_3 <- lm(
  ingreso_log ~ mujer + age + edad_2 + educ + estrato +
    horas + relab_grupo +
    antiguedad_meses + I(antiguedad_meses^2) +
    tamano_empresa + formal + cuenta_propia + micro_empresa,
  data = train
)


# -----------------------------------------------------------------------------
# MODEL 4: OCCUPATION
# -----------------------------------------------------------------------------
# Agregamos `oficio_grupo`.
#
# Como `oficio_grupo` es categorica, R la representa mediante varias dummies.
# Aunque visualmente agregamos una sola variable, el numero de parametros del
# modelo puede aumentar de forma importante.
#
# Motivacion:
# La ocupacion puede contener informacion predictiva sobre diferencias de
# ingreso entre tipos de trabajo.

mod_pred_4 <- lm(
  ingreso_log ~ mujer + age + edad_2 + educ + estrato +
    horas + relab_grupo +
    antiguedad_meses + I(antiguedad_meses^2) +
    tamano_empresa + formal + cuenta_propia + micro_empresa +
    oficio_grupo,
  data = train
)


# -----------------------------------------------------------------------------
# MODEL 5: INTERACTIONS
# -----------------------------------------------------------------------------
# Agregamos `mujer:educ` y `age:educ`.
#
# Las interacciones permiten que la relacion entre una variable y la
# prediccion dependa de otra. Por ejemplo, la asociacion entre educacion e
# ingreso puede variar segun genero o edad.
#
# El modelo sigue siendo lineal en los parametros aunque incorpore
# transformaciones e interacciones de los predictores.

mod_pred_5 <- lm(
  ingreso_log ~ mujer + age + edad_2 + educ + estrato +
    horas + relab_grupo +
    antiguedad_meses + I(antiguedad_meses^2) +
    tamano_empresa + formal + cuenta_propia + micro_empresa +
    oficio_grupo +
    mujer:educ + age:educ,
  data = train
)


# =============================================================================
# 5. PREDICCIONES SOBRE VALIDATION
# =============================================================================
# Generamos predicciones para las mismas observaciones de validation usando
# cada uno de los cinco modelos estimados en train.

pred_mod_1 <- predict(mod_pred_1, newdata = validation)
pred_mod_2 <- predict(mod_pred_2, newdata = validation)
pred_mod_3 <- predict(mod_pred_3, newdata = validation)
pred_mod_4 <- predict(mod_pred_4, newdata = validation)
pred_mod_5 <- predict(mod_pred_5, newdata = validation)

# Comprobacion diagnostica:
# todos los vectores de prediccion deberian tener el mismo numero de
# observaciones que validation y, idealmente, no contener NA.

sapply(
  list(
    M1 = pred_mod_1,
    M2 = pred_mod_2,
    M3 = pred_mod_3,
    M4 = pred_mod_4,
    M5 = pred_mod_5
  ),
  length
)

sapply(
  list(
    M1 = pred_mod_1,
    M2 = pred_mod_2,
    M3 = pred_mod_3,
    M4 = pred_mod_4,
    M5 = pred_mod_5
  ),
  function(x) sum(is.na(x))
)


# =============================================================================
# 6. RMSE DE VALIDACION DE LAS CINCO ESPECIFICACIONES
# =============================================================================
# Calculamos el RMSE de cada especificacion sobre el mismo validation set.

rmse_mod_1 <- rmse(validation$ingreso_log, pred_mod_1)
rmse_mod_2 <- rmse(validation$ingreso_log, pred_mod_2)
rmse_mod_3 <- rmse(validation$ingreso_log, pred_mod_3)
rmse_mod_4 <- rmse(validation$ingreso_log, pred_mod_4)
rmse_mod_5 <- rmse(validation$ingreso_log, pred_mod_5)

rmse_mod_1
rmse_mod_2
rmse_mod_3
rmse_mod_4
rmse_mod_5


# =============================================================================
# 7. COLINEALIDAD PERFECTA Y MODELO 5 LIMPIO
# =============================================================================
# Durante la revision del Modelo 5 observamos coeficientes NA para
# `cuenta_propia` y `micro_empresa`.
#
# `alias()` permite verificar si existen dependencias lineales exactas entre
# columnas de la matriz de regresores.

coef(mod_pred_5)[c("cuenta_propia", "micro_empresa")]
alias(mod_pred_5)

# En los resultados obtenidos:
# - `cuenta_propia` es redundante con una categoria de `relab_grupo`.
# - `micro_empresa` esta determinada por el intercepto y categorias de
#   `tamano_empresa`.
#
# Por tanto, sus coeficientes no pueden identificarse de forma separada.
# Eliminamos ambas variables redundantes y reestimamos el modelo.

mod_pred_5_clean <- update(
  mod_pred_5,
  . ~ . - cuenta_propia - micro_empresa,
  data = train
)

# Comprobamos que retirar variables redundantes no cambia las predicciones ni
# el RMSE de validacion.

pred_m5_clean <- predict(
  mod_pred_5_clean,
  newdata = validation
)

rmse_m5_clean <- rmse(
  validation$ingreso_log,
  pred_m5_clean
)

rmse_mod_5
rmse_m5_clean

# En nuestras ejecuciones ambos fueron 0.5813906, por lo que la limpieza no
# produjo perdida de capacidad predictiva.


# =============================================================================
# 8. TABLA COMPARATIVA: BASELINES Y MODELOS NUEVOS
# =============================================================================
# Reunimos en una sola tabla los baselines de las Secciones 1 y 2 y las cinco
# especificaciones nuevas. El enunciado pide exactamente esta comparacion: las
# especificaciones de las secciones anteriores son la linea base contra la que
# se miden los modelos predictivos.
#
# Se reporta el Modelo 5 LIMPIO. El original tiene dos coeficientes NA por
# colinealidad perfecta (seccion 7) y produce predicciones identicas, de modo
# que informar los dos duplicaria una misma fila.

# MODELO NULO: predecir a todo el mundo la media de ingreso_log del
# entrenamiento, sin un solo regresor. Es el piso contra el que hay que leer
# todo lo demas: un modelo que no le gane a esta fila no esta aportando
# informacion, solo esta reproduciendo el nivel promedio. La media se toma
# SOBRE TRAIN, no sobre validation, porque usar la media del fold de
# validacion seria mirar la respuesta antes de predecirla.

pred_nulo <- rep(mean(train$ingreso_log), nrow(validation))
rmse_nulo <- rmse(validation$ingreso_log, pred_nulo)

rmse_nulo

resultados_rmse <- tibble::tibble(
  modelo = c(
    "Media (sin regresores)",
    "Baseline S1 incondicional",
    "Baseline S1 condicional",
    "Baseline S2",
    "Modelo 1",
    "Modelo 2",
    "Modelo 3",
    "Modelo 4",
    "Modelo 5 (limpio)"
  ),
  rmse_validation = c(
    rmse_nulo,
    rmse_s1_incond,
    rmse_s1_cond,
    rmse_m2,
    rmse_mod_1,
    rmse_mod_2,
    rmse_mod_3,
    rmse_mod_4,
    rmse_m5_clean
  )
) |>
  dplyr::mutate(
    reduccion_vs_nulo = 1 - rmse_validation / rmse_nulo
  ) |>
  dplyr::arrange(rmse_validation)

# `reduccion_vs_nulo` es la fraccion del error del modelo nulo que la
# especificacion elimina. Responde la pregunta que motiva la fila nula:
# cuanto aporta cada modelo por encima de no saber nada.

# print() explicito: al correr por 99_run_all.R el script llega via
# source(), que no auto-imprime objetos sueltos. Sin esto la tabla de
# resultados no aparece en el log de la corrida canonica.

print(resultados_rmse)

# El ganador es la primera fila de la tabla. Se lee del objeto en vez de
# escribirlo a mano, para que un cambio de muestra no deje el texto desfasado.

modelo_ganador <- resultados_rmse$modelo[1]
rmse_ganador   <- resultados_rmse$rmse_validation[1]

cat(sprintf("\n--- ganador por RMSE de validacion: %s (%.4f) ---\n",
            modelo_ganador, rmse_ganador))

# El LOOCV y la importancia de variables de las secciones siguientes se
# calculan sobre el Modelo 5 limpio. Si el ganador dejara de ser ese modelo,
# habria que repetirlos sobre el nuevo ganador: este stopifnot() detiene la
# corrida en vez de dejar que el resto de la seccion analice un modelo que ya
# no es el elegido.

stopifnot(
  "El ganador ya no es el Modelo 5 limpio: repetir LOOCV e importancia." =
    modelo_ganador == "Modelo 5 (limpio)"
)


# =============================================================================
# 9. LOOCV DEL MEJOR MODELO
# =============================================================================
# Comparamos el desempeño del mejor modelo provisional usando LOOCV sobre
# train.
#
# `rmse_loocv()` usa el atajo exacto de OLS basado en leverage:
#
#   e_(-i) = e_i / (1 - h_ii)
#
# Esto evita reestimar el modelo n veces.

rmse_loocv_m5 <- rmse_loocv(mod_pred_5_clean)

rmse_loocv_m5

# En la ejecucion previa, el Modelo 5 original produjo un RMSE LOOCV de
# 0.5559649. El valor del modelo limpio debe verificarse al correr el script
# completo desde una sesion nueva.


# =============================================================================
# 10. IMPORTANCIA DE VARIABLES
# =============================================================================
# Definimos la importancia predictiva de una variable j como:
#
#   Importance_j = RMSE_sin_j - RMSE_modelo_completo
#
# Procedimiento:
#   1. Retiramos la variable (o todo su bloque de terminos).
#   2. Reestimamos el modelo sobre train.
#   3. Predecimos sobre el mismo validation.
#   4. Calculamos cuanto aumenta el RMSE.
#
# Cuanto mayor sea el aumento del RMSE, mayor es la contribucion predictiva
# marginal de esa variable dentro de esta especificacion.
#
# Esta es una medida de importancia PREDICTIVA, no una afirmacion causal.
#
# Para variables presentes en cuadrados o interacciones eliminamos todo el
# bloque asociado, de modo que la comparacion represente la variable completa.


# -----------------------------------------------------------------------------
# 10.1 OCCUPATION
# -----------------------------------------------------------------------------

mod_sin_oficio <- update(
  mod_pred_5_clean,
  . ~ . - oficio_grupo,
  data = train
)

pred_sin_oficio <- predict(
  mod_sin_oficio,
  newdata = validation
)

rmse_sin_oficio <- rmse(
  validation$ingreso_log,
  pred_sin_oficio
)

importancia_oficio <- rmse_sin_oficio - rmse_m5_clean

rmse_sin_oficio
importancia_oficio


# -----------------------------------------------------------------------------
# 10.2 HOURS WORKED
# -----------------------------------------------------------------------------

mod_sin_horas <- update(
  mod_pred_5_clean,
  . ~ . - horas,
  data = train
)

pred_sin_horas <- predict(
  mod_sin_horas,
  newdata = validation
)

rmse_sin_horas <- rmse(
  validation$ingreso_log,
  pred_sin_horas
)

importancia_horas <- rmse_sin_horas - rmse_m5_clean

rmse_sin_horas
importancia_horas


# -----------------------------------------------------------------------------
# 10.3 EMPLOYMENT RELATIONSHIP
# -----------------------------------------------------------------------------

mod_sin_relab <- update(
  mod_pred_5_clean,
  . ~ . - relab_grupo,
  data = train
)

pred_sin_relab <- predict(
  mod_sin_relab,
  newdata = validation
)

rmse_sin_relab <- rmse(
  validation$ingreso_log,
  pred_sin_relab
)

importancia_relab <- rmse_sin_relab - rmse_m5_clean

rmse_sin_relab
importancia_relab


# -----------------------------------------------------------------------------
# 10.4 FIRM SIZE
# -----------------------------------------------------------------------------

mod_sin_tamano <- update(
  mod_pred_5_clean,
  . ~ . - tamano_empresa,
  data = train
)

pred_sin_tamano <- predict(
  mod_sin_tamano,
  newdata = validation
)

rmse_sin_tamano <- rmse(
  validation$ingreso_log,
  pred_sin_tamano
)

importancia_tamano <- rmse_sin_tamano - rmse_m5_clean

rmse_sin_tamano
importancia_tamano


# -----------------------------------------------------------------------------
# 10.5 FORMAL EMPLOYMENT
# -----------------------------------------------------------------------------

mod_sin_formal <- update(
  mod_pred_5_clean,
  . ~ . - formal,
  data = train
)

pred_sin_formal <- predict(
  mod_sin_formal,
  newdata = validation
)

rmse_sin_formal <- rmse(
  validation$ingreso_log,
  pred_sin_formal
)

importancia_formal <- rmse_sin_formal - rmse_m5_clean

rmse_sin_formal
importancia_formal


# -----------------------------------------------------------------------------
# 10.6 SOCIOECONOMIC STRATUM
# -----------------------------------------------------------------------------

mod_sin_estrato <- update(
  mod_pred_5_clean,
  . ~ . - estrato,
  data = train
)

pred_sin_estrato <- predict(
  mod_sin_estrato,
  newdata = validation
)

rmse_sin_estrato <- rmse(
  validation$ingreso_log,
  pred_sin_estrato
)

importancia_estrato <- rmse_sin_estrato - rmse_m5_clean

rmse_sin_estrato
importancia_estrato


# -----------------------------------------------------------------------------
# 10.7 TENURE
# -----------------------------------------------------------------------------
# Antiguedad aparece de forma lineal y cuadratica. Para medir la importancia
# de la variable completa eliminamos ambos terminos.

mod_sin_antiguedad <- update(
  mod_pred_5_clean,
  . ~ . - antiguedad_meses - I(antiguedad_meses^2),
  data = train
)

pred_sin_antiguedad <- predict(
  mod_sin_antiguedad,
  newdata = validation
)

rmse_sin_antiguedad <- rmse(
  validation$ingreso_log,
  pred_sin_antiguedad
)

importancia_antiguedad <- rmse_sin_antiguedad - rmse_m5_clean

rmse_sin_antiguedad
importancia_antiguedad


# -----------------------------------------------------------------------------
# 10.8 GENDER
# -----------------------------------------------------------------------------
# `mujer` aparece como efecto principal y en la interaccion `mujer:educ`.
# Para medir la importancia del bloque asociado a genero eliminamos ambos.

mod_sin_mujer <- update(
  mod_pred_5_clean,
  . ~ . - mujer - mujer:educ,
  data = train
)

pred_sin_mujer <- predict(
  mod_sin_mujer,
  newdata = validation
)

rmse_sin_mujer <- rmse(
  validation$ingreso_log,
  pred_sin_mujer
)

importancia_mujer <- rmse_sin_mujer - rmse_m5_clean

rmse_sin_mujer
importancia_mujer


# -----------------------------------------------------------------------------
# 10.9 AGE
# -----------------------------------------------------------------------------
# Edad aparece como termino lineal, cuadratico y en interaccion con educacion.
# Para medir su importancia completa eliminamos los tres componentes.

mod_sin_age <- update(
  mod_pred_5_clean,
  . ~ . - age - edad_2 - age:educ,
  data = train
)

pred_sin_age <- predict(
  mod_sin_age,
  newdata = validation
)

rmse_sin_age <- rmse(
  validation$ingreso_log,
  pred_sin_age
)

importancia_age <- rmse_sin_age - rmse_m5_clean

rmse_sin_age
importancia_age


# -----------------------------------------------------------------------------
# 10.10 EDUCATION
# -----------------------------------------------------------------------------
# Educacion aparece como efecto principal y en interacciones con mujer y edad.
# Para medir su importancia completa eliminamos todos esos componentes.

mod_sin_educ <- update(
  mod_pred_5_clean,
  . ~ . - educ - mujer:educ - age:educ,
  data = train
)

pred_sin_educ <- predict(
  mod_sin_educ,
  newdata = validation
)

rmse_sin_educ <- rmse(
  validation$ingreso_log,
  pred_sin_educ
)

importancia_educ <- rmse_sin_educ - rmse_m5_clean

rmse_sin_educ
importancia_educ


# -----------------------------------------------------------------------------
# 10.11 VARIABLE IMPORTANCE RANKING
# -----------------------------------------------------------------------------
# Ordenamos todas las variables evaluadas por el aumento que generan en el
# RMSE cuando se eliminan del modelo.
#
# `cuenta_propia` y `micro_empresa` no se incluyen porque fueron eliminadas por
# colinealidad perfecta y no tienen una contribucion separadamente
# identificable dentro de esta especificacion.

resultados_importancia <- tibble::tibble(
  variable = c(
    "horas",
    "oficio_grupo",
    "estrato",
    "age",
    "antiguedad_meses",
    "formal",
    "educ",
    "mujer",
    "relab_grupo",
    "tamano_empresa"
  ),
  aumento_rmse = c(
    importancia_horas,
    importancia_oficio,
    importancia_estrato,
    importancia_age,
    importancia_antiguedad,
    importancia_formal,
    importancia_educ,
    importancia_mujer,
    importancia_relab,
    importancia_tamano
  )
) |>
  dplyr::arrange(dplyr::desc(aumento_rmse))

print(resultados_importancia)

# Con los resultados obtenidos previamente, `horas` presenta el mayor aumento
# del RMSE al ser eliminada, seguida muy de cerca por `oficio_grupo` y
# `estrato`. Por nuestra definicion, `horas` es el predictor mas importante.


# =============================================================================
# 11. DEPENDENCIA DE LAS PREDICCIONES RESPECTO DE HORAS
# =============================================================================
# Despues de identificar `horas` como la variable mas importante, analizamos
# como cambian las predicciones del modelo cuando cambia esta variable.
#
# En el Modelo 5 limpio, `horas` entra linealmente y no participa en
# interacciones. Por tanto, su pendiente en la prediccion de ingreso_log es
# constante.

coef_horas <- coef(mod_pred_5_clean)["horas"]
coef_horas

# En nuestra ejecucion previa:
#   beta_horas = 0.01584108
#
# Esto significa que una hora adicional esta asociada con un aumento de
# 0.01584 log-points en el ingreso predicho, manteniendo constantes las demas
# caracteristicas del modelo.
#
# Esta interpretacion describe una asociacion predictiva; no implica
# causalidad.


# -----------------------------------------------------------------------------
# 11.1 PREDICTION DEPENDENCE CURVE
# -----------------------------------------------------------------------------
# Para cada valor de horas:
#   1. mantenemos intactas las demas caracteristicas observadas en validation;
#   2. reemplazamos solo `horas` por un valor comun h;
#   3. generamos predicciones para todas las observaciones;
#   4. promediamos las predicciones.
#
# Restringimos el grafico al 5%-95% de la distribucion observada de horas para
# evitar que valores extremos dominen la visualizacion.

horas_grid <- seq(
  from = quantile(validation$horas, 0.05, na.rm = TRUE),
  to   = quantile(validation$horas, 0.95, na.rm = TRUE),
  length.out = 100
)

pred_promedio_horas <- sapply(
  horas_grid,
  function(h) {

    datos_h <- validation

    # Cambiamos solamente las horas trabajadas.
    datos_h$horas <- h

    # Prediccion del Modelo 5 limpio.
    pred_h <- predict(
      mod_pred_5_clean,
      newdata = datos_h
    )

    # Promedio de las predicciones para ese valor de horas.
    mean(pred_h, na.rm = TRUE)
  }
)

dependencia_horas <- tibble::tibble(
  horas = horas_grid,
  ingreso_log_predicho = pred_promedio_horas
)

grafica_horas <- ggplot2::ggplot(
  dependencia_horas,
  ggplot2::aes(
    x = horas,
    y = ingreso_log_predicho
  )
) +
  ggplot2::geom_line(linewidth = 1) +
  ggplot2::labs(
    x = "Horas trabajadas por semana",
    y = "Ingreso laboral mensual predicho (log, promedio)",
    title = "Ingreso predicho y horas trabajadas"
  ) +
  ggplot2::theme_minimal()

# La figura se exporta a views/figures/ como todas las demas del proyecto. Sin
# esto, `grafica_horas` solo se imprime al dispositivo grafico y una corrida
# por Rscript deja un Rplots.pdf suelto en la raiz del repositorio.

guardar_fig(grafica_horas, "dependencia_horas.png")


# =============================================================================
# 12. EXPORTACION DE TABLAS Y CIFRAS PARA EL DECK
# =============================================================================
# El deck de la Seccion 3 no calcula nada: incluye estas salidas con \input{}.
# Ninguna cifra se teclea en las laminas.

# Diagnostico para la autoridad tributaria: quienes quedan fuera del alcance
# del modelo. No son ruido, son un grupo con perfil propio, y ninguna
# especificacion de esta seccion puede senalarlos porque no estan en la
# muestra sobre la que se estima.

crudo_pred <- do.call(
  rbind,
  lapply(
    seq_len(10),
    function(i) {
      readRDS(here::here("stores", "raw", sprintf("chunk_%02d.rds", i)))
    }
  )
)

sin_ingreso_pred <- crudo_pred |>
  dplyr::filter(ocu == 1, age >= 18, is.na(y_total_m), !is.na(impaes))

pct_indep_sin_ingreso <- 100 * mean(
  sin_ingreso_pred$relab %in% c(4, 5),
  na.rm = TRUE
)

# --- Tabla 1: RMSE de validacion de todas las especificaciones --------------

tabla_rmse <- resultados_rmse |>
  dplyr::mutate(
    rmse_validation   = num_es(rmse_validation, 4),
    reduccion_vs_nulo = num_es(100 * reduccion_vs_nulo, 1)
  ) |>
  dplyr::rename(
    `Especificacion`             = modelo,
    `RMSE validacion`            = rmse_validation,
    `Reduccion vs. nulo (pp)`    = reduccion_vs_nulo
  )

# datasummary_df() viene de modelsummary, que ya esta en 00_packages.R. Se usa
# en vez de tinytable directamente para no agregar una dependencia nueva.

modelsummary::datasummary_df(
  tabla_rmse,
  output = here::here("views", "tables", "rmse_pred.tex"),
  notes = paste(
    "Estimacion sobre chunks 1-7; RMSE sobre chunks 8-10. El modelo nulo",
    "predice la media de entrenamiento a todas las observaciones."
  )
)

# --- Tabla 2: importancia de variables --------------------------------------

tabla_importancia <- resultados_importancia |>
  dplyr::mutate(aumento_rmse = num_es(aumento_rmse, 4)) |>
  dplyr::rename(
    `Variable`                = variable,
    `Aumento del RMSE`        = aumento_rmse
  )

modelsummary::datasummary_df(
  tabla_importancia,
  output = here::here("views", "tables", "importancia_pred.tex"),
  notes = paste(
    "Aumento del RMSE de validacion al retirar la variable del Modelo 5",
    "limpio y reestimar sobre entrenamiento."
  )
)

# --- Macros con las cifras del texto ----------------------------------------

cifras_pred <- c(
  sprintf("\\newcommand{\\NTrain}{%s}",
          formatC(nrow(train), format = "d", big.mark = ".")),
  sprintf("\\newcommand{\\NValidacion}{%s}",
          formatC(nrow(validation), format = "d", big.mark = ".")),
  sprintf("\\newcommand{\\ModeloGanador}{%s}", modelo_ganador),
  sprintf("\\newcommand{\\RMSEGanador}{%s}", num_es(rmse_ganador, 4)),
  sprintf("\\newcommand{\\RMSENulo}{%s}", num_es(rmse_nulo, 4)),
  sprintf("\\newcommand{\\RMSELoocv}{%s}", num_es(rmse_loocv_m5, 4)),
  sprintf("\\newcommand{\\BrechaLoocv}{%s}",
          num_es(rmse_ganador - rmse_loocv_m5, 4, signo = TRUE)),
  sprintf("\\newcommand{\\ReduccionGanador}{%s}",
          num_es(100 * (1 - rmse_ganador / rmse_nulo), 1)),
  sprintf("\\newcommand{\\ReduccionSUnoIncond}{%s}",
          num_es(100 * (1 - rmse_s1_incond / rmse_nulo), 1)),
  sprintf("\\newcommand{\\RMSESUnoIncond}{%s}", num_es(rmse_s1_incond, 4)),
  sprintf("\\newcommand{\\RMSESUnoCond}{%s}", num_es(rmse_s1_cond, 4)),
  sprintf("\\newcommand{\\RMSESDos}{%s}", num_es(rmse_m2, 4)),
  sprintf("\\newcommand{\\VarImportante}{%s}",
          resultados_importancia$variable[1]),
  sprintf("\\newcommand{\\ImportanciaTop}{%s}",
          num_es(resultados_importancia$aumento_rmse[1], 4)),
  sprintf("\\newcommand{\\ImportanciaSegunda}{%s}",
          num_es(resultados_importancia$aumento_rmse[2], 4)),
  sprintf("\\newcommand{\\CoefHorasPred}{%s}",
          num_es(unname(coef_horas), 5)),
  sprintf("\\newcommand{\\PicoTrainIncond}{%s}",
          num_es(edad_pico_train_incond, 2)),
  sprintf("\\newcommand{\\PicoTrainCond}{%s}",
          num_es(edad_pico_train_cond, 2)),
  sprintf("\\newcommand{\\NSinIngresoPred}{%s}",
          formatC(nrow(sin_ingreso_pred), format = "d", big.mark = ".")),
  sprintf("\\newcommand{\\PctIndepSinIngreso}{%s}",
          num_es(pct_indep_sin_ingreso, 1))
)

writeLines(
  cifras_pred,
  here::here("views", "tables", "cifras_pred.tex")
)

message("rmse_pred.tex, importancia_pred.tex y cifras_pred.tex written.")
