#' Build the CTAS gsm KRI `dfMetrics` audit table
#'
#' One row per unique `(parameter_category_2, parameter_category_3)` pair
#' in the unfiltered stacked CTAS results, so every field the pipeline
#' scored appears in the table. Carries the labels the `gsm.kri` overview
#' widget and per-metric bar chart consume, plus one column per CTAS
#' parameter (Feature toggles, sample-size gates, scoring / padjust
#' methods, seed) harvested from each metric workflow's `meta:` block.
#'
#' `MetricID` is `ctas_<parameter_category_3>_<parameter_category_2>` --
#' family-granular so each `(field, metric family)` pair carries its own
#' CTAS parameter values distinctly. This is *not* the field-level
#' `MetricID` scheme emitted by [Summarize_CTAS()] (`ctas_<field>`); run
#' the audit through [Prune_Metrics()] to collapse it to the field-level
#' scheme `gsm.kri` expects for rendering.
#'
#' @param dfResults `data.frame` Unfiltered stacked CTAS results, typically
#'   `Reporting_Results$results` from the reporting `Results` workflow.
#'   Must carry `parameter_category_2` (field) and `parameter_category_3`
#'   (metric family). `parameter_id` and `parameter_category_1` are
#'   copied through when present.
#' @param lMetricWorkflows `list` Metric workflow YAML objects
#'   (`workr::MakeWorkflowList()` output from `inst/workflow/2_metrics`).
#'   Each element's `meta:` block supplies the CTAS parameter columns for
#'   the workflow whose `meta$ID` matches `parameter_category_3`. Metric
#'   families with no matching workflow get `NA` in the parameter columns.
#'   Default `NULL` -> every parameter column is `NA`.
#' @param vThreshold `numeric` Threshold values used by [Flag_CTAS()].
#'   Written verbatim into the `Threshold` string. Default
#'   `c(0.842, 2.326)`.
#' @param dfInput `data.frame` Optional stacked CTAS input frame
#'   (`Reporting_Results$input`), used only to look up `parameter_name`
#'   for each `parameter_id`. `NULL` -> `parameter_name` is `NA`.
#'
#' @return `data.frame` with the gsm KRI `dfMetrics` columns (`MetricID`,
#'   `Abbreviation`, `Metric`, `Score`, `Threshold`, `GroupLevel`,
#'   `AnalysisType`, `Model`) plus the CTAS identity columns
#'   (`parameter_id`, `parameter_name`, `parameter_category_1`,
#'   `parameter_category_2`, `parameter_category_3`) and one column per
#'   CTAS parameter surfaced from the metric YAMLs.
#'
#'   `Abbreviation` is the short label the `gsm.kri` site-overview widget
#'   uses as each metric column's header (see `gsm.viz`
#'   `defineMetricColumns`: `label: metric.Abbreviation`); an empty
#'   `Abbreviation` renders as an empty column header. It is set here to
#'   `parameter_category_2`.
#'
#' @seealso [Prune_Metrics()] to slim the audit table to a `gsm.kri`-ready
#'   one-row-per-`MetricID` frame.
#'
#' @export
MakeMetric_CTAS <- function(dfResults,
                            lMetricWorkflows = NULL,
                            vThreshold = c(0.842, 2.326),
                            dfInput = NULL) {
  AssertColumns(
    dfResults,
    c("parameter_category_2", "parameter_category_3"),
    "dfResults"
  )

  vIdCols <- intersect(
    c("parameter_id", "parameter_category_1",
      "parameter_category_2", "parameter_category_3"),
    names(dfResults)
  )
  dfKeys <- dplyr::distinct(dfResults[, vIdCols, drop = FALSE])
  dfKeys <- dfKeys[order(dfKeys$parameter_category_3,
                         dfKeys$parameter_category_2), , drop = FALSE]
  # A single (pc2, pc3) can carry more than one parameter_id when the raw
  # data has ambiguous inputs; keep the first so MetricID stays unique.
  dfKeys <- dfKeys[
    !duplicated(dfKeys[, c("parameter_category_2", "parameter_category_3")]), ,
    drop = FALSE
  ]

  vField <- dfKeys$parameter_category_2
  vType <- dfKeys$parameter_category_3
  vParamId <- if ("parameter_id" %in% names(dfKeys)) dfKeys$parameter_id else NA_character_
  vCat1 <- if ("parameter_category_1" %in% names(dfKeys)) dfKeys$parameter_category_1 else NA_character_
  vParamName <- LookupParameterName(vParamId, dfInput)

  dfBase <- data.frame(
    MetricID = paste0("ctas_", vType, "_", vField),
    parameter_id = vParamId,
    parameter_name = vParamName,
    parameter_category_1 = vCat1,
    parameter_category_2 = vField,
    parameter_category_3 = vType,
    Abbreviation = vField,
    Metric = paste0(vField, " -- ", vType),
    Score = "CTAS score (-log10 p)",
    Threshold = paste(vThreshold, collapse = ","),
    GroupLevel = "Site",
    AnalysisType = "CTAS",
    Model = "ctas::process_a_study",
    stringsAsFactors = FALSE,
    row.names = NULL
  )

  dfParams <- MetricParamsFrame(vType, lMetricWorkflows)

  cbind(dfBase, dfParams)
}

#' Collapse the CTAS metrics audit table to a `gsm.kri`-ready `dfMetrics`
#'
#' The audit table from [MakeMetric_CTAS()] carries one row per
#' `(parameter_category_2, parameter_category_3)` with a family-granular
#' `MetricID` (`ctas_<family>_<field>`). The gsm KRI summary emitted by
#' [Summarize_CTAS()] is field-granular (`MetricID = ctas_<field>`) and
#' `gsm.kri` requires the two frames to share a `MetricID` vocabulary.
#'
#' `Prune_Metrics()` collapses the audit down to one row per field, filters
#' to the fields present in `dfSummary`, and rewrites `MetricID` to
#' `ctas_<parameter_category_2>` so downstream `gsm.kri::MakeCharts()`
#' joins cleanly. When multiple metric families exist for the same field
#' the first row (by input order) wins; sponsors who need per-family
#' parameter values should consume `Reporting_Metrics` directly.
#'
#' @param dfMetrics `data.frame` Output of [MakeMetric_CTAS()]. Must carry
#'   `parameter_category_2`.
#' @param dfSummary `data.frame` Filtered CTAS summary. Must contain
#'   `MetricID`.
#'
#' @return `data.frame` One row per `MetricID` present in
#'   `dfSummary$MetricID`, preserving column order of `dfMetrics`.
#'
#' @export
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
