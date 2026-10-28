# Flag CTAS scores with a gsm-shaped `Flag` column

User-facing gsm-style flagging function that mirrors the
[`gsm.core::Flag()`](https://rdrr.io/pkg/gsm.core/man/Flag.html)
signature but with unsigned CTAS defaults appropriate for the
`-log10(p)` scoring scale. Adds a `Flag` column to `dfAnalyzed` based on
left-closed intervals of the score column.

## Usage

``` r
Flag_CTAS(
  dfAnalyzed,
  strColumn = "Score",
  vThreshold = c(0.842, 2.326),
  vFlag = c(0, 1, 2),
  vFlagOrder = c(2, 1, 0),
  nAccrualThreshold = NULL,
  strAccrualMetric = NULL
)
```

## Arguments

- dfAnalyzed:

  `data.frame` Aggregated CTAS scores, typically the output of
  [`Summarize_CTAS()`](Summarize_CTAS.md). Must contain `strColumn`.

- strColumn:

  `character` Column to threshold. Default `"Score"`.

- vThreshold:

  `numeric` Ascending threshold values. Default `c(0.842, 2.326)`.

- vFlag:

  `numeric` Flag values, one longer than `vThreshold`. Default
  `c(0, 1, 2)`.

- vFlagOrder:

  `numeric` Sort order for the returned rows. Must contain the same
  values as `vFlag`. Default `c(2, 1, 0)` (red first). Pass `NULL` to
  leave rows unsorted.

- nAccrualThreshold:

  `numeric` Minimum accrual value below which `Score` and `Flag` are set
  to `NA`. Default `NULL` (no accrual filter).

- strAccrualMetric:

  `character` Column to compare against `nAccrualThreshold`. One of
  `"Numerator"`, `"Denominator"`, `"Difference"` (Denominator -
  Numerator). Required when `nAccrualThreshold` is set.

## Value

`data.frame` `dfAnalyzed` with an added `Flag` column, optionally sorted
by `vFlagOrder`.

## Details

CTAS `-log10(p)` is one-sided and non-negative, so the defaults are two
ascending thresholds (`0.842`, `2.326` – 80% and 99% one-sided normal
z-quantiles) with three flag levels (`0` = green, `1` = amber, `2` =
red). A `Flag = 2` means the site differs from its peers; the unsigned
scale carries no directional information.

## See also

[`gsm.core::Flag()`](https://rdrr.io/pkg/gsm.core/man/Flag.html) for the
signed gsm-core variant.

## Examples

``` r
dfSummary <- data.frame(
  MetricID = "ctas_AST",
  GroupID = c("101", "102", "103"),
  Score = c(0.1, 1.2, 3.0),
  Numerator = c(2, 4, 3),
  Denominator = c(2, 4, 3)
)
Flag_CTAS(dfSummary)
#>   MetricID GroupID Score Numerator Denominator Flag
#> 1 ctas_AST     103   3.0         3           3    2
#> 2 ctas_AST     102   1.2         4           4    1
#> 3 ctas_AST     101   0.1         2           2    0
```
