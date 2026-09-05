# Problem Set 1 — Predicting Income (Equipo XX)

**MECA 4107 · Big Data and Machine Learning para Economia Aplicada · 2026-20**
Universidad de los Andes — Facultad de Economia

Modelos de ingreso laboral individual con microdatos de la **GEIH 2018 (Bogota)**,
orientados a la pregunta: *que puede decirle un modelo de ingreso laboral a la
autoridad tributaria sobre quien podria estar subreportando, y donde fallan sus
predicciones?*

## Integrantes

| Nombre | Usuario GitHub | Correo |
|---|---|---|
| — | — | — |
| — | — | — |
| — | — | — |

## Estructura del repositorio

```
.
├── README.md
├── PS1.Rproj              # Proyecto de RStudio (define el working directory)
├── document/              # Slides (.qmd -> .pdf) de las tres secciones
│   ├── age_equipo_XX.qmd
│   ├── gap_equipo_XX.qmd
│   └── pred_equipo_XX.qmd
├── scripts/
│   ├── 00_packages.R      # Carga/instala dependencias
│   ├── 01_scraping.R      # Scraping de los 10 chunks (polite)
│   ├── 02_cleaning.R      # Muestra de analisis: ocupados, 18+, tratamiento de NA y ceros
│   ├── 03_descriptives.R  # Estadisticas descriptivas que motivan las especificaciones
│   ├── 10_age_profile.R   # Seccion 1
│   ├── 20_gender_gap.R    # Seccion 2 (FWL + bootstrap)
│   ├── 30_prediction.R    # Seccion 3 (validation set, LOOCV, importancia)
│   ├── 99_run_all.R       # Pipeline completo de reproduccion
│   └── functions/         # Funciones reutilizables
├── stores/
│   ├── raw/               # Chunks descargados (NO versionado)
│   └── processed/         # Muestra de analisis limpia
└── views/
    ├── figures/           # Graficas exportadas
    └── tables/            # Tablas exportadas (LaTeX / .tex)
```

## Reproduccion

```bash
git clone https://github.com/<org-o-usuario>/problem-set-1.git
cd problem-set-1
Rscript scripts/99_run_all.R
```

El pipeline descarga los datos, construye la muestra, corre las tres secciones y
exporta tablas y figuras a `views/`.

**Tiempo aproximado: 2 min** desde un clone limpio con `stores/raw/` vacio
(medido de punta a punta: 1 min 59 s, incluye la descarga de ~227 MB de HTML
crudo). Una segunda corrida tarda **20 s**: el scraper reutiliza el cache en
disco y no emite ninguna peticion.

## Datos

Microdata de Bogota del reporte *Medicion de Pobreza Monetaria y Desigualdad* (2018),
basada en la GEIH: <https://ignaciomsarmiento.github.io/GEIH2018_sample/>.
Distribuidos en 10 chunks. Variable de resultado: `y_total_m`.

