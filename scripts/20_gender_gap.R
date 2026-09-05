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

source(here::here("scripts", "02_cleaning.R"))
source(here::here("scripts", "functions", "edad_pico.R"))
