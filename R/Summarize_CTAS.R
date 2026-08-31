#' Aggregate CTAS site scores into a gsm-shaped KRI summary
#'
#' Pivots the long CTAS results frame (one row per site x timeseries x
#' feature) into the gsm reporting `dfResults` contract (one row per site x
#' synthetic `MetricID`) so the stock `gsm.kri` KRI report can render it
#' unchanged. Each `parameter_category_2` (data field, e.g. `"AST"`,
#' `"SYSBP"`) becomes its own `MetricID`; when `bByFeature = TRUE`, one
#' `MetricID` per (field x CTAS feature) is emitted instead.
#'
#' The `Score` is the max `fdr_corrected_pvalue_logp` across every
#' contributing (timeseries x feature) row in the group. Sites present in
#' `dfSubjects` but absent from `dfResults` (e.g. no scorable timeseries for
#' a field) are retained with `Score = NA`, `Numerator = 0`,
#' `Denominator = 0` so the KRI overview table cannot silently drop them.
#'
#' `Flag` is intentionally not emitted here -- run [Flag_CTAS()] on the
#' returned frame to add it. Splitting Summarize + Flag mirrors the
#' `gsm.core::Summarize()` / `gsm.core::Flag()` seam so users can swap
#' thresholds without re-aggregating.
#'
#' @param dfResults `data.frame` Stacked CTAS results, typically
#'   `Reporting_Results$results` from the reporting Results workflow. Must
#'   contain `study`, `site`, `parameter_category_2`, `parameter_category_3`,
#'   `feature`, `fdr_corrected_pvalue_logp`, `timeseries_id`.
#' @param dfSubjects `data.frame` Standardised subjects with `studyid`,
#'   `subject_id`, `site`. Used to complete the (study x site x MetricID)
#'   grid so sites with no scored timeseries stay visible.
#' @param bIncludeMissingness `logical` Include the `ratio_missing` metric
#'   family (`parameter_category_3 == "ratio_missing"`) in the aggregation.
#'   Default `TRUE`.
#' @param bByFeature `logical` Group by (data field x CTAS feature) instead
#'   of by data field only. Default `FALSE`.
#' @param strStudyID `character` Optional single StudyID used for every row
#'   (overrides per-row `study`). Default `NULL` -> use the `study` column.
#' @param dSnapshotDate `Date` Snapshot date stamped on every row. Default
#'   `Sys.Date()`.
#'
#' @return `data.frame` with the gsm reporting `dfResults` columns
#'   (`MetricID`, `GroupID`, `GroupLevel`, `StudyID`, `SnapshotDate`,
#'   `Numerator`, `Denominator`, `Metric`, `Score`) plus the CTAS grouping
#'   keys (`parameter_category_2`, and `feature` when `bByFeature = TRUE`)
#'   so downstream steps can label metrics without a re-join.
#'
#' @seealso [Flag_CTAS()] to add the `Flag` column.
#'
#' @examples
#' \dontrun{
#' lReporting <- gsm.core::RunWorkflows(
#'   lReportingWorkflows["Results"],
#'   lData = c(lMapped, list(lAnalyzed = lAnalysis))
#' )
#' dfSummary <- Summarize_CTAS(
#'   dfResults = lReporting$Reporting_Results$results,
#'   dfSubjects = lMapped$Mapped_Subjects
#' )
#' }
#'
#' @export
Summarize_CTAS <- function(dfResults,
                           dfSubjects,
                           bIncludeMissingness = TRUE,
                           bByFeature = FALSE,
                           strStudyID = NULL,
                           dSnapshotDate = Sys.Date()) {
  AssertColumns(
    dfResults,
    c("study", "site", "parameter_category_2", "parameter_category_3",
      "feature", "fdr_corrected_pvalue_logp", "timeseries_id"),
    "dfResults"
  )
  AssertColumns(dfSubjects, c("studyid", "subject_id", "site"), "dfSubjects")
  if (!is.logical(bIncludeMissingness) || length(bIncludeMissingness) != 1) {
    cli::cli_abort("{.arg bIncludeMissingness} must be a single logical value.")
  }
  if (!is.logical(bByFeature) || length(bByFeature) != 1) {
    cli::cli_abort("{.arg bByFeature} must be a single logical value.")
  }

  df <- dfResults
  if (!bIncludeMissingness) {
    df <- df[df$parameter_category_3 != "ratio_missing", , drop = FALSE]
  }

  vMetricKeys <- if (bByFeature) {
    c("parameter_category_2", "feature")
  } else {
    "parameter_category_2"
  }
  vGroupCols <- c("study", "site", vMetricKeys)

  dfAgg <- df |>
    dplyr::group_by(dplyr::across(dplyr::all_of(vGroupCols))) |>
    dplyr::summarise(
      Score = suppressWarnings(max(.data$fdr_corrected_pvalue_logp, na.rm = TRUE)),
      Numerator = dplyr::n(),
      Denominator = dplyr::n_distinct(.data$timeseries_id),
      .groups = "drop"
    ) |>
    dplyr::mutate(Score = ifelse(is.finite(.data$Score), .data$Score, NA_real_))

  dfSitesByStudy <- dplyr::distinct(dplyr::transmute(
    dfSubjects,
    study = as.character(.data$studyid),
    site = as.character(.data$site)
  ))

  dfMetricKeys <- dplyr::distinct(dfAgg[, vMetricKeys, drop = FALSE])

  if (nrow(dfMetricKeys) == 0 || nrow(dfSitesByStudy) == 0) {
    dfComplete <- dfAgg[0, , drop = FALSE]
  } else {
    dfGrid <- dplyr::cross_join(dfSitesByStudy, dfMetricKeys)
    dfComplete <- dplyr::left_join(dfGrid, dfAgg, by = vGroupCols)
  }

  dfComplete$Numerator[is.na(dfComplete$Numerator)] <- 0L
  dfComplete$Denominator[is.na(dfComplete$Denominator)] <- 0L

  dfComplete$MetricID <- if (bByFeature) {
    paste0("ctas_", dfComplete$parameter_category_2, "_", dfComplete$feature)
  } else {
    paste0("ctas_", dfComplete$parameter_category_2)
  }

  dfComplete$GroupID <- dfComplete$site
  dfComplete$GroupLevel <- "Site"
  dfComplete$StudyID <- if (is.null(strStudyID)) {
    dfComplete$study
  } else {
    rep(as.character(strStudyID), nrow(dfComplete))
  }
  dfComplete$SnapshotDate <- dSnapshotDate
  dfComplete$Metric <- dfComplete$Score

  vOutCols <- c(
    "MetricID", "GroupID", "GroupLevel", "StudyID", "SnapshotDate",
    "Numerator", "Denominator", "Metric", "Score",
    vMetricKeys
  )
  as.data.frame(dfComplete[, vOutCols, drop = FALSE])
}
