# Problem Set 1 — Predicting Income (Equipo 06)

**MECA 4107 · Big Data and Machine Learning para Economía Aplicada · 2026-20**
Universidad de los Andes — Facultad de Economía

Modelos de ingreso laboral individual con microdatos de la **GEIH 2018 (Bogotá)**,
orientados a la pregunta que organiza el problem set:

> *Qué puede decirle un modelo de ingreso laboral a la autoridad tributaria sobre
> quién podría estar subreportando, y dónde fallan sus predicciones?*

La respuesta corta está en la sección [Hallazgos principales](#hallazgos-principales):
el modelo más predictivo reduce el error en 36,5% frente a no usar ningún
regresor, mientras que el perfil edad-ingreso — el más interpretable — lo reduce
en 2,5%. Esa distancia entre interpretabilidad y capacidad predictiva es el
resultado transversal del trabajo.

## Integrantes

| Nombre | Usuario GitHub |
|---|---|
| Neislen García | `NeislenG` |
| Diego Felipe Rodríguez | `dfeliperodriguezv-create` |
| Esteban Labastidas | `Stebandido77` |

## Hallazgos principales

| Sección | Hallazgo | Cifra |
|---|---|---|
| **1 — Edad** | Edad pico del ingreso mensual, incondicional | **40,62** años, IC 95% [40,06; 41,17] |
| **1 — Edad** | Edad pico a horas y posición fijas | **43,61** años, IC 95% [42,88; 44,37] |
| **1 — Edad** | Desplazamiento al condicionar (intervalos disjuntos) | **+2,99** años |
| **2 — Brecha** | Brecha de género cruda | **-0,2375** log points (-21,1%) |
| **2 — Brecha** | Brecha condicional (edad, educación, estrato) | **-0,3201** log points (-27,4%) |
| **2 — Brecha** | Errores estándar: analítico HC1 vs. bootstrap | **0,01217** vs. **0,01215** |
| **2 — Brecha** | Edad pico por sexo (intervalos disjuntos) | H **44,5** / M **40,1** años |
| **3 — Predicción** | Mejor modelo, RMSE de validación | Modelo 5 limpio, **0,5814** |
| **3 — Predicción** | Reducción frente al modelo nulo | **36,5%** |
| **3 — Predicción** | Perfil de edad (Sección 1) frente al nulo | **2,5%** |
| **3 — Predicción** | LOOCV del mejor modelo | **0,5560** |
| **3 — Predicción** | Variable más importante | `horas` (+0,0290 de RMSE al quitarla) |

Las tres secciones corren sobre **la misma muestra de 14.751 observaciones**
(10.255 entrenamiento, 4.496 validación).

> **Ninguna cifra de este README, ni de los tres decks, se teclea a mano.** Las de
> las slides entran como macros de LaTeX que escribe el propio pipeline
> (`views/tables/cifras_age.tex`, `cifras_gap.tex`, `cifras_pred.tex`): si cambia
> la muestra, cambian las láminas.

## Estructura del repositorio

```
.
├── README.md
├── PS1.Rproj                    # Proyecto de RStudio (define el working directory)
├── document/                    # Slides (.qmd -> .pdf) de las tres secciones
│   ├── age_equipo_06.qmd
│   ├── gap_equipo_06.qmd
│   ├── pred_equipo_06.qmd
│   └── notas_pulso.md           # Nota tecnica: procedencia y seleccion
├── scripts/
│   ├── 00_packages.R            # Carga/instala dependencias y fija la semilla
│   ├── 01_scraping.R            # Scraping de los 10 chunks (con cache en disco)
│   ├── 02_cleaning.R            # Muestra de analisis: unica fuente de verdad
│   ├── 03_descriptives.R        # Descriptivas que motivan las especificaciones
│   ├── 10_age_profile.R         # Seccion 1
│   ├── 20_gender_gap.R          # Seccion 2 (FWL + bootstrap)
│   ├── 30_prediction.R          # Seccion 3 (validacion, LOOCV, importancia)
│   ├── 99_run_all.R             # Pipeline completo de reproduccion
│   └── functions/               # Funciones reutilizables
│       ├── edad_pico.R          # -b_age / (2 b_edad_2)
│       ├── figuras.R            # Tema comun, guardado y formato numerico es-CO
│       ├── rmse.R               # RMSE
│       └── rmse_loocv.R         # LOOCV exacto por leverage
├── stores/
│   ├── raw/                     # Chunks descargados (NO versionado)
│   └── processed/               # muestra_analisis.rds (SI versionado)
└── views/
    ├── figures/                 # Figuras exportadas (.png)
    └── tables/                  # Tablas y macros exportadas (.tex)
```

### Que hace cada script

| Script | Que hace | Que deja |
|---|---|---|
| `00_packages.R` | Carga (e instala) los paquetes y fija `set.seed(1234)`. Todo script empieza por aquí. | — |
| `01_scraping.R` | Descarga los 10 chunks de la GEIH. **Cachea en disco**: si el `.rds` o el HTML ya están, no emite petición. | `stores/raw/chunk_01..10.rds` |
| `02_cleaning.R` | `construir_muestra_analisis()`: aplica los filtros, construye las variables del equipo y define `particion`. **Única fuente de verdad de la limpieza** para las tres secciones. | `stores/processed/muestra_analisis.rds`, `views/tables/construccion_muestra.tex` |
| `03_descriptives.R` | Descriptivas que justifican decisiones: asimetría del outcome (por qué logaritmos), perfil por edad, brecha cruda, deriva temporal. | 5 figuras en `views/figures/` |
| `10_age_profile.R` | **Sección 1.** Perfiles incondicional y condicional, edad pico e IC bootstrap (1.000 réplicas por especificación). | `perfiles_edad.tex`, `cifras_age.tex`, 2 figuras |
| `20_gender_gap.R` | **Sección 2.** Tres especificaciones, FWL, errores HC1 y bootstrap (10.000 réplicas), perfiles por sexo con picos e IC, y el diagnóstico de selección por no respuesta. | `tabla_brecha_genero.tex`, `brecha_compacta.tex`, `cifras_gap.tex`, 1 figura |
| `30_prediction.R` | **Sección 3.** Partición temporal, baselines de las Secciones 1 y 2, modelo nulo, cinco especificaciones, LOOCV, importancia de variables y dependencia de las predicciones. | `rmse_pred.tex`, `importancia_pred.tex`, `cifras_pred.tex`, 1 figura |
| `99_run_all.R` | Corre todo lo anterior en orden. **Es la única forma soportada de reproducir.** | Todo `views/` |

## Reproducción

```bash
git clone https://github.com/Stebandido77/problem-set-1.git
cd problem-set-1
Rscript scripts/99_run_all.R
```

Con `stores/raw/` ya en disco, la corrida completa toma **10 min 03 s**,
medidos de punta a punta en esta máquina. El grueso son los dos bootstrap de la
Sección 2 y las reestimaciones de la Sección 3:

| Etapa | Tiempo medido |
|---|---|
| `00_packages.R` | 3,1 s |
| `01_scraping.R` (con cache; sin peticiones) | 0,7 s |
| `02_cleaning.R` | 0,1 s |
| `03_descriptives.R` | 8,5 s |
| `10_age_profile.R` — dos bootstrap de 1.000 réplicas | 18,5 s |
| `20_gender_gap.R` — bootstrap de 10.000 réplicas x2 | 292,5 s |
| `30_prediction.R` — 5 modelos, LOOCV e importancia | 279,8 s |
| **Total** | **603,1 s** |

Desde un clone limpio hay que sumarle la descarga de ~227 MB de HTML crudo.

Para regenerar los decks (requiere Quarto y una distribución de LaTeX):

```bash
cd document
quarto render age_equipo_06.qmd  --to beamer
quarto render gap_equipo_06.qmd  --to beamer
quarto render pred_equipo_06.qmd --to beamer
```

Los decks **no calculan nada**: solo incluyen las tablas y figuras que dejo el
pipeline, de modo que hay que correr `99_run_all.R` antes.

## Datos

Microdatos de Bogotá del reporte *Medición de Pobreza Monetaria y Desigualdad*
(2018), basado en la GEIH:
<https://ignaciomsarmiento.github.io/GEIH2018_sample/>.
Distribuidos en 10 chunks. Variable de resultado: `y_total_m`.

> **Procedencia.** El sitio del curso enlaza al catálogo DANE 547, *Gran Encuesta
> Integrada de Hogares - GEIH - 2018*
> (<https://microdatos.dane.gov.co/index.php/catalog/547>); la MPMD es el reporte
> construido a partir de esa encuesta, de modo que ambas descripciones apuntan a
> la misma fuente.

**Partición (Sección 3):** chunks 1–7 = entrenamiento · chunks 8–10 = validación.
El corte es **temporal**, no aleatorio: los chunks están ordenados por mes.

## Decisiones de limpieza

Todas viven en `construir_muestra_analisis()` dentro de `scripts/02_cleaning.R`,
que es la única fuente de verdad para las tres secciones. La cascada completa se
exporta a `views/tables/construccion_muestra.tex`.

| Decisión | Criterio | Costo | Justificación |
|---|---|---|---|
| Ocupados | `ocu == 1` | 15.495 (48,16%) | Enunciado |
| Edad | `age >= 18` | 140 (0,84%) | Enunciado |
| Ingreso faltante | excluir, nunca imputar | 1.778 (10,75%) | `y_total_m` no registra ceros exactos, solo `NA`. 248 son `relab` 6/7 (trabajo no remunerado), faltantes por construcción. Imputar exigiría un modelo de ingreso, que es el objeto de estimación. |
| Cola alta | **no se toca** | 0 | El ejercicio es detección de subreporte por una autoridad tributaria: la cola alta es la población de interés. Sin top-coding, winsorización ni recorte por percentil. |
| Piso de ingreso | no se aplica en la muestra base | 0 | El argumento `piso_ingreso` permite reestimar como chequeo de robustez (con `piso_ingreso = 500` la muestra baja a 14.680). |
| Horas implausibles | `totalHoursWorked <= 112` | 12 (0,08%) | 16 h/dia x 7 días. El ingreso reportado es plausible; el error está en las horas, que son control en la Sección 1 y predictor en la Sección 3. |
| Educación faltante | excluir | 1 (0,01%) | Control central en las tres secciones. |
| Factor de expansión | **no se aplica** | 0 | La Sección 3 se evalua por RMSE no ponderado. La inferencia ponderada valida exige estratos y UPM, que este sample no publica. `fex_c` se conserva como columna. |
| Niveles raros de `oficio` | colapsar en `"otros"` si tienen < 30 obs **en chunks 1-7** | 29 niveles, 2,8% | El umbral se calcula solo en entrenamiento y se aplica a validación, de modo que el fold de validación nunca informa la codificación. |
| `relab == 8` | colapsar en `relab == 9` ("otro") | 1 obs recodificada | Un único caso en entrenamiento: se ajustaría perfectamente y desaparecería bajo LOOCV. |

**Muestra final: 14.751 observaciones** (10.255 entrenamiento, 4.496 validación).

### Regla del equipo: el `.rds` viaja con el script

`stores/processed/muestra_analisis.rds` **si** se versiona. Lleva un atributo
`meta` con el `N` final, la fecha de generación y un hash SHA-256 de las reglas
de limpieza (digest del cuerpo de `construir_muestra_analisis()`).

> **Cualquier cambio a `scripts/02_cleaning.R` se commitea junto con el `.rds`
> regenerado, nunca por separado.**

Al cargar la muestra, `02_cleaning.R` imprime esa metadata y **advierte** si el
hash almacenado no coincide con el script actual:

```
--- analysis sample metadata ---
  N observations : 14751
  generated at   : 2026-09-04 23:58:35
  cleaning rules : b05214a0920f643f...
  piso_ingreso   : NULL (base sample)
  oficio_n_min   : 30 | horas_max: 112
```

Si ves `muestra_analisis.rds was built with DIFFERENT cleaning rules`, corre
`Rscript scripts/02_cleaning.R` y commitea el `.rds` resultante en el mismo
commit que el cambio al script.

Se mantiene en `.rds` a propósito: `.gitignore` tiene una regla `*.csv.gz` que
dejaría un export comprimido fuera del repositorio sin avisar.

## Glosario de variables

Dos convenciones de nombres conviven a propósito en el mismo data frame, y el
estilo es la señal de a quién pertenece cada columna:

- **Columnas del DANE**: nombre original, `camelCase` incluido. No se pasan por
  `janitor::clean_names()` ni se traducen, para que sigan correspondiendo uno a
  uno con el diccionario del curso y con el enunciado.
- **Columnas del equipo**: `snake_case` en español, construidas en
  `scripts/02_cleaning.R`.

Los 10 chunks crudos traen 178 columnas; la muestra de análisis conserva 27.
Las definiciones de abajo se verificaron contra el dato, no se supusieron.

### Variables del DANE

| Variable | Que es | Valores observados |
|---|---|---|
| `y_total_m` | **Outcome.** Ingreso laboral mensual total. Suma exacta de `y_ingLab_m + y_gananciaIndep_m` (coincide en el 100% de la muestra) y sigue la serie **sin imputar**: solo 20 filas (0,14%) tienen valor en `impaes`. | Numérica. Sin ceros exactos, solo `NA` |
| `y_total_m_ha` | Ingreso laboral **por hora**. Es exactamente `y_total_m / (4,2857 * totalHoursWorked)`, es decir 30/7 semanas por mes. | Numérica |
| `ocu` | Ocupado en la semana de referencia. Define la muestra base. | `0`, `1` |
| `age` | Edad en años cumplidos. | `0`–`95` en el crudo |
| `sex` | Sexo. **`1` = hombre, `0` = mujer.** De aquí sale `mujer`. | `0`, `1` |
| `relab` | Posición ocupacional: `4` cuenta propia (coincide exactamente con `cuentaPropia == 1`), `5` patrón o empleador, `6` y `7` trabajo no remunerado, `8` jornalero (1 sola observación), `9` otro. `NA` exactamente cuando `ocu != 1`. | `1`–`9` |
| `oficio` | Codigo de ocupación. 79 niveles llegan a la muestra; los raros se colapsan en `oficio_grupo`. | `2`–`99` |
| `maxEducLevel` | Nivel educativo máximo. La codificación **no es monotona**: `college == 1` coincide exactamente con `maxEducLevel == 6`, no con el `7`. Entra siempre como factor. | `1`–`7` |
| `sizeFirm` | Tamaño de la empresa. `microEmpresa == 1` coincide exactamente con `sizeFirm` en `{1, 2}`. | `1`–`5` |
| `estrato1` | Estrato socioeconómico de la vivienda. Entra como factor: la distancia entre estratos no es cardinal. | `1`–`6` |
| `cotPension` | Cotización a pensión. `2` corresponde siempre a `formal == 0`; `1` y `3` a `formal == 1` salvo 73 de 16.663 filas (0,4%). | `1`, `2`, `3` |
| `p6426` | Antiguedad en el trabajo actual, en meses. Se renombra a `antiguedad_meses`. | `0`–`600` |
| `totalHoursWorked` | Horas efectivamente trabajadas en la semana. Control en la Sección 1, predictor en la Sección 3. | `2`–`130` en el crudo |
| `hoursWorkUsual` | Horas que la persona trabaja habitualmente. | `2`–`130` |
| `formal` | Indicador de formalidad. | `0`, `1` |
| `college` | Educación superior. Equivale a `maxEducLevel == 6`. | `0`, `1` |
| `cuentaPropia` | Trabajador por cuenta propia. Equivale a `relab == 4`. | `0`, `1` |
| `microEmpresa` | Micro empresa. Equivale a `sizeFirm` en `{1, 2}`. | `0`, `1` |
| `fex_c` | Factor de expansión del diseño muestral. **No se aplica**; se conserva para el chequeo ponderado de la Sección 2. | `129,45`–`477,97` |
| `fweight` | El mismo factor redondeado: `fweight == round(fex_c)` en el 100% de las filas. | `129`–`478` |
| `mes` | Mes de la encuesta. **Nunca es predictor**: filtra la partición. | `1`–`12` |
| `directorio`, `secuencia_p`, `orden` | Identificadores de vivienda, hogar y persona. Se conservan solo para rastrear una fila hasta el dato crudo. | Enteros |
| `chunk_id` | Número de chunk, agregado por `01_scraping.R`. Ordenado por mes (chunk 1 = ene-feb ... chunk 10 = nov-dic), así que **nunca es predictor**. | `1`–`10` |
| `impa`, `impaes` | Ingreso de la actividad principal, antes y después de la imputación del DANE. No entran a la muestra: se usan solo en el diagnóstico de selección de la Sección 2. | Numéricas |

### Variables construidas por el equipo

| Variable | Definición | Por qué |
|---|---|---|
| `ingreso_log` | `log(y_total_m)` | Outcome de las tres secciones. En niveles la asimetría es 8,49; en logaritmos, -0,348 |
| `mujer` | `as.integer(sex == 0)` | Invierte la codificación del DANE para que el coeficiente de la Sección 2 se lea directo como brecha femenina |
| `edad_2` | `age^2` | Sin el cuadrático no hay edad pico que estimar |
| `relab_grupo` | `relab`, con el `8` plegado en el `9` | `relab == 8` tiene 1 sola observación de entrenamiento: apalancamiento 1 y LOOCV infinito |
| `oficio_grupo` | `oficio`, con los niveles de menos de 30 obs. **en chunks 1-7** colapsados en `"otros"` | Umbral aprendido solo en entrenamiento. Sobreviven 50 niveles, se colapsan 29, `"otros"` queda con el 2,8% |
| `educ` | `factor(maxEducLevel)` | Codificación no cardinal |
| `tamano_empresa` | `factor(sizeFirm)` | Codificación no cardinal |
| `estrato` | `factor(estrato1)` | Codificación no cardinal |
| `cot_pension` | `factor(cotPension)` | Codificación no cardinal |
| `antiguedad_meses` | `p6426` | Renombre legible |
| `horas` | `totalHoursWorked` | Renombre legible |
| `horas_usuales` | `hoursWorkUsual` | Renombre legible |
| `particion` | `"entrenamiento"` si `chunk_id` está en 1–7, si no `"validacion"` | Determinista y temporal, no aleatoria: no depende de la semilla |

## Flujo de trabajo con Git

- `main` protegido: nada se mergea sin pull request.
- Ramas: `feat/age-profile`, `feat/gender-gap`, `feat/prediction`, `fix/...`.
- Conventional commits: **tipo y alcance en ingles, descripción en español**
  (ver `.gitmessage`). Prefijos validos: `feat`, `fix`, `refactor`, `docs`,
  `data`, `chore`, `test`.
- Cada integrante debe registrar al menos **5 contribuciones sustanciales** a
  `main`.
