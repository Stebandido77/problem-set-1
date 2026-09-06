# Nota de procedencia: imputacion en `y_total_m` y el papel de `pulso`

**Alcance.** Esta nota responde una sola pregunta, acotada a proposito:
*¿`y_total_m` viene con imputacion por no respuesta?* Importa porque determina
que es exactamente el 10,75% de observaciones que excluimos, y eso se describe
distinto en las slides. Las demas preguntas sobre `pulso` (poblacion, tipo de
normalizacion, costo de la dependencia cruzada) quedan fuera.

**Muestra de referencia.** Salvo que se diga lo contrario, todas las cifras se
calculan sobre la **muestra de analisis final, N = 14.751**, la misma que
produce `construir_muestra_analisis()` y que se guarda en
`stores/processed/muestra_analisis.rds`. Es el unico N del repositorio.

> Una version previa de esta nota comparaba definiciones sobre las 14.764 filas
> que quedan justo despues del filtro de ingreso, es decir **antes** de los dos
> ultimos filtros de la cascada. Las 13 filas de diferencia son 12 excluidas por
> `totalHoursWorked > 112` y 1 por `maxEducLevel` faltante. Las cifras de abajo
> ya estan recalculadas sobre 14.751 y ninguna conclusion cambia.

El grupo excluido (1.778 filas) se mide, por construccion, en el paso de
la cascada donde se aplica el filtro de ingreso, sobre los 16.542 ocupados de
18 anos o mas.

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

| Candidato | Coincidencia exacta con `y_total_m` (N = 14.751) |
|---|---|
| `y_ingLab_m + y_gananciaIndep_m` | **14.751 / 14.751 (100,0%)** |
| `impa + isa` (sin imputar) | 14.237 (96,5%) |
| `impa` (sin imputar) | 14.206 (96,3%) |
| `ingtot` | 10.857 (73,6%) |
| `impaes + isaes` (imputado) | 2 (0,0%) |
| `impaes` (imputado) | **0 (0,0%)** |

`y_total_m` es exactamente la suma de los dos componentes laborales
construidos, y esos componentes siguen la serie **previa** a la imputacion. La
coincidencia con la serie imputada es nula.

Confirmacion por el otro lado: en la muestra final solo **20 observaciones
(0,14%)** tienen un valor en `impaes`.

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
**mediana 1.000.000 COP**, media 1.780.515 COP.

**Conclusion.** El grupo que excluimos **no** es el residuo que quedo despues
de que el DANE imputo. Es no respuesta bruta (y ceros reportados) en la
actividad principal, para la cual **el DANE si publica un valor imputado que la
variable construida del curso no incorpora**. En terminos de la MPMD, esas
personas si aparecerian en los agregados oficiales, con ingreso imputado.

## 4. La limitacion que esto impone

La justificacion de excluirlas es real: una autoridad tributaria observa lo
**reportado**, no lo imputado, de modo que estimar sobre la serie sin imputar
es coherente con el ejercicio. Pero tiene un costo que **no se puede
presentar como neutral**.

**Excluimos 1.451 personas que declararon ingreso laboral cero y a las que el
DANE asigna una mediana de 1.000.000 COP.** Su composicion esta sesgada
respecto a la muestra que si estimamos:

| Grupo | Muestra final | Los 1.451 excluidos |
|---|---|---|
| Independientes (`relab` 4 y 5) | 32,9% | **55,1%** |
| Informales (`formal == 0`) | 39,8% | 46,4% |
| Mujeres | 47,4% | 38,9% |

Los independientes estan sobrerrepresentados por un factor de 1,7 entre los
excluidos; los informales, de forma mas moderada.

La fila de mujeres **no** es tranquilizadora, es direccional: 38,9% de mujeres
entre los excluidos frente a 47,4% en la muestra significa que **removimos
desproporcionadamente hombres** (61,0% de los excluidos, frente a 52,6% de la
muestra). Eso es una amenaza especifica a la Seccion 2, porque la brecha se
estima sobre una muestra masculina depurada de los que reportaron cero.

**Cuantificacion.** Reestimando la brecha cruda sobre la muestra ampliada con
las 1.451 observaciones al ingreso imputado por el DANE (`impaes`, N = 16.201):

| Muestra | N | Brecha cruda |
|---|---|---|
| Base (solo ingreso observado) | 14.751 | **-0,2375** log points (-21,1%) |
| Ampliada con `impaes` | 16.201 | **-0,2426** log points (-21,5%) |

**La brecha se mueve -0,0051 log points (-0,4 pp): se vuelve levemente MAS
negativa.** El signo es el contrario al que sugiere la intuicion de "salieron
los hombres de peor desempeno", y la magnitud es pequena: la brecha observada
**subestima** la desventaja femenina en cerca de un 2% de su propio valor.

La intuicion falla porque los hombres excluidos no son de bajo ingreso: el
DANE les imputa una media de log 13,9935, **por encima** de la media masculina
observada (13,9808), mientras que a las mujeres excluidas les imputa 13,6929,
**por debajo** de la femenina observada (13,7433). Ambos efectos empujan en la
misma direccion y por eso la brecha se ensancha en lugar de encogerse.

Esto descansa en que la imputacion del DANE sea correcta; es un chequeo de
sensibilidad, no una cota. Pero como ejercicio de robustez es tranquilizador y
va en el deck de la Seccion 2, no enterrado aqui.

> **Limitacion.** El modelo, por construccion, **no puede detectar a quien
> declara cero**. Declarar cero es precisamente la forma extrema de
> subreportar, y es la conducta que una autoridad tributaria mas querria
> senalar. Al excluir esas 1.451 observaciones, el ejercicio queda condicionado
> a la poblacion que reporta un ingreso positivo: estimamos quien subreporta
> *en el margen*, no quien se declara fuera del sistema. La distorsion es mayor
> entre independientes, que es tambien donde la fiscalizacion es mas dificil.

Una extension natural, fuera del alcance de este problem set, seria reestimar
usando `impaes` para ese grupo y comparar cuanto se desplaza la cola baja de la
distribucion.

## 5. La serie no es autorreporte puro

El matiz del punto anterior. El apilamiento general en valores redondos es el
tipico del autorreporte y no evidencia imputacion: 57,7% multiplos de 1.000 y
41,2% multiplos de 100.000. Pero tres valores **no redondos** se repiten de
forma anomala:

| Valor | Frecuencia | Lectura |
|---|---|---|
| 869.453 | 332 | Constante calculada. Ningun caso tiene `impaes`; 318/332 son obreros de empresa particular y 278/332 formales. Rastro de un valor asignado dentro de la variable construida. |
| 781.242 | 266 | El SMMLV exacto de 2018. Legitimo: asalariados al minimo. |
| 930.929,4375 | 164 | **No es entero.** Solo puede ser un valor calculado. |

En conjunto **762 observaciones, el 5,17% de la muestra final**. No alteran
ninguna decision de limpieza, pero matizan el argumento del punto 4: aunque
`y_total_m` no usa la imputacion del DANE, **tampoco es autorreporte puro**;
tiene un componente construido. Al defender la exclusion de los ceros con el
argumento de "observamos lo reportado", conviene reconocer que la serie que si
estimamos ya trae valores asignados en cerca de una de cada veinte
observaciones.

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
