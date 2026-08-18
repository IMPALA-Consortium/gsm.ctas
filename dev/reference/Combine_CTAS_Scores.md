# Attach parameter identity and category to CTAS site scores

`site_scores` identifies a row by `timeseries_id` and `feature` only,
which was sufficient while a study mapped a single domain. Once several
domains share one CTAS run - vital signs, range-normalised labs and lab
missingness - a feature name no longer identifies a metric, and each
metric workflow needs to select its own parameters.

## Usage

``` r
Combine_CTAS_Scores(lResult, lInput = NULL)
```

## Arguments

- lResult:

  `list` Result of [`Analyze_CTAS()`](Analyze_CTAS.md).

- lInput:

  `list` Optional result of
  [`Combine_CTAS_Input()`](Combine_CTAS_Input.md), used to recover the
  parameter categories CTAS drops.

## Value

`data.frame` `site_scores` with `parameter_id` added, plus
`parameter_category_1` and `parameter_category_3` when `lInput` is
given.

## Details

Two joins are needed, because CTAS spreads the identifying fields across
its inputs and outputs and discards some entirely:

- `parameter_id` comes from `lResult$timeseries`.

- `parameter_category_1` (the domain, e.g. `"Labs"`) and
  `parameter_category_3` (the transformation, e.g. `"ratio_missing"`)
  come from `lInput$parameters`. The `Input_*()` functions set these,
  but `process_a_study()` does not return them on any of its four
  elements, so they can only be recovered from the input.

Supplying `lInput` is optional but recommended. Without it, metrics can
only select parameters by pattern-matching `parameter_id` strings; with
it they can select on the categories directly, which is what those
fields are for.

This also satisfies the drill-down contract of the `ctasapp` dashboard
(`site`, `timeseries_id`, `parameter_id`, `feature`,
`fdr_corrected_pvalue_logp`), which plain `site_scores` does not.

## Examples

``` r
Combine_CTAS_Scores(list(
  site_scores = data.frame(
    timeseries_id = "ts1", site = "001", country = "USA",
    feature = "average", fdr_corrected_pvalue_logp = 1.2
  ),
  timeseries = data.frame(timeseries_id = "ts1", parameter_id = "VS_SYSBP")
))
#>   timeseries_id site country feature fdr_corrected_pvalue_logp parameter_id
#> 1           ts1  001     USA average                       1.2     VS_SYSBP
```
