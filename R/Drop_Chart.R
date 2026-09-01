#' Drop named chart entries from a `gsm.kri::MakeCharts()` result
#'
#' `lCharts` is nested: the outer key is `MetricID`, the inner keys are chart
#' names (`scatterPlot`, `barChart`, `metricTable`, `timeSeries`). The stock
#' `Report_CTAS.Rmd` renders one tab per inner key, so removing an
#' entry here suppresses that tab from the HTML report without editing the
#' template.
#'
#' @param lCharts `list` Output of [gsm.kri::MakeCharts()] -- a named list
#'   keyed by `MetricID`, whose elements are lists of chart widgets.
#' @param vDropCharts `character` Names of inner chart entries to remove
#'   from every metric. Names not present in a given metric slot are
#'   silently ignored. Default `character(0)` (no-op).
#'
#' @return `list` `lCharts` with the requested inner entries removed.
#'
#' @examples
#' lCharts <- list(
#'   ctas_AST = list(scatterPlot = "s1", barChart = "b1"),
#'   ctas_ALT = list(scatterPlot = "s2", barChart = "b2")
#' )
#' Drop_Chart(lCharts, "scatterPlot")
#'
#' @export
Drop_Chart <- function(lCharts, vDropCharts = character(0)) {
  if (!is.list(lCharts)) {
    cli::cli_abort("{.arg lCharts} must be a list.")
  }
  if (is.null(vDropCharts) || !length(vDropCharts)) {
    return(lCharts)
  }
  if (!is.character(vDropCharts)) {
    cli::cli_abort("{.arg vDropCharts} must be a character vector.")
  }
  lapply(lCharts, function(lMetricCharts) {
    if (!is.list(lMetricCharts)) return(lMetricCharts)
    lMetricCharts[setdiff(names(lMetricCharts), vDropCharts)]
  })
}
