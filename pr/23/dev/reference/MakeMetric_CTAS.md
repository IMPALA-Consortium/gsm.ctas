# Build the CTAS gsm-shaped `dfMetrics` audit table

One row per unique `(parameter_category_2, parameter_category_3)` pair
in the unfiltered stacked CTAS results, so every field the pipeline
scored appears in the table. Carries the labels the `gsm.kri` overview
widget and per-metric bar chart consume, plus one column per CTAS
parameter (Feature toggles, sample-size gates, scoring / padjust
methods, seed) harvested from each metric workflow's `meta:` block.

## Usage

``` r
MakeMetric_CTAS(
  dfResults,
  lMetricWorkflows = NULL,
  vThreshold = c(0.842, 2.326),
  dfInput = NULL
)
```

## Arguments

- dfResults:

  `data.frame` Unfiltered stacked CTAS results, typically
  `Reporting_Results$results` from the reporting `Results` workflow.
  Must carry `parameter_category_2` (field) and `parameter_category_3`
  (metric family). `parameter_id` and `parameter_category_1` are copied
  through when present.

- lMetricWorkflows:

  `list` Metric workflow YAML objects
  ([`workr::MakeWorkflowList()`](https://rdrr.io/pkg/workr/man/MakeWorkflowList.html)
  output from `inst/workflow/2_metrics`). Each element's `meta:` block
  supplies the CTAS parameter columns for the workflow whose `meta$ID`
  matches `parameter_category_3`. Metric families with no matching
  workflow get `NA` in the parameter columns. Default `NULL` -\> every
  parameter column is `NA`.

- vThreshold:

  `numeric` Threshold values used by [`Flag_CTAS()`](Flag_CTAS.md).
  Written verbatim into the `Threshold` string. Default
  `c(0.842, 2.326)`.

- dfInput:

  `data.frame` Optional stacked CTAS input frame
  (`Reporting_Results$input`), used only to look up `parameter_name` for
  each `parameter_id`. `NULL` -\> `parameter_name` is `NA`.

## Value

`data.frame` with the gsm-shaped `dfMetrics` columns (`MetricID`,
`Abbreviation`, `Metric`, `Score`, `Threshold`, `GroupLevel`,
`AnalysisType`, `Model`) plus the CTAS identity columns (`parameter_id`,
`parameter_name`, `parameter_category_1`, `parameter_category_2`,
`parameter_category_3`) and one column per CTAS parameter surfaced from
the metric YAMLs.

`Abbreviation` is the short label the `gsm.kri` site-overview widget
uses as each metric column's header (see `gsm.viz`
`defineMetricColumns`: `label: metric.Abbreviation`); an empty
`Abbreviation` renders as an empty column header. It is set here to
`parameter_category_2`.

## Details

`MetricID` is `ctas_<parameter_category_3>_<parameter_category_2>` –
family-granular so each `(field, metric family)` pair carries its own
CTAS parameter values distinctly. This is *not* the field-level
`MetricID` scheme emitted by [`Summarize_CTAS()`](Summarize_CTAS.md)
(`ctas_<field>`); [`Report_CTAS()`](Report_CTAS.md) collapses it to that
scheme internally before handing it to
[`gsm.kri::MakeCharts()`](https://gilead-public.github.io/gsm.kri/reference/MakeCharts.html).

## See also

[`Report_CTAS()`](Report_CTAS.md) for the end-to-end reporting pipeline.
