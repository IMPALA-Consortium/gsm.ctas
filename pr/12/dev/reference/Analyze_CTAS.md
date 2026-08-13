# Run the CTAS engine over a combined study input

A gsm-friendly wrapper around
[`ctas::process_a_study()`](https://rdrr.io/pkg/ctas/man/process_a_study.html).
It validates the input list produced by
[`Combine_CTAS_Input()`](Combine_CTAS_Input.md), applies reproducible
seeding, and converts the degenerate cases CTAS signals by returning
`NULL` elements into an informative error.

## Usage

``` r
Analyze_CTAS(
  lInput,
  strFeatures = "autocorr;average;sd;unique_value_count_relative",
  nMinTimepoints = 3,
  nMinSubjects = 3,
  dMaxShareMissing = 0.5,
  bChangeFromBaseline = FALSE,
  bAutogenerate = TRUE,
  strScoringMethod = "ks",
  strPadjustMethod = "fdr",
  nSeed = NULL,
  ...
)
```

## Arguments

- lInput:

  `list` Result of [`Combine_CTAS_Input()`](Combine_CTAS_Input.md).

- strFeatures:

  `character` Semicolon-delimited CTAS features.

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

  `character` One of "ks", "mixedeffects", "avg_feat_value".

- strPadjustMethod:

  `character` Passed to
  [`stats::p.adjust()`](https://rdrr.io/r/stats/p.adjust.html).

- nSeed:

  `numeric` Optional seed for reproducibility.

- ...:

  Further arguments passed to
  [`ctas::process_a_study()`](https://rdrr.io/pkg/ctas/man/process_a_study.html).

## Value

`list` with `timeseries`, `timeseries_features`, `PCA_coordinates` and
`site_scores`.

## Details

`process_a_study()` is an all-metrics-at-once engine: a single call
scores every (timeseries x feature x site) combination. It is therefore
intended to run once per study, in a high-`Priority` mapping workflow,
with each metric workflow filtering the shared result to one feature.

## Examples

``` r
# \donttest{
lInput <- Combine_CTAS_Input(
  Input_Numeric(pharmaversesdtm::vs),
  dfSubjects = Input_Subjects(pharmaversesdtm::dm)
)
lCTAS <- Analyze_CTAS(lInput)
#> Warning: There were 26 warnings in `mutate()`.
#> The first warning was:
#> ℹ In argument: `ts_features = list(...)`.
#> ℹ In row 4.
#> Caused by warning in `cor()`:
#> ! the standard deviation is zero
#> ℹ Run `dplyr::last_dplyr_warnings()` to see the 25 remaining warnings.
# }
```
