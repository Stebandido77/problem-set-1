# 10_age_profile.R -----------------------------------------------------------
# Seccion 1: perfil edad-ingreso laboral.
#
#   (1) Incondicional:  log(w) = b1 + b2*age + b3*age^2 + u
#   (2) Condicional:    + totalHoursWorked + relab
#   (3) Edad pico = -b2 / (2*b3), con intervalo de confianza bootstrap.
#
# POR QUE EL CUADRATICO
# Las medias de log(y_total_m) por edad dibujan un perfil concavo: el ingreso
# sube, se aplana y cae (ver `views/figures/ingreso_por_edad.png`). Un termino
# lineal no puede representar ese descenso final, y sin el no existe una edad
# pico que reportar.
#
# POR QUE LA ESPECIFICACION CONDICIONAL CONTROLA POR HORAS Y POSICION
# Las horas trabajadas varian a lo largo del ciclo de vida. Sin controlarlas,
# el perfil de edad absorbe variacion en OFERTA LABORAL y no en el salario, y
# la edad pico deja de ser interpretable como el pico del precio del trabajo.
# `relab` (posicion ocupacional) cumple el mismo papel: la composicion entre
# asalariados e independientes cambia con la edad.
#
# La lectura de las dos especificaciones no es la misma y conviene decirlo en
# las slides: la incondicional describe el perfil de INGRESO observado, la
# condicional se acerca al perfil del PRECIO del trabajo.
#
# POR QUE LA EDAD PICO NECESITA BOOTSTRAP
# Es una razon de coeficientes, no un coeficiente: `lm()` no reporta su error
# estandar y el metodo delta se degrada porque el denominador esta cerca de
# cero. El detalle esta documentado en `scripts/functions/edad_pico.R`.
# ----------------------------------------------------------------------------

source(here::here("scripts", "02_cleaning.R"))
source(here::here("scripts", "functions", "edad_pico.R"))
