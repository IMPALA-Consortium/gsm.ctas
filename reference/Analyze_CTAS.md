# Score sites with CTAS

A gsm-friendly wrapper around
[`ctas::process_a_study()`](https://rdrr.io/pkg/ctas/man/process_a_study.html).
It takes a single long data frame in the CTAS +
[ctasapp](https://github.com/IMPALA-Consortium/ctasapp) vocabulary
(typically the output of an `Input_*()` function), splits by study when
the multi-study contract is active, runs `process_a_study()` per study,
and returns the flat `results` frame ctasapp displays.

## Usage

``` r
Analyze_CTAS(
  dfInput,
  bAutocorr = TRUE,
  bAverage = TRUE,
  bSD = TRUE,
  bRange = FALSE,
  bUniqueValueCountRelative = TRUE,
  bOwnSiteSimilScore = FALSE,
  bLOF = FALSE,
  nMinTimepoints = 1,
  nMinSubjects = 3,
  dMaxShareMissing = 0.5,
  bChangeFromBaseline = FALSE,
  bAutogenerate = TRUE,
  strScoringMethod = "ks",
  strPadjustMethod = "fdr",
  dfCustomTimeseries = ctas::ctas_data$custom_timeseries,
  dfCustomReferenceGroups = ctas::ctas_data$custom_reference_groups,
  nSeed = NULL,
  strStudyCol = "studyid",
  bStopOnError = TRUE,
  ...
)
```

## Arguments

- dfInput:

  `data.frame` Long-format CTAS input with at minimum `subject_id`,
  `site`, `parameter_id`, `parameter_name`, `parameter_category_1/2/3`,
  `timepoint_1_name`, `timepoint_2_name`, `timepoint_rank`, `result`,
  `baseline`. Additional CTAS subject columns (`country`, `region`) are
  carried through when present.

- bAutocorr:

  `logical` Score the `autocorr` feature.

- bAverage:

  `logical` Score the `average` feature.

- bSD:

  `logical` Score the `sd` feature.

- bRange:

  `logical` Score the `range` feature.

- bUniqueValueCountRelative:

  `logical` Score the `unique_value_count_relative` feature.

- bOwnSiteSimilScore:

  `logical` Score the `own_site_simil_score` feature.

- bLOF:

  `logical` Score the `lof` feature.

- nMinTimepoints:

  `numeric` Minimum timepoints per timeseries.

- nMinSubjects:

  `numeric` Minimum subjects per timeseries.

- dMaxShareMissing:

  `numeric` Maximum share of missing timepoints.

- bChangeFromBaseline:

  `logical` Derive change-from-baseline timeseries.

- bAutogenerate:

  `logical` Autogenerate timeseries.

- strScoringMethod:

  `character` One of `"ks"`, `"mixedeffects"`, `"avg_feat_value"`.

- strPadjustMethod:

  `character` Passed to
  [`stats::p.adjust()`](https://rdrr.io/r/stats/p.adjust.html).

- dfCustomTimeseries:

  `data.frame` Custom timeseries table forwarded to
  [`ctas::process_a_study()`](https://rdrr.io/pkg/ctas/man/process_a_study.html).
  Defaults to the shipped
  [`ctas::ctas_data`](https://rdrr.io/pkg/ctas/man/ctas_data.html).

- dfCustomReferenceGroups:

  `data.frame` Custom reference-group table forwarded to
  [`ctas::process_a_study()`](https://rdrr.io/pkg/ctas/man/process_a_study.html).
  Defaults to `ctas::ctas_data$custom_reference_groups`.

- nSeed:

  `numeric` Optional seed for reproducibility.

- strStudyCol:

  `character` Column on `dfInput` identifying the study. `NULL` disables
  the split and drops the `study` output column.

- bStopOnError:

  `logical` When `FALSE`, an error raised by CTAS (including CTAS
  dropping every timeseries) is turned into a warning and a zero-row
  `results` frame is returned, so the metric workflow still ships its
  `input` and `untransformed` frames. Input validation errors always
  abort.

- ...:

  Further arguments passed to
  [`ctas::process_a_study()`](https://rdrr.io/pkg/ctas/man/process_a_study.html).

## Value

`data.frame` One row per (site x timeseries x feature), carrying
`parameter_id`, the category columns, and `study` (when the multi-study
contract is active).

## Details

Only `results` is returned; the `input` and `untransformed` frames
ctasapp also consumes are pure projections of the input `dfInput`, so
the metric YAML assembles the ctasapp payload in a separate
[`base::list`](https://rdrr.io/r/base/list.html) step (see
`inst/workflow/2_metrics/*.yaml`).

The single-df pattern follows
[ctasval](https://github.com/IMPALA-Consortium/ctasval): `subjects` and
`parameters` are re-derived from `dfInput` via `distinct()` inside the
function so callers only have to keep one frame consistent.

Feature selection is a boolean-per-feature contract instead of the
semicolon-delimited string CTAS accepts, so metric YAMLs can toggle
features individually from `meta:`.

## Examples

``` r
# \donttest{
dfSubjects <- data.frame(
  studyid = pharmaversesdtm::dm$STUDYID,
  subject_id = pharmaversesdtm::dm$USUBJID,
  site = pharmaversesdtm::dm$SITEID,
  country = pharmaversesdtm::dm$COUNTRY
)
dfValues <- Standardize_Domain(
  dfDomain = pharmaversesdtm::vs,
  dfSubjects = dfSubjects,
  strTestCDCol = "VSTESTCD", strTestCol = "VSTEST",
  strValueCol = "VSSTRESN",
  strCategory = "Vital Signs"
)
dfResults <- Analyze_CTAS(dfValues, nSeed = 1)
#> Warning: There were 26 warnings in `mutate()`.
#> The first warning was:
#> ℹ In argument: `ts_features = list(...)`.
#> ℹ In row 5.
#> Caused by warning in `cor()`:
#> ! the standard deviation is zero
#> ℹ Run `dplyr::last_dplyr_warnings()` to see the 25 remaining warnings.
lAnalysis <- list(
  ID = "numeric", results = dfResults,
  input = dfValues, untransformed = dfValues
)
# }
```
