# Flag aggregated CTAS scores

Thin wrapper around
[`gsm.core::Flag()`](https://rdrr.io/pkg/gsm.core/man/Flag.html) that
fixes the flagging to be one-sided. CTAS reports an unsigned -log10(p):
it says "this site differs from the others", not in which direction.
Signed flags would therefore be fabricated, so only `0` / `1` / `2` are
emitted and no negative flag is ever produced in v1.

## Usage

``` r
Flag_CTAS(dfAnalyzed, vThreshold = c(0.842, 2.326), strColumn = "Score")
```

## Arguments

- dfAnalyzed:

  `data.frame` Result of [`Summarize_CTAS()`](Summarize_CTAS.md).

- vThreshold:

  `numeric` Ascending thresholds on the `Score` scale. Defaults to
  `c(0.842, 2.326)`, drawn from experience.

- strColumn:

  `character` Column to flag on.

## Value

`dfAnalyzed` with an added `Flag` column, sorted by flag severity.

## Details

Groups with `Score = NA` (no evaluated timeseries for the feature) keep
`Flag = NA`; they are shown as not evaluated rather than as not flagged.

## Examples

``` r
dfAnalyzed <- data.frame(
  GroupID = c("001", "002", "003"),
  GroupLevel = "Site",
  Numerator = c(1, 0, 0),
  Denominator = c(2, 2, 0),
  Metric = c(0.5, 0, NA),
  Score = c(3.1, 0.2, NA)
)
Flag_CTAS(dfAnalyzed)
#> ℹ Sorted dfFlagged using custom Flag order: 2.Sorted dfFlagged using custom Flag order: 1.Sorted dfFlagged using custom Flag order: 0.
#>   GroupID GroupLevel Numerator Denominator Metric Score Flag
#> 1     001       Site         1           2    0.5   3.1    2
#> 2     002       Site         0           2    0.0   0.2    0
#> 3     003       Site         0           0     NA    NA   NA
```
