# Remove named charts from a `gsm.kri` chart list

[`gsm.kri::MakeCharts()`](https://gilead-public.github.io/gsm.kri/reference/MakeCharts.html)
returns, for each metric, a list of widgets keyed by chart type.
[`gsm.kri::Report_MetricCharts()`](https://gilead-public.github.io/gsm.kri/reference/Report_MetricCharts.html)
renders whatever that list contains, so a chart can be suppressed by
dropping it here rather than by forking the report template.

## Usage

``` r
DropChart(lCharts, strChart = "scatterPlot")
```

## Arguments

- lCharts:

  `list` Named list of per-metric chart lists, as returned by
  [`gsm.kri::MakeCharts()`](https://gilead-public.github.io/gsm.kri/reference/MakeCharts.html).

- strChart:

  `character` Chart keys to drop, e.g. `"scatterPlot"`.

## Value

`lCharts` with the named charts removed from every metric. Metrics that
never had the chart are returned unchanged.

## Details

This exists because the stock scatter plot is not meaningful for CTAS.
It plots `Denominator` on x against `Numerator` on y, which suits a rate
metric where the denominator is exposure. For CTAS the denominator is
the number of timeseries evaluated for the feature, which is identical
across sites unless a site lacks a parameter altogether, so the points
collapse onto one or two x positions.

## Examples

``` r
lCharts <- list(
  Analysis_ctas0001 = list(scatterPlot = 1, barChart = 2, metricTable = 3)
)
names(DropChart(lCharts, "scatterPlot")$Analysis_ctas0001)
#> [1] "barChart"    "metricTable"
```
