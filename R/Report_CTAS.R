#' Render the CTAS site-level report from a CTAS summary
#'
#' One-call wrapper that runs the chart-preparation pipeline
#' (`Prune_Metrics()` -> `MakeCharts()`) and hands the
#' result to [gsm.kri::Report_KRI()] together with the vendored
#' `inst/report/Report_CTAS.Rmd` template. The chart builder is the
#' internal `MakeCharts()` / `Visualize_CTAS()` pair (not
#' `gsm.kri::MakeCharts()`) so `Widget_BarChart` only offers `"Score"`
#' -- the CTAS `dfResults` contract has no
#' `Numerator`/`Denominator`/`Metric` columns.
#'
#' `strOutputDir` is normalized to an absolute path so `rmarkdown::render()`
#' doesn't resolve it against the template's directory. `strInputPath` is
#' resolved via `system.file()` inside the `gsm.ctas` namespace so
#' `pkgload`'s `inst/` shim picks it up under `devtools::load_all()`.
#'
#' @param lReporting Named list with `summary`, `metrics`, `groups` frames
#'   -- the shape produced by [Summarize_CTAS()].
#' @param strOutputDir Output directory for the rendered html.
#' @param strOutputFile Output file name; defaults to `Report_KRI`'s
#'   auto-generated name.
#' @param dfBounds Optional bounds frame forwarded to the internal
#'   `MakeCharts()`.
#' @param ... Further arguments forwarded to [gsm.kri::Report_KRI()].
#'
#' @return `character(1)` File path of the rendered html report, invisibly.
#'
#' @export
Report_CTAS <- function(lReporting,
                        strOutputDir = getwd(),
                        strOutputFile = NULL,
                        dfBounds = NULL,
                        ...) {
  rlang::check_installed("gsm.kri", reason = "to run `Report_CTAS()`.")

  lReport <- Prepare_CTAS_Report(lReporting, dfBounds = dfBounds)

  gsm.kri::Report_KRI(
    lCharts       = lReport$lCharts,
    dfResults     = lReport$dfResults,
    dfMetrics     = lReport$dfMetrics,
    dfGroups      = lReport$dfGroups,
    strOutputDir  = normalizePath(strOutputDir, mustWork = FALSE),
    strOutputFile = strOutputFile,
    strInputPath  = system.file("report", "Report_CTAS.Rmd", package = "gsm.ctas"),
    ...
  )
}
