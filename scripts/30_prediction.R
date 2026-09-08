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

train <- muestra_analisis |>
  dplyr::filter(particion == "entrenamiento")

validation <- muestra_analisis |>
  dplyr::filter(particion == "validacion")


# Check partition
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
) |>
  dplyr::arrange(rmse_validation)

resultados_rmse