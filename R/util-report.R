# Internal helpers backing Report_CTAS().

#' Collapse the CTAS metrics audit table to a `gsm.kri`-ready `dfMetrics`
#'
#' The audit table from [MakeMetric_CTAS()] is family-granular
#' (`MetricID = ctas_<family>_<field>`); the gsm KRI summary emitted by
#' [Summarize_CTAS()] is field-granular (`MetricID = ctas_<field>`).
#' `gsm.kri::MakeCharts()` requires the two frames to share a `MetricID`
#' vocabulary. Collapses to one row per field, filters to fields present
#' in `dfSummary`, and rewrites `MetricID`. First row per field wins.
#'
#' @param dfMetrics `data.frame` Output of [MakeMetric_CTAS()].
#' @param dfSummary `data.frame` Filtered CTAS summary. Must contain `MetricID`.
#'
#' @return `data.frame` One row per `MetricID` present in `dfSummary$MetricID`.
#'
#' @keywords internal
#' @noRd
Prune_Metrics <- function(dfMetrics, dfSummary) {
  AssertColumns(dfMetrics, c("MetricID", "parameter_category_2"), "dfMetrics")
  AssertColumns(dfSummary, "MetricID", "dfSummary")

  df <- dfMetrics
  df$MetricID <- paste0("ctas_", df$parameter_category_2)
  df <- df[df$MetricID %in% unique(dfSummary$MetricID), , drop = FALSE]
  df <- df[!duplicated(df$MetricID), , drop = FALSE]
  row.names(df) <- NULL
  df
}

#' Drop named chart entries from a `gsm.kri::MakeCharts()` result
#'
#' `lCharts` is nested: outer key is `MetricID`, inner keys are chart names
#' (`scatterPlot`, `barChart`, `metricTable`, `timeSeries`). The vendored
#' `Report_CTAS.Rmd` renders one tab per inner key.
#'
#' @param lCharts `list` Output of [gsm.kri::MakeCharts()].
#' @param vDropCharts `character` Inner chart names to remove from every metric.
#'
#' @return `list` `lCharts` with the requested inner entries removed.
#'
#' @keywords internal
#' @noRd
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
