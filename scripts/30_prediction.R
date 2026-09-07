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