#' Remove named charts from a `gsm.kri` chart list
#'
#' [gsm.kri::MakeCharts()] returns, for each metric, a list of widgets keyed by
#' chart type. `gsm.kri::Report_MetricCharts()` renders whatever that list
#' contains, so a chart can be suppressed by dropping it here rather than by
#' forking the report template.
#'
#' This exists because the stock scatter plot is not meaningful for CTAS. It
#' plots `Denominator` on x against `Numerator` on y, which suits a rate metric
#' where the denominator is exposure. For CTAS the denominator is the number of
#' timeseries evaluated for the feature, which is identical across sites unless
#' a site lacks a parameter altogether, so the points collapse onto one or two x
#' positions.
#'
#' @param lCharts `list` Named list of per-metric chart lists, as returned by
#'   [gsm.kri::MakeCharts()].
#' @param strChart `character` Chart keys to drop, e.g. `"scatterPlot"`.
#'
#' @return `lCharts` with the named charts removed from every metric. Metrics
#'   that never had the chart are returned unchanged.
#'
#' @examples
#' lCharts <- list(
#'   Analysis_ctas0001 = list(scatterPlot = 1, barChart = 2, metricTable = 3)
#' )
#' names(DropChart(lCharts, "scatterPlot")$Analysis_ctas0001)
#'
#' @export
DropChart <- function(lCharts, strChart = "scatterPlot") {
  if (!is.list(lCharts)) {
    cli::cli_abort("{.arg lCharts} must be a {.cls list}.")
  }
  if (!rlang::is_character(strChart)) {
    cli::cli_abort("{.arg strChart} must be a character vector.")
  }

  # `MakeCharts()` yields NULL for a metric with no matching results; keep those
  # as-is so the report still reports the metric as unevaluated.
  purrr::map(lCharts, function(lMetricCharts) {
    if (!is.list(lMetricCharts)) {
      return(lMetricCharts)
    }
    lMetricCharts[!names(lMetricCharts) %in% strChart]
  })
}