> **Procedencia.** El sitio del curso enlaza al catalogo DANE 547, *Gran Encuesta
> Integrada de Hogares - GEIH - 2018* (<https://microdatos.dane.gov.co/index.php/catalog/547>);
> la MPMD es el reporte construido a partir de esa encuesta, de modo que ambas
> descripciones apuntan a la misma fuente.

**Particion (Seccion 3):** chunks 1–7 = entrenamiento · chunks 8–10 = validacion.

### Glosario de variables

Dos convenciones de nombres conviven a proposito en el mismo data frame, y el
estilo es la senal de a quien pertenece cada columna:

- **Columnas del DANE**: nombre original, `camelCase` incluido. No se pasan por
  `janitor::clean_names()` ni se traducen, para que sigan correspondiendo uno a
  uno con el diccionario del curso y con el enunciado.
- **Columnas del equipo**: `snake_case` en espanol, construidas en
  `scripts/02_cleaning.R`.

Los 10 chunks crudos traen 178 columnas; la muestra de analisis conserva 27.
Las definiciones de abajo se verificaron contra el dato, no se supusieron.

#### Variables del DANE

| Variable | Que es | Valores observados |
|---|---|---|
| `y_total_m` | **Outcome.** Ingreso laboral mensual total. Suma exacta de `y_ingLab_m + y_gananciaIndep_m` (coincide en el 100% de la muestra) y sigue la serie **sin imputar**: solo 20 filas (0,14%) tienen valor en `impaes`. | Numerica. Sin ceros exactos, solo `NA` |
| `y_total_m_ha` | Ingreso laboral **por hora**. Es exactamente `y_total_m / (4,2857 * totalHoursWorked)`, es decir 30/7 semanas por mes. | Numerica |
| `ocu` | Ocupado en la semana de referencia. Define la muestra base. | `0`, `1` |
| `age` | Edad en anos cumplidos. | `0`–`95` en el crudo |
| `sex` | Sexo. **`1` = hombre, `0` = mujer.** De aqui sale `mujer`. | `0`, `1` |
| `relab` | Posicion ocupacional. Documentados por el uso que se les da: `4` cuenta propia (coincide exactamente con `cuentaPropia == 1`), `5` patron o empleador, `6` y `7` trabajo no remunerado, `8` jornalero (1 sola observacion), `9` otro. `NA` exactamente cuando `ocu != 1`. | `1`–`9` |
| `oficio` | Codigo de ocupacion. 79 niveles llegan a la muestra de analisis; los raros se colapsan en `oficio_grupo`. | `2`–`99` |
| `maxEducLevel` | Nivel educativo maximo alcanzado. La codificacion **no es monotona**: `college == 1` coincide exactamente con `maxEducLevel == 6`, no con el `7`. Las etiquetas se leen del diccionario del curso; aqui entra siempre como factor, nunca como numero. | `1`–`7` |
| `sizeFirm` | Tamano de la empresa. `microEmpresa == 1` coincide exactamente con `sizeFirm` en `{1, 2}`. | `1`–`5` |
| `estrato1` | Estrato socioeconomico de la vivienda. Entra como factor: la distancia entre estratos no es cardinal. | `1`–`6` |
| `cotPension` | Cotizacion a pension. `2` corresponde siempre a `formal == 0`; `1` y `3` a `formal == 1` salvo 73 de 16.663 filas (0,4%). | `1`, `2`, `3` |
| `p6426` | Antiguedad en el trabajo actual, en meses. Se renombra a `antiguedad_meses`. | `0`–`600` |
| `totalHoursWorked` | Horas efectivamente trabajadas en la semana. Control en la Seccion 1, predictor en la Seccion 3. | `2`–`130` en el crudo |
| `hoursWorkUsual` | Horas que la persona trabaja habitualmente. | `2`–`130` |
| `formal` | Indicador de formalidad. | `0`, `1` |
| `college` | Educacion superior. Equivale a `maxEducLevel == 6`. | `0`, `1` |
| `cuentaPropia` | Trabajador por cuenta propia. Equivale a `relab == 4`. | `0`, `1` |
| `microEmpresa` | Micro empresa. Equivale a `sizeFirm` en `{1, 2}`. | `0`, `1` |
| `fex_c` | Factor de expansion del diseno muestral. **No se aplica**; se conserva para el chequeo ponderado de la Seccion 2. | `129,45`–`477,97` |
| `fweight` | El mismo factor redondeado: `fweight == round(fex_c)` en el 100% de las filas. | `129`–`478` |
| `mes` | Mes de la encuesta. **Nunca es predictor**: filtra la particion. | `1`–`12` |
| `directorio`, `secuencia_p`, `orden` | Identificadores de vivienda, hogar y persona. Se conservan solo para rastrear una fila hasta el dato crudo. | Enteros |
| `chunk_id` | Numero de chunk, agregado por `01_scraping.R`. Ordenado por mes (chunk 1 = ene-feb ... chunk 10 = nov-dic), asi que **nunca es predictor**. | `1`–`10` |
| `impa`, `impaes` | Ingreso de la actividad principal, antes y despues de la imputacion del DANE. No entran a la muestra: se usan solo en el chequeo de seleccion de `document/notas_pulso.md`. | Numericas |

#### Variables construidas por el equipo

| Variable | Definicion | Por que |
|---|---|---|
| `ingreso_log` | `log(y_total_m)` | Outcome de las tres secciones. En niveles la asimetria es 8,49; en logaritmos, -0,348 |
| `mujer` | `as.integer(sex == 0)` | Invierte la codificacion del DANE para que el coeficiente de la Seccion 2 se lea directo como brecha femenina |
| `edad_2` | `age^2` | Sin el cuadratico no hay edad pico que estimar |
| `relab_grupo` | `relab`, con el `8` plegado en el `9` | `relab == 8` tiene 1 sola observacion de entrenamiento: apalancamiento 1 y LOOCV infinito |
| `oficio_grupo` | `oficio`, con los niveles de menos de 30 obs. **en chunks 1-7** colapsados en `"otros"` | Umbral aprendido solo en entrenamiento. Sobreviven 50 niveles, se colapsan 29, `"otros"` queda con el 2,8% |
| `educ` | `factor(maxEducLevel)` | Codificacion no cardinal |
| `tamano_empresa` | `factor(sizeFirm)` | Codificacion no cardinal |
| `estrato` | `factor(estrato1)` | Codificacion no cardinal |
| `cot_pension` | `factor(cotPension)` | Codificacion no cardinal |
| `antiguedad_meses` | `p6426` | Renombre legible |
| `horas` | `totalHoursWorked` | Renombre legible |
| `horas_usuales` | `hoursWorkUsual` | Renombre legible |
| `particion` | `"entrenamiento"` si `chunk_id` esta en 1–7, si no `"validacion"` | Determinista y temporal, no aleatoria: no depende de la semilla |

## Decisiones de limpieza

Todas viven en `construir_muestra_analisis()` dentro de `scripts/02_cleaning.R`, que
es la unica fuente de verdad para las tres secciones. La cascada completa
se exporta a `views/tables/construccion_muestra.tex`.

| Decision | Criterio | Costo | Justificacion |
|---|---|---|---|
| Ocupados | `ocu == 1` | 15.495 (48,16%) | Enunciado |
| Edad | `age >= 18` | 140 (0,84%) | Enunciado |
| Ingreso faltante | excluir, nunca imputar | 1.778 (10,75%) | `y_total_m` no registra ceros exactos, solo `NA`. 248 son `relab` 6/7 (trabajo no remunerado), faltantes por construccion. Imputar exigiria un modelo de ingreso, que es el objeto de estimacion. |
| Cola alta | **no se toca** | 0 | El ejercicio es la deteccion de subreporte por una autoridad tributaria: la cola alta es la poblacion de interes. Sin top-coding, winsorizacion ni recorte por percentil. |
| Piso de ingreso | no se aplica en la muestra base | 0 | El argumento `piso_ingreso` permite reestimar las especificaciones como chequeo de robustez (con `piso_ingreso = 500` la muestra baja a 14.680). |
| Horas implausibles | `totalHoursWorked <= 112` | 12 (0,08%) | 16 h/dia x 7 dias. El ingreso reportado es plausible; el error esta en las horas, que son control en la Seccion 1 y predictor en la Seccion 3. |
| Educacion faltante | excluir | 1 (0,01%) | Control central. |
| Factor de expansion | **no se aplica** | 0 | La Seccion 3 se evalua por RMSE no ponderado. La inferencia ponderada valida exige estratos y UPM, que este sample no publica. `fex_c` se conserva como columna para el chequeo ponderado de la Seccion 2. |
| Niveles raros de `oficio` | colapsar en `"otros"` si tienen < 30 obs **en chunks 1-7** | 29 niveles, 2,8% | El umbral se calcula solo en entrenamiento y se aplica a validacion, de modo que el fold de validacion nunca informa la codificacion. |
| `relab == 8` | colapsar en `relab == 9` ("otro") | 1 obs recodificada | Un unico caso en entrenamiento: se ajustaria perfectamente y desapareceria bajo LOOCV. |

**Muestra final: 14.751 observaciones** (10.255 entrenamiento, 4.496 validacion).

### Regla del equipo: el `.rds` viaja con el script

`stores/processed/muestra_analisis.rds` **si** se versiona. Lleva un atributo
`meta` con el `N` final, la fecha de generacion y un hash SHA-256 de las reglas
de limpieza (digest del cuerpo de `construir_muestra_analisis()`).

> **Cualquier cambio a `scripts/02_cleaning.R` se commitea junto con el `.rds`
> regenerado, nunca por separado.**

Al cargar la muestra, `02_cleaning.R` imprime esa metadata y **advierte** si el
hash almacenado no coincide con el script actual:

```
--- analysis sample metadata ---
  N observations : 14751
  generated at   : 2026-09-03 13:34:05
  cleaning rules : b05214a0920f643f...
  piso_ingreso   : NULL (base sample)
  oficio_n_min   : 30 | horas_max: 112
```

Si ves `muestra_analisis.rds was built with DIFFERENT cleaning rules`, corre
`Rscript scripts/02_cleaning.R` y commitea el `.rds` resultante en el mismo
commit que el cambio al script.

Se mantiene en `.rds` a proposito: `.gitignore` tiene una regla `*.csv.gz` que
dejaria un export comprimido fuera del repositorio sin avisar.

## Flujo de trabajo con Git

- `main` protegido: nada se mergea sin pull request.
- Ramas: `feat/age-profile`, `feat/gender-gap`, `feat/prediction`, `fix/...`.
- Commits en ingles siguiendo conventional commits (ver `.gitmessage`).
- Cada integrante debe registrar al menos **5 contribuciones sustanciales** a `main`.
