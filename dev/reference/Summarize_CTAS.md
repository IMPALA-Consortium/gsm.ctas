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
  vGroupIDs = NULL,
  dHigh = 2.326,
  dLow = 0.842
)
```

## Arguments

- dfSiteScores:

  `data.frame` The `site_scores` element of
  [`Analyze_CTAS()`](Analyze_CTAS.md).

- strFeature:

  `character` Single CTAS feature to summarise, e.g. `"average"`.

- strGroupLevel:

  `character` gsm group level, `"Site"` or `"Country"`.

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

Groups with no evaluated timeseries for the feature are retained with
`Denominator = 0`, `Metric = NA` and `Score = NA`, so that the report
does not silently drop them. Supply `vGroupIDs` to complete the grid
against a known group list; otherwise only groups present in
`dfSiteScores` appear.

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
  feature = "average",
  fdr_corrected_pvalue_logp = c(3.1, 0.5, 1.0)
)
Summarize_CTAS(dfSiteScores, strFeature = "average")
#> # A tibble: 2 × 6
#>   GroupID GroupLevel Numerator Denominator Metric Score
#>   <chr>   <chr>          <dbl>       <dbl>  <dbl> <dbl>
#> 1 001     Site               1           2    0.5   3.1
#> 2 002     Site               0           1    0     1  
```
