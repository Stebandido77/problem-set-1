# 30_prediction.R ------------------------------------------------------------
# Seccion 3: prediccion fuera de muestra.
#
#   - Particion: chunks 1-7 entrenamiento / chunks 8-10 validacion
#   - Baseline: las especificaciones de las Secciones 1 y 2
#   - Al menos 5 especificaciones adicionales (no linealidades, interacciones,
#     controles nuevos)
#   - Mejor modelo por RMSE de validacion, y despues LOOCV sobre entrenamiento
#     (con el atajo de la matriz sombrero, no reajustando n veces)
#   - Importancia de variables: hay que definir la medida y justificarla
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
source(here::here("scripts", "20_gender_gap.R"))

# -----------------------------------------------------------------------------
# 1. TRAIN / VALIDATION SPLIT
# -----------------------------------------------------------------------------
# Separamos la muestra de en dos partes/grupos:
#
# train: observaciones previamente usadas para estimar el modelo.
# validation: observaciones que se guardaran para analizar 
# que tan bueno es el modelo prediciendo fuerra de la muestra.

# Previamente la separación fuenida en la base mediante la variable `particion`.

train <- muestra_analisis |>
  dplyr::filter(particion == "entrenamiento")

validation <- muestra_analisis |>
  dplyr::filter(particion == "validacion")


# # Verificamos el número de observaciones en cada conjunto. Luego, comprobamos que
# los chunks asignados a entrenamiento y validacion sean los propuestos previamente.

nrow(train)
nrow(validation)

table(train$chunk_id)
table(validation$chunk_id)

# -----------------------------------------------------------------------------
# 2. RE-ESTIMATE SECTION 2 BASELINE
# -----------------------------------------------------------------------------
m2_train <- update(
  m2,
  data = train
)
m2_train

pred_m2 <- predict(
  m2_train,
  newdata = validation
)
# -----------------------------------------------------------------------------
# 3. RMSE Section 2 Model
#-----------------------------------------------------------------------------

rmse_m2 <- rmse(
  validation$ingreso_log,
  pred_m2
)

rmse_m2

#-----------------------------------------------------------------------------
# 4. Development of 5 additional models
#-----------------------------------------------------------------------------

mod_pred_1 <- lm(
  ingreso_log ~ mujer + age + edad_2 + educ + estrato +
    horas + relab_grupo,
  data = train
)

# al baseline de la Sección 2 le agregamos horas y relab_grupo.
# La idea es incorporar información directa del empleo: cuánto trabaja la persona
#y qué tipo de relación laboral tiene. No agregamos nueva no linealidad; el modelo sigue
#con age^2 como término cuadrático.

mod_pred_2 <- lm(
  ingreso_log ~ mujer + age + edad_2 + educ + estrato +
    horas + relab_grupo +
    antiguedad_meses + I(antiguedad_meses^2),
  data = train
)
#Mantenemos lo anterior y agregamos antiguedad_meses y antiguedad_meses^2.
#Aquí sí introducimos una nueva no linealidad: permitimos que la relación 
#Entre antigüedad e ingreso sea curva, no necesariamente constante.


mod_pred_3 <- lm(
  ingreso_log ~ mujer + age + edad_2 + educ + estrato +
    horas + relab_grupo +
    antiguedad_meses + I(antiguedad_meses^2) +
    tamano_empresa + formal + cuenta_propia + micro_empresa,
  data = train
)

#Agregamos tamano_empresa, formal, cuenta_propia y micro_empresa.
#La idea es incorporar información sobre el tipo de empresa en la que trabaja la persona.

mod_pred_4 <- lm(
  ingreso_log ~ mujer + age + edad_2 + educ + estrato +
    horas + relab_grupo +
    antiguedad_meses + I(antiguedad_meses^2) +
    tamano_empresa + formal + cuenta_propia + micro_empresa +
    oficio_grupo,
  data = train
)
# Agregamos oficio_grupo. Como es una variable categórica, R crea varias dummies. 
#  Esto   permite capturar diferencias salariales entre ocupaciones. 
#Puede aumentar bastante la complejidad del modelo aunque visualmente agreguemos una sola variable.

mod_pred_5 <- lm(
  ingreso_log ~ mujer + age + edad_2 + educ + estrato +
    horas + relab_grupo +
    antiguedad_meses + I(antiguedad_meses^2) +
    tamano_empresa + formal + cuenta_propia + micro_empresa +
    oficio_grupo +
    mujer:educ + age:educ,
  data = train
)

#Agregamos interacciones como mujer:educ y age:educ. 
#Aquí el cambio no es “más variables” solamente, sino permitir que la relación de una variable con 
#El ingreso dependa de otra. Por ejemplo, que la relación entre educación e ingreso sea distinta entre hombres y mujeres.

# -----------------------------------------------------------------------------
# 5 VALIDATION PREDICTIONS
# -----------------------------------------------------------------------------

pred_mod_1 <- predict(mod_pred_1, newdata = validation)
pred_mod_2 <- predict(mod_pred_2, newdata = validation)
pred_mod_3 <- predict(mod_pred_3, newdata = validation)
pred_mod_4 <- predict(mod_pred_4, newdata = validation)
pred_mod_5 <- predict(mod_pred_5, newdata = validation)


