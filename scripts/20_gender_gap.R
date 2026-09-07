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

# Cargar funciones auxiliares y datos procesados
source(here::here("scripts", "02_cleaning.R"))
source(here::here("scripts", "functions", "edad_pico.R"))

# -----------------------------------------------------------------------------
# 1. Especificaciones de Regresión
# -----------------------------------------------------------------------------

# (1) Incondicional
m1 <- lm(ingreso_log ~ mujer, data = muestra_analisis)

# (2) Condicional Preferido (Capital Humano / Predeterminadas)
m2 <- lm(ingreso_log ~ mujer + age + edad_2 + educ + estrato, data = muestra_analisis)

# (3) Modelo Condicional con Bad Controls (Características del Puesto)
m3 <- lm(
  ingreso_log ~ mujer + age + edad_2 + educ + estrato +
    factor(oficio_grupo) + tamano_empresa + factor(relab_grupo),
  data = muestra_analisis
)

# -----------------------------------------------------------------------------
# 2. Descomposición Frisch-Waugh-Lovell (FWL)
# -----------------------------------------------------------------------------

res_mujer <- residuals(lm(mujer ~ age + edad_2 + educ + estrato, data = muestra_analisis))
res_y     <- residuals(lm(ingreso_log ~ age + edad_2 + educ + estrato, data = muestra_analisis))
m2_fwl    <- lm(res_y ~ res_mujer - 1)

cat("--- VERIFICACIÓN TEORÍA FWL ---\n")
cat("Coeficiente de 'mujer' en regresión múltiple (m2): ", coef(m2)["mujer"], "\n")
cat("Coeficiente de 'res_mujer' en regresión FWL:        ", coef(m2_fwl)["res_mujer"], "\n\n")

# -----------------------------------------------------------------------------
# 3. Errores Estándar Analíticos vs. Bootstrap
# -----------------------------------------------------------------------------

boot_brecha <- function(data, indices) {
  d <- data[indices, ]
  m <- lm(ingreso_log ~ mujer + age + edad_2 + educ + estrato, data = d)
  return(coef(m)["mujer"])
}

set.seed(1234)
res_boot_brecha <- boot(data = muestra_analisis, statistic = boot_brecha, R = 1000)

se_analitico_m2 <- sqrt(diag(vcovHC(m2, type = "HC1")))["mujer"]
se_bootstrap_m2 <- sd(res_boot_brecha$t)

cat("--- ERRORES ESTÁNDAR PARA LA BRECHA EN M2 ---\n")
cat("Error estándar HC1 analítico: ", se_analitico_m2, "\n")
cat("Error estándar Bootstrap:     ", se_bootstrap_m2, "\n\n")

# -----------------------------------------------------------------------------
# 4. Exportar Tabla Comparativa de Regresiones a views/tables/
# -----------------------------------------------------------------------------

modelos <- list(
  "(1) Incondicional" = m1,
  "(2) Preferido"     = m2,
  "(3) Bad Controls"  = m3
)

dir.create(here::here("views", "tables"), showWarnings = FALSE, recursive = TRUE)

msummary(
  modelos,
  vcov = "HC1",
  stars = TRUE,
  gof_omit = "AIC|BIC|Log.Lik|F",
  title = "Comparación de la Brecha de Ingreso Laboral por Género",
  output = here::here("views", "tables", "tabla_brecha_genero.html")
)

# -----------------------------------------------------------------------------
# 5. Edad Pico e Intervalos de Confianza por Percentiles (Bootstrap)
# -----------------------------------------------------------------------------

boot_edad_pico <- function(data, indices) {
  d <- data[indices, ]
  
  m_h <- lm(ingreso_log ~ age + edad_2 + educ + estrato, data = dplyr::filter(d, mujer == 0))
  m_m <- lm(ingreso_log ~ age + edad_2 + educ + estrato, data = dplyr::filter(d, mujer == 1))
  
  pico_h <- edad_pico(m_h, "age", "edad_2")
  pico_m <- edad_pico(m_m, "age", "edad_2")
  
  return(c(pico_hombres = pico_h, pico_mujeres = pico_m))
}

set.seed(1234)
res_boot_picos <- boot(data = muestra_analisis, statistic = boot_edad_pico, R = 1000)

ic_hombres <- boot.ci(res_boot_picos, type = "perc", index = 1)
ic_mujeres <- boot.ci(res_boot_picos, type = "perc", index = 2)

cat("--- EDAD PICO E INTERVALOS DE CONFIANZA (BOOTSTRAP) ---\n")
cat("Edad pico hombres: ", round(res_boot_picos$t0[1], 4),
    " con IC 95%: [", round(ic_hombres$percent[4], 4), ", ", round(ic_hombres$percent[5], 4), "]\n")
cat("Edad pico mujeres: ", round(res_boot_picos$t0[2], 4),
    " con IC 95%: [", round(ic_mujeres$percent[4], 4), ", ", round(ic_mujeres$percent[5], 4), "]\n\n")

# -----------------------------------------------------------------------------
# 6. Gráfico de Perfiles Edad-Ingreso Predichos y Exportación (CORREGIDO)
# -----------------------------------------------------------------------------

# Usamos I(age^2) directamente en la fórmula para que R reconozca el término cuadrático dinámico
m2_interact <- lm(
  ingreso_log ~ mujer * (age + I(age^2)) + educ + estrato, 
  data = muestra_analisis
)

# Filtramos la malla hasta los 65 o 70 años (fuerza laboral activa habitual)
edad_max_grafica <- min(max(muestra_analisis$age, na.rm = TRUE), 70)

# Generar predicciones marginales
grid_edad_preds <- predictions(
  m2_interact,
  newdata = datagrid(
    age = seq(18, edad_max_grafica, by = 1),
    mujer = c(0, 1)
  )
)

# Construcción de la gráfica
p_edad <- ggplot(grid_edad_preds, aes(x = age, y = estimate, color = factor(mujer))) +
  geom_line(size = 1.2) +
  geom_vline(xintercept = res_boot_picos$t0[1], linetype = "dashed", color = "navy") +
  geom_vline(xintercept = res_boot_picos$t0[2], linetype = "dashed", color = "darkred") +
  scale_color_manual(values = c("0" = "navy", "1" = "darkred"), labels = c("Hombres", "Mujeres")) +
  labs(
    title = "Perfiles Edad-Ingreso Predichos por Género",
    subtitle = "Predicciones promedio ajustadas sobre las características de la muestra (Líneas punteadas = Edades pico)",
    x = "Edad (Años)",
    y = "Log(Ingreso Laboral Mensual)",
    color = "Género"
  ) +
  theme_minimal()

# Guardar la gráfica corregida
dir.create(here::here("views", "figures"), showWarnings = FALSE, recursive = TRUE)

ggsave(
  here::here("views", "figures", "perfil_edad_ingreso.png"), 
  plot = p_edad, 
  width = 8, 
  height = 5
)