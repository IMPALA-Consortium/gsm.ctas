#' Build a chart list for every CTAS MetricID
#'
#' Thin wrapper around `Visualize_CTAS()` that loops over
#' `unique(dfMetrics$MetricID)` and returns a named list keyed by
#' MetricID. Mirrors `gsm.simaerep::MakeCharts()` so [Report_CTAS()] can
#' control the CTAS bar-chart outcome list without inheriting
#' `gsm.kri::MakeCharts()`'s Numerator/Denominator defaults
#' (`Numerator`, `Denominator`, `Metric`).
#'
#' @inheritParams gsm.kri::MakeCharts
#' @param strVisualizeFun Fully-qualified name of the per-metric
#'   visualization function to dispatch to.
#' @param ... Forwarded to `strVisualizeFun`.
#'
#' @return Named list; one entry per MetricID.
#'
#' @keywords internal
#' @noRd
MakeCharts <- function(
  dfResults,
  dfMetrics,
  dfGroups = NULL,
  dfBounds = NULL,
  bDebug = FALSE,
  strVisualizeFun = "gsm.ctas:::Visualize_CTAS",
  ...
) {
  strMetrics <- unique(dfMetrics$MetricID)

  lArgs <- list(
    dfResults = dfResults,
    dfMetrics = dfMetrics,
    dfGroups = dfGroups,
    dfBounds = dfBounds,
    bDebug = bDebug,
    ...
  )

  fun <- eval(parse(text = strVisualizeFun))

  lCharts <- lapply(strMetrics, function(strMetricID) {
    lArgs$strMetricID <- strMetricID
    do.call(fun, lArgs)
  })
  names(lCharts) <- strMetrics

  lCharts
}


#' Build the per-metric CTAS chart list
#'
#' Bar, metric table, and (multi-snapshot) time series for a single CTAS
#' MetricID. Mirrors `gsm.simaerep::Visualize_Metric_Simaerep()` but drops
#' the `Numerator`/`Denominator`/`Metric` outcomes from
#' `Widget_BarChart` -- [Summarize_CTAS()] only emits `Score`, so those
#' tabs would render empty.
#'
#' @param dfResults `data.frame` from [Summarize_CTAS()].
#' @param dfMetrics Optional single-row `data.frame` describing the
#'   metric; the row is coerced to a list and passed as `lMetric` to the
#'   `gsm.kri` widgets.
#' @param dfGroups Optional `data.frame` of group metadata.
#' @param dfBounds Optional bounds frame; unused, accepted for signature
#'   compatibility with `MakeCharts()`.
#' @param strMetricID Optional MetricID to filter to. When supplied and
#'   absent from `dfResults`, returns `NULL`.
#' @param strSnapshotDate Optional snapshot date; defaults to
#'   `max(dfResults$SnapshotDate)`.
#' @param bDebug Passed through to the `gsm.kri` widgets.
#' @param vResultTooltipKeys Columns shown in widget tooltips.
#' @param vOutcomeOptions Y-axis choices exposed by
#'   [gsm.kri::Widget_BarChart()]. Default is `"Score"` only.
#' @param ... Forwarded to the `gsm.kri` widgets.
#'
#' @return Named list of htmlwidgets, or `NULL` if no data survives
#'   filtering.
#'
#' @keywords internal
#' @noRd
Visualize_CTAS <- function(
  dfResults,
  dfMetrics = NULL,
  dfGroups = NULL,
  dfBounds = NULL,
  strMetricID = NULL,
  strSnapshotDate = NULL,
  bDebug = FALSE,
  vResultTooltipKeys = c("Score"),
  vOutcomeOptions = c("Score"),
  ...
) {
  rlang::check_installed("gsm.kri", reason = "to run `Visualize_CTAS()`.")
  rlang::check_installed("gsm.core", reason = "to run `Visualize_CTAS()`.")

  if (!"SnapshotDate" %in% colnames(dfResults)) {
    dfResults$SnapshotDate <- as.Date(Sys.Date())
  }

  intSnapshots <- length(unique(dfResults$SnapshotDate))

  if (is.null(strSnapshotDate)) {
    strSnapshotDate <- max(dfResults$SnapshotDate)
  }

  if (!is.null(strMetricID) && "MetricID" %in% colnames(dfResults)) {
    if (!(strMetricID %in% unique(dfResults$MetricID))) {
      return(NULL)
    }
    dfResults <- dfResults[dfResults$MetricID == strMetricID, , drop = FALSE]
  }

  if (!is.null(strMetricID) && !is.null(dfMetrics) &&
    "MetricID" %in% colnames(dfMetrics)) {
    if (!(strMetricID %in% unique(dfMetrics$MetricID))) {
      dfMetrics <- NULL
    } else {
      dfMetrics <- dfMetrics[dfMetrics$MetricID == strMetricID, , drop = FALSE]
    }
  }

  if (is.null(dfMetrics)) {
    lMetric <- NULL
    vThreshold <- NULL
  } else {
    lMetric <- as.list(dfMetrics)
    vThreshold <- gsm.core::ParseThreshold(lMetric$Threshold, bSort = FALSE)
  }

  lCharts <- list()

  dfResults_latest <- gsm.kri::FilterByLatestSnapshotDate(
    dfResults, strSnapshotDate
  )

  if (nrow(dfResults_latest) == 0) {
    return(NULL)
  }

  # Widget_BarChart expects these columns to be presents
  # even though we only display score
  dfResults_latest$Numerator <- NA
  dfResults_latest$Denominator <- NA
  dfResults_latest$Metric <- NA

  lCharts$barChart <- gsm.kri::Widget_BarChart(
    dfResults = dfResults_latest,
    lMetric = lMetric,
    dfGroups = dfGroups,
    vThreshold = vThreshold,
    bDebug = bDebug,
    vResultTooltipKeys = vResultTooltipKeys,
    vOutcomeOptions = vOutcomeOptions,
    ...
  )

  # remove columns again for Metric_Table
  dfResults_latest$Numerator <- NULL
  dfResults_latest$Denominator <- NULL
  dfResults_latest$Metric <- NULL

  if (!is.null(lMetric)) {
    lCharts$metricTable <- gsm.kri::Report_MetricTable(
      dfResults = dfResults_latest,
      dfGroups = dfGroups,
      strGroupLevel = lMetric$GroupLevel
    )
  } else {
    dfResults_latest$MetricID <- NA
    lCharts$metricTable <- gsm.kri::Report_MetricTable(dfResults_latest)
  }

  if (intSnapshots > 1) {
    lCharts$timeSeries <- do.call(
      gsm.kri::Widget_TimeSeries,
      list(
        dfResults = dfResults,
        lMetric = lMetric,
        dfGroups = dfGroups,
        vThreshold = vThreshold,
        bDebug = bDebug,
        ...
      )
    )
  }

  lCharts
}