# -----------------------------------------------------------------------------
# 6.VALIDATION RMSE
# -----------------------------------------------------------------------------

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

# Resultados de RMSE ordenados de menos a mayor.

 rmse_validation = c(
    rmse_m2,
    rmse_mod_1,
    rmse_mod_2,
    rmse_mod_3,
    rmse_mod_4,
    rmse_mod_5
  )
  dplyr::arrange(rmse_validation)

resultados_rmse

# -----------------------------------------------------------------------------
# 7. LOOCV - PROVISIONAL BEST MODEL
# -----------------------------------------------------------------------------

rmse_loocv_m5 <- rmse_loocv(mod_pred_5)

rmse_loocv_m5

#-----------------------------------------------------------------------------
# 8. IMPORTANCE OF VARIABLES
#-----------------------------------------------------------------------------  
mod_sin_oficio <- update(
  mod_pred_5,
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

importancia_oficio <- rmse_sin_oficio - rmse_mod_5

rmse_sin_oficio
importancia_oficio

#Manteniendo el resto de la especificación de M5, eliminar oficio_grupo aumenta el RMSE de validación de 0.5814 a 0.6097. Por tanto, 
#la ocupación aporta información relevante para predecir el ingreso laboral.

mod_sin_horas <- update(
  mod_pred_5,
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

importancia_horas <- rmse_sin_horas - rmse_mod_5

rmse_sin_horas
importancia_horas

mod_sin_relab <- update(
  mod_pred_5,
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

importancia_relab <- rmse_sin_relab - rmse_mod_5

rmse_sin_relab
importancia_relab

mod_sin_tamano <- update(
  mod_pred_5,
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

importancia_tamano <- rmse_sin_tamano - rmse_mod_5

rmse_sin_tamano
importancia_tamano

mod_sin_cuenta <- update(
  mod_pred_5,
  . ~ . - cuenta_propia,
  data = train
)

pred_sin_cuenta <- predict(
  mod_sin_cuenta,
  newdata = validation
)

rmse_sin_cuenta <- rmse(
  validation$ingreso_log,
  pred_sin_cuenta
)

# 

importancia_cuenta <- rmse_sin_cuenta - rmse_mod_5

rmse_sin_cuenta
importancia_cuenta

# Esta variable tiene colinealidad perfecta.

mod_pred_5_clean <- update(
  mod_pred_5,
  . ~ . - cuenta_propia - micro_empresa,
  data = train
)
# Eliminamos la variable del maneja original.

# -----------------------------------------------------------------------------
# VARIABLE IMPORTANCE: ESTRATO
# -----------------------------------------------------------------------------
# Eliminamos estrato del Modelo 5 limpio y evaluamos cuanto aumenta
# el RMSE de validacion.

mod_sin_estrato <- update(
  mod_pred_5_clean,
  . ~ . - estrato,
  data = train
)

pred_sin_estrato <- predict(
  mod_sin_estrato,
  newdata = validation
)
# -----------------------------------------------------------------------------
# VARIABLE IMPORTANCE: MUJER
# -----------------------------------------------------------------------------
# Mujer aparece como efecto principal y tambien interactua con educacion.
# Para medir su importancia completa eliminamos ambos componentes.

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
rmse_sin_estrato <- rmse(
  validation$ingreso_log,
  pred_sin_estrato
)

importancia_estrato <- rmse_sin_estrato - rmse_m5_clean

rmse_sin_estrato
importancia_estrato

# -----------------------------------------------------------------------------
# VARIABLE IMPORTANCE: EDAD
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
# VARIABLE IMPORTANCE: EDAD
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
# VARIABLE IMPORTANCE: EDUCACION
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
# 8. DEPENDENCE OF PREDICTIONS ON THE MOST IMPORTANT VARIABLE
# -----------------------------------------------------------------------------

coef(mod_pred_5_clean)["horas"]

# =============================================================================
# 8. DEPENDENCE OF PREDICTIONS ON HOURS WORKED
# =============================================================================
# `horas` was identified as the most important predictor according to the
# increase in validation RMSE when the variable was removed.
#
# We now characterize how the predictions of the best model depend on hours
# worked.
#
# For each possible value of `horas`, we keep all other characteristics of
# the validation observations unchanged, replace only `horas`, generate
# predictions, and calculate the average predicted log income.
#
# We restrict the graph to the central 90% of observed hours to avoid letting
# extreme observations dominate the visualization.

horas_grid <- seq(
  from = quantile(validation$horas, 0.05, na.rm = TRUE),
  to   = quantile(validation$horas, 0.95, na.rm = TRUE),
  length.out = 100
)

pred_promedio_horas <- sapply(
  horas_grid,
  function(h) {

    datos_h <- validation

    # Change only hours worked
    datos_h$horas <- h

    # Predict log income with Model 5
    pred_h <- predict(
      mod_pred_5_clean,
      newdata = datos_h
    )

    # Average prediction
    mean(pred_h, na.rm = TRUE)
  }
)

dependencia_horas <- tibble::tibble(
  horas = horas_grid,
  ingreso_log_predicho = pred_promedio_horas
)

ggplot2::ggplot(
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

  