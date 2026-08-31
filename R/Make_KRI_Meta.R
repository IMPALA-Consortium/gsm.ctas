#' Build a minimal gsm KRI `dfMetrics` for CTAS
#'
#' One row per unique `MetricID` in `dfSummary`, carrying the labels and
#' threshold string the `gsm.kri` overview widget and per-metric bar chart
#' consume.
#'
#' @param dfSummary `data.frame` Output of [Summarize_CTAS()] (or
#'   [Flag_CTAS()] on top of it); must contain `MetricID` and
#'   `parameter_category_2`.
#' @param vThreshold `numeric` Threshold values used by [Flag_CTAS()].
#'   Written verbatim into the `Threshold` string. Default
#'   `c(0.842, 2.326)`.
#'
#' @return `data.frame` with the gsm KRI `dfMetrics` columns: `MetricID`,
#'   `Abbreviation`, `Metric`, `Numerator`, `Denominator`, `Score`,
#'   `Threshold`, `GroupLevel`, `AnalysisType`, `Model`.
#'
#'   `Abbreviation` is the short label the `gsm.kri` site-overview widget
#'   uses as each metric column's header (see `gsm.viz` `defineMetricColumns`:
#'   `label: metric.Abbreviation`); an empty `Abbreviation` renders as an
#'   empty column header. It is set here to `parameter_category_2` (with
#'   `(feature)` appended when the summary is per-feature).
#'
#' @export
Make_KRI_Metrics <- function(dfSummary, vThreshold = c(0.842, 2.326)) {
  AssertColumns(dfSummary, c("MetricID", "parameter_category_2"), "dfSummary")

  bHasFeature <- "feature" %in% names(dfSummary)
  vKeyCols <- c("MetricID", "parameter_category_2",
                if (bHasFeature) "feature")
  dfKeys <- dplyr::distinct(dfSummary[, vKeyCols, drop = FALSE])

  vMetric <- if (bHasFeature) {
    paste0(dfKeys$parameter_category_2, " (", dfKeys$feature, ") -- CTAS")
  } else {
    paste0(dfKeys$parameter_category_2, " -- CTAS")
  }

  vAbbreviation <- if (bHasFeature) {
    paste0(dfKeys$parameter_category_2, " (", dfKeys$feature, ")")
  } else {
    dfKeys$parameter_category_2
  }

  data.frame(
    MetricID = dfKeys$MetricID,
    Abbreviation = vAbbreviation,
    Metric = vMetric,
    Numerator = "Timeseries x features scored",
    Denominator = "Distinct timeseries at site",
    Score = "CTAS score (-log10 p)",
    Threshold = paste(vThreshold, collapse = ","),
    GroupLevel = "Site",
    AnalysisType = "CTAS",
    Model = "ctas::process_a_study",
    stringsAsFactors = FALSE
  )
}
