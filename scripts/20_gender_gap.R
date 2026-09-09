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
      strwrap(
        paste(
          "Predicciones promedio ajustadas sobre las características de la muestra",
          "(Líneas punteadas = Edades pico).",
          "Edad Pico Mujeres: 40.13 años. Edad Pico Hombres: 44.47 años"
        ),
        width = 75
      ),
      collapse = "\n"
    ),
    x = "Edad (Años)",
    y = "Log(Ingreso Laboral Mensual)",
    color = "Género"
  ) +
  theme_minimal() + # Tema visual minimalista para la gráfica.
  theme(plot.subtitle = element_text(hjust = 0, lineheight = 1.1))

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