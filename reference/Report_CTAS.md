# Render the CTAS site-level report from a CTAS summary

One-call wrapper that runs the chart-preparation pipeline
(`Prune_Metrics()` -\> `MakeCharts()`) and hands the result to
[`gsm.kri::Report_KRI()`](https://gilead-public.github.io/gsm.kri/reference/Report_KRI.html)
together with the vendored `inst/report/Report_CTAS.Rmd` template. The
chart builder is the internal `MakeCharts()` / `Visualize_CTAS()` pair
(not
[`gsm.kri::MakeCharts()`](https://gilead-public.github.io/gsm.kri/reference/MakeCharts.html))
so `Widget_BarChart` only offers `"Score"` – the CTAS `dfResults`
contract has no `Numerator`/`Denominator`/`Metric` columns.

## Usage

``` r
Report_CTAS(
  lReporting,
  strOutputDir = getwd(),
  strOutputFile = NULL,
  dfBounds = NULL,
  ...
)
```

## Arguments

- lReporting:

  Named list with `summary`, `metrics`, `groups` frames – the shape
  produced by [`Summarize_CTAS()`](Summarize_CTAS.md).

- strOutputDir:

  Output directory for the rendered html.

- strOutputFile:

  Output file name; defaults to `Report_KRI`'s auto-generated name.

- dfBounds:

  Optional bounds frame forwarded to the internal `MakeCharts()`.

- ...:

  Further arguments forwarded to
  [`gsm.kri::Report_KRI()`](https://gilead-public.github.io/gsm.kri/reference/Report_KRI.html).

## Value

`character(1)` File path of the rendered html report, invisibly.

## Details

`strOutputDir` is normalized to an absolute path so
[`rmarkdown::render()`](https://pkgs.rstudio.com/rmarkdown/reference/render.html)
doesn't resolve it against the template's directory. `strInputPath` is
resolved via [`system.file()`](https://rdrr.io/r/base/system.file.html)
inside the `gsm.ctas` namespace so `pkgload`'s `inst/` shim picks it up
under `devtools::load_all()`.
