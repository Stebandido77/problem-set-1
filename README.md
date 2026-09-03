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
exporta tablas y figuras a `views/`. Tiempo aproximado: — min.

## Datos

Microdata de Bogota del reporte *Medicion de Pobreza Monetaria y Desigualdad* (2018),
basada en la GEIH: <https://ignaciomsarmiento.github.io/GEIH2018_sample/>.
Distribuidos en 10 chunks. Variable de resultado: `y_total_m`.

> **Procedencia.** El sitio del curso enlaza al catalogo DANE 547, *Gran Encuesta
> Integrada de Hogares - GEIH - 2018* (<https://microdatos.dane.gov.co/index.php/catalog/547>);
> la MPMD es el reporte construido a partir de esa encuesta, de modo que ambas
> descripciones apuntan a la misma fuente.

**Particion (Seccion 3):** chunks 1–7 = entrenamiento · chunks 8–10 = validacion.

## Decisiones de limpieza

Todas viven en `build_analysis_sample()` dentro de `scripts/02_cleaning.R`, que
es la unica fuente de verdad para las tres secciones. El waterfall completo se
exporta a `views/tables/sample_construction.tex`.

| Decision | Criterio | Costo | Justificacion |
|---|---|---|---|
| Ocupados | `ocu == 1` | 15.495 (48,16%) | Enunciado |
| Edad | `age >= 18` | 140 (0,84%) | Enunciado |
| Ingreso faltante | excluir, nunca imputar | 1.778 (10,75%) | `y_total_m` no registra ceros exactos, solo `NA`. 248 son `relab` 6/7 (trabajo no remunerado), faltantes por construccion. Imputar exigiria un modelo de ingreso, que es el objeto de estimacion. |
| Cola alta | **no se toca** | 0 | El ejercicio es la deteccion de subreporte por una autoridad tributaria: la cola alta es la poblacion de interes. Sin top-coding, winsorizacion ni recorte por percentil. |
| Piso de ingreso | no se aplica en la muestra base | 0 | El argumento `income_floor` permite reestimar las especificaciones como chequeo de robustez (con `income_floor = 500` la muestra baja a 14.680). |
| Horas implausibles | `totalHoursWorked <= 112` | 12 (0,08%) | 16 h/dia x 7 dias. El ingreso reportado es plausible; el error esta en las horas, que son control en la Seccion 1 y predictor en la Seccion 3. |
| Educacion faltante | excluir | 1 (0,01%) | Control central. |
| Factor de expansion | **no se aplica** | 0 | La Seccion 3 se evalua por RMSE no ponderado. La inferencia ponderada valida exige estratos y UPM, que este sample no publica. `fex_c` se conserva como columna para el chequeo ponderado de la Seccion 2. |
| Niveles raros de `oficio` | colapsar en `"otros"` si tienen < 30 obs **en chunks 1-7** | 29 niveles, 2,8% | El umbral se calcula solo en entrenamiento y se aplica a validacion, de modo que el fold de validacion nunca informa la codificacion. |
| `relab == 8` | colapsar en `relab == 9` ("otro") | 1 obs recodificada | Un unico caso en entrenamiento: se ajustaria perfectamente y desapareceria bajo LOOCV. |

**Muestra final: 14.751 observaciones** (10.255 entrenamiento, 4.496 validacion).

### Regla del equipo: el `.rds` viaja con el script

`stores/processed/analysis_sample.rds` **si** se versiona. Lleva un atributo
`meta` con el `N` final, la fecha de generacion y un hash SHA-256 de las reglas
de limpieza (digest del cuerpo de `build_analysis_sample()`).

> **Cualquier cambio a `scripts/02_cleaning.R` se commitea junto con el `.rds`
> regenerado, nunca por separado.**

Al cargar la muestra, `02_cleaning.R` imprime esa metadata y **advierte** si el
hash almacenado no coincide con el script actual:

```
--- analysis sample metadata ---
  N observations : 14751
  generated at   : 2026-09-03 13:34:05
  cleaning rules : 389ab2e03f19a76f...
  income_floor   : NULL (base sample)
  oficio_min_n   : 30 | hours_max: 112
```

Si ves `analysis_sample.rds was built with DIFFERENT cleaning rules`, corre
`Rscript scripts/02_cleaning.R` y commitea el `.rds` resultante en el mismo
commit que el cambio al script.

Se mantiene en `.rds` a proposito: `.gitignore` tiene una regla `*.csv.gz` que
dejaria un export comprimido fuera del repositorio sin avisar.

## Flujo de trabajo con Git

- `main` protegido: nada se mergea sin pull request.
- Ramas: `feat/age-profile`, `feat/gender-gap`, `feat/prediction`, `fix/...`.
- Commits en ingles siguiendo conventional commits (ver `.gitmessage`).
- Cada integrante debe registrar al menos **5 contribuciones sustanciales** a `main`.
