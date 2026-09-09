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
# PENDIENTE:
# Incorporar el baseline final de la Seccion 1 cuando el equipo confirme su
# especificacion.
#
# NOTA:
# Los comentarios iniciales sobre la estructura temporal de los chunks y las
# decisiones de limpieza deben conservarse solo si fueron verificados en los
# scripts correspondientes del proyecto.
# -----------------------------------------------------------------------------

source(here::here("scripts", "02_cleaning.R"))
source(here::here("scripts", "functions", "rmse.R"))
source(here::here("scripts", "functions", "rmse_loocv.R"))
source(here::here("scripts", "20_gender_gap.R"))


# =============================================================================
# 1. TRAIN / VALIDATION SPLIT
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
# 2. RE-ESTIMATE SECTION 2 BASELINE
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


# =============================================================================
# 3. RMSE - SECTION 2 BASELINE
# =============================================================================
# Evaluamos el error predictivo del baseline mediante RMSE:
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
# 4. FIVE ADDITIONAL PREDICTIVE SPECIFICATIONS
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
# 5. VALIDATION PREDICTIONS
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
# 6. VALIDATION RMSE AND MODEL COMPARISON
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

# Construimos una tabla ordenada de menor a mayor RMSE.
# El baseline de la Seccion 1 se agregara aqui cuando el equipo confirme la
# especificacion final.

resultados_rmse <- tibble::tibble(
  modelo = c(
    "Baseline S2",
    "Modelo 1",
    "Modelo 2",
    "Modelo 3",
    "Modelo 4",
    "Modelo 5"
  ),
  rmse_validation = c(
    rmse_m2,
    rmse_mod_1,
    rmse_mod_2,
    rmse_mod_3,
    rmse_mod_4,
    rmse_mod_5
  )
) |>
  dplyr::arrange(rmse_validation)

resultados_rmse

# Con los resultados obtenidos hasta ahora, Modelo 5 es el ganador PROVISIONAL.
# Sigue siendo provisional hasta incorporar el baseline de la Seccion 1.


# =============================================================================
# 7. PERFECT COLLINEARITY AND CLEAN MODEL 5
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
# 8. LOOCV - PROVISIONAL BEST MODEL
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
# 9. VARIABLE IMPORTANCE
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
# 9.1 OCCUPATION
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
# 9.2 HOURS WORKED
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
# 9.3 EMPLOYMENT RELATIONSHIP
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
# 9.4 FIRM SIZE
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
# 9.5 FORMAL EMPLOYMENT
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
# 9.6 SOCIOECONOMIC STRATUM
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
# 9.7 TENURE
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
# 9.8 GENDER
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
# 9.9 AGE
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
# 9.10 EDUCATION
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
# 9.11 VARIABLE IMPORTANCE RANKING
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

resultados_importancia

# Con los resultados obtenidos previamente, `horas` presenta el mayor aumento
# del RMSE al ser eliminada, seguida muy de cerca por `oficio_grupo` y
# `estrato`. Por nuestra definicion, `horas` es el predictor mas importante.


# =============================================================================
# 10. DEPENDENCE OF PREDICTIONS ON HOURS WORKED
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
# 10.1 PREDICTION DEPENDENCE CURVE
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
    x = "Hours worked",
    y = "Average predicted log income",
    title = "Predicted Labor Income and Hours Worked"
  ) +
  ggplot2::theme_minimal()

grafica_horas


# =============================================================================
# 11. PENDING: SECTION 1 BASELINE
# =============================================================================
# Cuando el equipo confirme la especificacion final de la Seccion 1:
#
#   1. Reestimarla usando `train`.
#   2. Predecir `ingreso_log` en `validation`.
#   3. Calcular su RMSE.
#   4. Agregarla a `resultados_rmse`.
#   5. Volver a seleccionar el modelo con menor RMSE.
#
# Si Modelo 5 limpio sigue siendo el ganador, los resultados de LOOCV,
# importancia y dependencia de predicciones permanecen como analisis final.
#
# Si el baseline de la Seccion 1 obtiene un RMSE menor, sera necesario repetir
# LOOCV e importancia de variables para ese nuevo modelo ganador.
# =============================================================================
