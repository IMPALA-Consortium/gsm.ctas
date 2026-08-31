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
#'   `Metric`, `Numerator`, `Denominator`, `Threshold`, `GroupLevel`,
#'   `AnalysisType`, `Model`.
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

  data.frame(
    MetricID = dfKeys$MetricID,
    Metric = vMetric,
    Numerator = "Timeseries x features scored",
    Denominator = "Distinct timeseries at site",
    Threshold = paste(vThreshold, collapse = ","),
    GroupLevel = "Site",
    AnalysisType = "CTAS",
    Model = "ctas::process_a_study",
    stringsAsFactors = FALSE
  )
}

#' Build a minimal gsm KRI `dfGroups` from a subjects frame
#'
#' Long-format `MakeLongMeta`-shaped group metadata for the `gsm.kri` site
#' report. Emits two blocks:
#'
#' * `GroupLevel == "Site"`: `Enrolled` (distinct subjects per site) and a
#'   `InvestigatorLastName` placeholder so the KRI overview widget can
#'   render without erroring on a missing param.
#' * `GroupLevel == "Study"`: `SiteCount`, `ParticipantCount` and `Status`
#'   per `studyid` so `gsm.kri::Report_StudyInfo()` -> `MakeStudyInfo()`
#'   has rows to label.
#'
#' Richer site meta (country, region, planned vs actual enrolment) is left
#' for a follow-up wave.
#'
#' @param dfSubjects `data.frame` Standardised subjects with `studyid`,
#'   `subject_id` and `site`.
#'
#' @return `data.frame` with columns `GroupID`, `GroupLevel`, `Param`,
#'   `Value`.
#'
#' @export
Make_KRI_Groups <- function(dfSubjects) {
  AssertColumns(dfSubjects, c("studyid", "subject_id", "site"), "dfSubjects")

  dfEnrolled <- dfSubjects |>
    dplyr::group_by(site = as.character(.data$site)) |>
    dplyr::summarise(
      Enrolled = dplyr::n_distinct(.data$subject_id),
      .groups = "drop"
    ) |>
    dplyr::transmute(
      GroupID = .data$site,
      GroupLevel = "Site",
      Param = "Enrolled",
      Value = as.character(.data$Enrolled)
    )

  dfInv <- data.frame(
    GroupID = sort(unique(as.character(dfSubjects$site))),
    GroupLevel = "Site",
    Param = "InvestigatorLastName",
    Value = NA_character_,
    stringsAsFactors = FALSE
  )

  dfStudy <- dfSubjects |>
    dplyr::group_by(studyid = as.character(.data$studyid)) |>
    dplyr::summarise(
      SiteCount = dplyr::n_distinct(.data$site),
      ParticipantCount = dplyr::n_distinct(.data$subject_id),
      .groups = "drop"
    )
  dfStudyLong <- dplyr::bind_rows(
    data.frame(
      GroupID = dfStudy$studyid,
      GroupLevel = "Study",
      Param = "SiteCount",
      Value = as.character(dfStudy$SiteCount),
      stringsAsFactors = FALSE
    ),
    data.frame(
      GroupID = dfStudy$studyid,
      GroupLevel = "Study",
      Param = "ParticipantCount",
      Value = as.character(dfStudy$ParticipantCount),
      stringsAsFactors = FALSE
    ),
    data.frame(
      GroupID = dfStudy$studyid,
      GroupLevel = "Study",
      Param = "Status",
      Value = "Active",
      stringsAsFactors = FALSE
    )
  )

  as.data.frame(dplyr::bind_rows(dfEnrolled, dfInv, dfStudyLong))
}
