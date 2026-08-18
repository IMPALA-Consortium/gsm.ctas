# Aggregate CTAS site scores into the gsm `Analysis_Analyzed` contract

CTAS returns one score per (timeseries x feature x group), while gsm
expects one row per group per metric. `Summarize_CTAS()` filters the
shared [`Analyze_CTAS()`](Analyze_CTAS.md) output to a single feature
and collapses it over timeseries.

## Usage

``` r
Summarize_CTAS(
  dfSiteScores,
  strFeature,
  strGroupLevel = "Site",
  strDomain = NULL,
  strTransformation = NULL,
  strParameterPattern = NULL,
  vGroupIDs = NULL,
  dHigh = 2.326,
  dLow = 0.842
)
```

## Arguments

- dfSiteScores:

  `data.frame` The `site_scores` element of
  [`Analyze_CTAS()`](Analyze_CTAS.md), normally via
  [`Combine_CTAS_Scores()`](Combine_CTAS_Scores.md).

- strFeature:

  `character` Single CTAS feature to summarise, e.g. `"average"`.

- strGroupLevel:

  `character` gsm group level, `"Site"` or `"Country"`.

- strDomain:

  `character` Optional `parameter_category_1` to keep, e.g. `"Labs"`.
  Must be given together with `strTransformation`.

- strTransformation:

  `character` Optional `parameter_category_3` to keep, e.g.
  `"ratio_missing"`. Must be given together with `strDomain`.

- strParameterPattern:

  `character` Optional regular expression matched against
  `parameter_id`, as an alternative to the category pair for inputs that
  lack the category columns.

- vGroupIDs:

  `character` Optional complete vector of group IDs.

- dHigh:

  `numeric` Score at or above which a timeseries triggers "Further
  Evaluation".

- dLow:

  `numeric` Score at or above which a timeseries is put on the "Watch
  List".

## Value

`data.frame` with `GroupID`, `GroupLevel`, `Numerator`, `Denominator`,
`Metric` and `Score`.

## Details

A single CTAS run covers every domain in the study, so `feature` alone
does not identify a metric once more than one domain is mapped:
"average" spans vital signs, range-normalised labs and lab missingness
at the same time. A metric must therefore also say which family of
parameters it summarises.

There are two ways to do so, and the category pair is preferred:

- `strDomain` and `strTransformation` match `parameter_category_1` (e.g.
  `"Labs"`) and `parameter_category_3` (e.g. `"ratio_missing"`). These
  are the structured fields the `Input_*()` functions set, recovered by
  [`Combine_CTAS_Scores()`](Combine_CTAS_Scores.md). **Both** are needed
  to identify a family: `parameter_category_3` is `"numeric"` for every
  plain numeric domain, so it would select vital signs and ECG together.

- `strParameterPattern` matches a regular expression against
  `parameter_id`. This works without the category columns, but
  re-derives from a string what the categories already state, and is
  easy to get subtly wrong - `"^LB_"` selects both lab families where
  `"^LB_MISS_"` selects one.

Groups with no evaluated timeseries for the feature are retained with
`Denominator = 0`, `Metric = NA` and `Score = NA`, so that the report
does not silently drop them. Supply `vGroupIDs` to complete the grid
against a known group list; otherwise only groups present in
`dfSiteScores` appear.

`Denominator` counts the timeseries evaluated for the feature, not
participants. Sites are normally assessed on the same timeseries, so the
denominator is usually constant across sites within a metric, and varies
only where a site contributes no data at all for a parameter. It differs
*between* metrics, because CTAS autogenerates one timeseries per
timepoint combination and those differ by domain. It is a coverage
denominator, not an exposure one, and should not be read as site size.

The default thresholds `2.326` / `0.842` are drawn from experience
rather than derived. They are one-sided normal z-quantiles (99% / 80%)
applied to a -log10(p) scale, where they correspond to p = 0.0047 and p
= 0.144. Override them from the workflow YAML `meta` block where a
different convention is wanted.

## Examples

``` r
dfSiteScores <- data.frame(
  timeseries_id = c("ts1", "ts2", "ts1"),
  site = c("001", "001", "002"),
  country = "USA",
  parameter_id = c("VS_SYSBP", "LB_NORM_ALB", "VS_SYSBP"),
  parameter_category_1 = c("Vital Signs", "Labs", "Vital Signs"),
  parameter_category_3 = c("numeric", "range_normalized", "numeric"),
  feature = "average",
  fdr_corrected_pvalue_logp = c(3.1, 0.5, 1.0)
)
Summarize_CTAS(
  dfSiteScores,
  strFeature = "average",
  strDomain = "Vital Signs",
  strTransformation = "numeric"
)
#> # A tibble: 2 × 6
#>   GroupID GroupLevel Numerator Denominator Metric Score
#>   <chr>   <chr>          <dbl>       <dbl>  <dbl> <dbl>
#> 1 001     Site               1           1      1   3.1
#> 2 002     Site               0           1      0   1  
```
