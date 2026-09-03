# Nota de procedencia: imputacion en `y_total_m` y el papel de `pulso`

**Alcance.** Esta nota responde una sola pregunta, acotada a proposito:
*¿`y_total_m` viene con imputacion por no respuesta?* Importa porque determina
que es exactamente el 10,75% de observaciones que excluimos, y eso se describe
distinto en las slides. Las demas preguntas sobre `pulso` (poblacion, tipo de
normalizacion, costo de la dependencia cruzada) quedan fuera.

Todas las cifras salen de correr `scripts/01_scraping.R` y consultas sobre
`stores/raw/chunk_*.rds`. Universo de referencia: ocupados de 18 anos o mas,
N = 16.542.

---

## 1. La GEIH si trae imputacion, y el sample del curso la publica

El diccionario del curso documenta pares antes/despues de imputacion para cada
componente de ingreso:

| Antes de imputacion | Imputado | Definicion del diccionario |
|---|---|---|
| `impa` | `impaes` | Ingreso monetario de la primera actividad |
| `isa` | `isaes` | Ingreso monetario de la segunda actividad |
| `ie` | `iees` | Ingreso en especie |
| `iof1`, `iof2`, `iof6` | `iof1es`, `iof2es`, `iof6es` | Intereses, pensiones, arriendos |
| `ingtotob` | `ingtotes` | Ingreso total observado / imputado |

Las variables `*es` se describen como *"imputado (solo para faltantes o
extremos)"*. Es decir: la imputacion del DANE **esta disponible en el dataset**.

## 2. Pero `y_total_m` esta construida sobre la serie SIN imputar

| Candidato | Coincidencia exacta con `y_total_m` (N = 14.764) |
|---|---|
| `y_ingLab_m + y_gananciaIndep_m` | **14.764 / 14.764 (100,0%)** |
| `impa + isa` (sin imputar) | 14.249 (96,5%) |
| `impa` (sin imputar) | 14.218 (96,3%) |
| `ingtot` | 10.869 (73,6%) |
| `impaes + isaes` (imputado) | 2 (0,0%) |
| `impaes` (imputado) | **0 (0,0%)** |

`y_total_m` es exactamente la suma de los dos componentes laborales
construidos, y esos componentes siguen la serie **previa** a la imputacion. La
coincidencia con la serie imputada es nula.

Confirmacion por el otro lado: en la muestra que conservamos, solo **20
observaciones (0,14%)** tienen un valor en `impaes`. **Nuestra muestra de
analisis esta practicamente libre de imputacion.**

## 3. Que es entonces el 10,75% que excluimos

De las 1.778 filas con `y_total_m` faltante:

| Grupo | N | `impa` | `impaes` (imputado por DANE) |
|---|---|---|---|
| Trabajadores sin remuneracion (`relab` 6 y 7) | 248 | `NA` | ninguno |
| Reportan cero en la actividad principal | 1.529 | `= 0` | **1.451 (94,9%)** |
| Otro | 1 | `> 0` | ninguno |

El cruce es limpio: de las 1.529 con `impa == 0`, el DANE imputo 1.451 y dejo
78 sin imputar; ninguno de los 248 trabajadores no remunerados recibio
imputacion, como corresponde. Los valores imputados son ingresos plausibles:
mediana 1.000.000 COP, media 1.780.515 COP.

**Conclusion.** El grupo que excluimos **no** es el residuo que quedo despues
de que el DANE imputo. Es no respuesta bruta (y ceros reportados) en la
actividad principal, para la cual **el DANE si publica un valor imputado que la
variable construida del curso no incorpora**. En terminos de la MPMD, esas
personas si aparecerian en los agregados oficiales, con ingreso imputado.

### Como se describe en las slides

> Se excluye el 10,75% de los ocupados adultos sin ingreso laboral observado.
> No es el residuo posterior a la imputacion del DANE: `y_total_m` se construye
> sobre la serie previa a imputar, de modo que el grupo excluido es no
> respuesta bruta, para la cual el DANE si publica un valor imputado
> (`impaes`, disponible para el 81,6% de ellos) que la variable del curso no
> usa. La contrapartida es que la muestra estimada esta libre de imputacion
> (0,14% con `impaes`), lo cual es coherente con el ejercicio: una autoridad
> tributaria observa lo reportado, no lo imputado.

## 4. Rastro de redondeo

El apilamiento en valores redondos es el tipico del autorreporte y no evidencia
imputacion: 57,7% multiplos de 1.000 y 41,2% multiplos de 100.000.

Tres valores no redondos si se repiten de forma anomala:

| Valor | Frecuencia | Lectura |
|---|---|---|
| 869.453 | 332 | Constante calculada. Ningun caso tiene `impaes`; 318/332 son obreros de empresa particular y 278/332 formales. Rastro de un valor asignado dentro de la variable construida, no de autorreporte. |
| 781.242 | 266 | El SMMLV exacto de 2018. Legitimo: asalariados al minimo. |
| 930.929,4375 | 164 | **No es entero.** Solo puede ser un valor calculado. |

Son pocos casos (762 en total, 5,2%) y no alteran las decisiones de limpieza,
pero conviene no presentarlos como ingreso autorreportado puro.

---

## Veredicto sobre `pulso`: **usar solo para validar**

`pulso` no puede sustituir ni reconstruir el outcome, por una razon de
definicion, no de implementacion:

- `pulso` mapea `ingreso_laboral` a `INGLABO` con `transform: "identity"`, que
  en el diccionario del DANE es ingreso **imputado** de la actividad principal.
  `y_total_m` es la serie **sin imputar**, suma de asalariado e independiente
  sobre todas las ocupaciones. **No son la misma cantidad.**
- `ingreso_total` de `pulso` mapea a `INGTOT`, que incluye ingreso no laboral.
  Tampoco corresponde.
- Ninguna de las 30 variables canonicas de `pulso` cubre la familia `y_*_m`
  construida para este curso.

Usar `pulso` como fuente cambiaria la definicion del outcome y invalidaria la
comparacion con el enunciado. Su valor es como **capa de validacion**:
diccionario de variables y contraste de la distribucion de ingreso contra la
GEIH 2018 oficial.

Dos limitaciones adicionales que acotan incluso ese uso, verificadas en el
repositorio de `pulso`:

1. Ninguno de los 12 meses de 2018 esta marcado `validated: true` en
   `data/sources.json` (solo 5 de 230 entradas lo estan), asi que
   `pulso_load()` rechaza esos periodos salvo `allow_unvalidated = TRUE`.
2. El filtro por area **no esta implementado** en la version 0.1.0, de modo que
   no se puede restringir a Bogota de forma programatica.

No hay barrera de lenguaje: `pulso` incluye un paquete de R real bajo `R/`
(exporta `pulso_load`, `pulso_describe_variable`, entre otras), asi que la
integracion no exigiria `reticulate`. La razon para no usarlo es de definicion
del outcome, no de tooling.
