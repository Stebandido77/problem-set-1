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

**Particion (Seccion 3):** chunks 1–7 = entrenamiento · chunks 8–10 = validacion.

## Decisiones de limpieza

| Decision | Criterio | Justificacion |
|---|---|---|
| Ocupados | `ocu == 1` | Enunciado |
| Edad | `age >= 18` | Enunciado |
| Ingreso cero / faltante | — | — |
| Outliers | — | — |

## Flujo de trabajo con Git

- `main` protegido: nada se mergea sin pull request.
- Ramas: `feat/age-profile`, `feat/gender-gap`, `feat/prediction`, `fix/...`.
- Commits en ingles siguiendo conventional commits (ver `.gitmessage`).
- Cada integrante debe registrar al menos **5 contribuciones sustanciales** a `main`.
