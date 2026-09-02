#' Render the standard gsm.kri site-level KRI report from a CTAS summary
#'
#' One-call wrapper that runs the chart-preparation pipeline
#' (`Prune_Metrics()` -> [gsm.kri::MakeCharts()] -> `Drop_Chart()`) and
#' hands the result to [gsm.kri::Report_KRI()] together with the vendored
#' `inst/report/Report_CTAS.Rmd` template.
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
#' @param vDropCharts Character vector of inner chart tab names to omit
#'   (e.g. `"scatterPlot"`).
#' @param dfBounds Optional bounds frame for [gsm.kri::MakeCharts()].
#' @param ... Further arguments forwarded to [gsm.kri::Report_KRI()].
#'
#' @return `character(1)` File path of the rendered html report, invisibly.
#'
#' @export
Report_CTAS <- function(lReporting,
                        strOutputDir = getwd(),
                        strOutputFile = NULL,
                        vDropCharts = NULL,
                        dfBounds = NULL,
                        ...) {
  rlang::check_installed("gsm.kri", reason = "to run `Report_CTAS()`.")

  dfResults <- lReporting[["summary"]]
  dfMetrics <- lReporting[["metrics"]]
  dfGroups  <- lReporting[["groups"]]

  # MakeCharts keys lCharts by MetricID; audit's family-level MetricIDs
  # won't match dfResults, so collapse to field-level just for chart building.
  dfMetricsPruned <- Prune_Metrics(dfMetrics = dfMetrics, dfSummary = dfResults)

  lCharts <- gsm.kri::MakeCharts(
    dfResults = dfResults,
    dfMetrics = dfMetricsPruned,
    dfGroups = dfGroups,
    dfBounds = dfBounds
  )

  if (length(vDropCharts) > 0) {
    lCharts <- Drop_Chart(lCharts = lCharts, vDropCharts = vDropCharts)
  }

  gsm.kri::Report_KRI(
    lCharts = lCharts,
    dfResults = dfResults,
    dfMetrics = dfMetrics,
    dfGroups = dfGroups,
    strOutputDir = normalizePath(strOutputDir, mustWork = FALSE),
    strOutputFile = strOutputFile,
    strInputPath = system.file("report", "Report_CTAS.Rmd", package = "gsm.ctas"),
    ...
  )
}
