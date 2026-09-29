# Aggregate CTAS site scores into a gsm-shaped CTAS summary

Pivots the long CTAS results frame (one row per site x timeseries x
feature) into the gsm reporting `dfResults` contract (one row per site x
synthetic `MetricID`) so the stock `gsm.kri` report can render it
unchanged. Each `parameter_category_2` (data field, e.g. `"AST"`,
`"SYSBP"`) becomes its own `MetricID` (`ctas_<field>`); metric families
are collapsed with `max(Score)` so a field scored by both
`range_normalized` and `ratio_missing` shows as one CTAS row. When
`bByFeature = TRUE`, one `MetricID` per (field x CTAS feature) is
emitted instead.

## Usage

``` r
Summarize_CTAS(
  dfResults,
  dfSubjects,
  bIncludeMissingness = TRUE,
  bByFeature = FALSE,
  strStudyID = NULL,
  dSnapshotDate = Sys.Date()
)
```

## Arguments

- dfResults:

  `data.frame` Stacked CTAS results, typically
  `Reporting_Results$results` from the reporting Results workflow. Must
  contain `study`, `site`, `parameter_category_2`,
  `parameter_category_3`, `feature`, `fdr_corrected_pvalue_logp`,
  `timeseries_id`.

- dfSubjects:

  `data.frame` Standardised subjects with `studyid`, `subject_id`,
  `site`. Used to complete the (study x site x MetricID) grid so sites
  with no scored timeseries stay visible.

- bIncludeMissingness:

  `logical` Include the `ratio_missing` metric family
  (`parameter_category_3 == "ratio_missing"`) in the aggregation.
  Default `TRUE`.

- bByFeature:

  `logical` Group by (data field x CTAS feature) instead of by data
  field only. Default `FALSE`.

- strStudyID:

  `character` Optional single StudyID used for every row (overrides
  per-row `study`). Default `NULL` -\> use the `study` column.

- dSnapshotDate:

  `Date` Snapshot date stamped on every row. Default
  [`Sys.Date()`](https://rdrr.io/r/base/Sys.time.html).

## Value

`data.frame` with the gsm reporting `dfResults` columns (`MetricID`,
`GroupID`, `GroupLevel`, `StudyID`, `SnapshotDate`, `Score`) plus the
CTAS grouping keys (`parameter_category_2`, and `feature` when
`bByFeature = TRUE`) so downstream steps can label metrics without a
re-join.

## Details

The `Score` is the max `fdr_corrected_pvalue_logp` across every
contributing (timeseries x feature) row in the group. Sites present in
`dfSubjects` but absent from `dfResults` (e.g. no scorable timeseries
for a field) are retained with `Score = NA` so the CTAS overview table
cannot silently drop them.

`Flag` is intentionally not emitted here – run
[`Flag_CTAS()`](Flag_CTAS.md) on the returned frame to add it. Splitting
Summarize + Flag mirrors the
[`gsm.core::Summarize()`](https://rdrr.io/pkg/gsm.core/man/Summarize.html)
/ [`gsm.core::Flag()`](https://rdrr.io/pkg/gsm.core/man/Flag.html) seam
so users can swap thresholds without re-aggregating.

## See also

[`Flag_CTAS()`](Flag_CTAS.md) to add the `Flag` column.

## Examples

``` r
if (FALSE) { # \dontrun{
lReporting <- workr::RunWorkflows(
  lReportingWorkflows["Results"],
  lData = c(lMapped, list(lAnalyzed = lAnalysis))
)
dfSummary <- Summarize_CTAS(
  dfResults = lReporting$Reporting_Results$results,
  dfSubjects = lMapped$Mapped_Subjects
)
} # }
```
