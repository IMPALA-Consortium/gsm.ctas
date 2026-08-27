#' Map a findings frame to a missingness-ratio CTAS input
#'
#' Turns data *completeness* into a timeseries: for each subject and test, the
#' running proportion of missing results over visits ([Prepare_MissingRatio()]).
#' This lets CTAS flag sites whose reporting completeness deviates from the
#' study, which the value-based inputs cannot see because they drop `NA` rows.
#'
#' Unlike the other `Input_*()` functions, rows with missing results are
#' retained - they are the signal.
#'
#' @inheritParams Input_Numeric
#'
#' @return `list` with elements `data`, `parameters` and `untransformed`.
#'
#' @examples
#' Input_Missing(data.frame(
#'   studyid = "A",
#'   subject_id = c("S1", "S1"),
#'   parameter_id = c("ALT", "ALT"),
#'   parameter_name = c("Alanine Aminotransferase", "Alanine Aminotransferase"),
#'   parameter_category_1 = "Labs",
#'   visit = c("WEEK 2", "WEEK 4"),
#'   visitnum = c(3, 4),
#'   value = c(20, NA)
#' ))
#'
#' @export
Input_Missing <- function(dfDomain,
                          strSubjectCol = "subject_id",
                          strTestCDCol = "parameter_id",
                          strTestCol = "parameter_name",
                          strValueCol = "value",
                          strVisitCol = "visit",
                          strVisitNumCol = "visitnum",
                          strStudyCol = "studyid",
                          strCategoryCol = "parameter_category_1",
                          strVisitPattern = NULL,
                          strExcludePattern = NULL,
                          strCategory = NA_character_,
                          strPrefix = "MISS") {
  dfWork <- StandardizeDomain(
    dfDomain,
    strSubjectCol = strSubjectCol,
    strTestCDCol = strTestCDCol,
    strTestCol = strTestCol,
    strValueCol = strValueCol,
    strVisitCol = strVisitCol,
    strVisitNumCol = strVisitNumCol,
    strStudyCol = strStudyCol,
    strCategoryCol = strCategoryCol,
    strVisitPattern = strVisitPattern,
    strExcludePattern = strExcludePattern
  ) |>
    dplyr::mutate(parameter_id = paste0(.env$strPrefix, "_", .data$TestCD)) |>
    dplyr::arrange(
      .data$subject_id, .data$parameter_id,
      .data$timepoint_rank, .data$timepoint_1_name
    )

  if (nrow(dfWork) == 0) {
    return(list(
      data = EmptyCTASData(),
      parameters = EmptyCTASParameters(),
      untransformed = EmptyCTASUntransformed()
    ))
  }

  dfWork$result <- Prepare_MissingRatio(
    vValue = dfWork$Value,
    vSubjectID = dfWork$subject_id,
    vParameterID = dfWork$parameter_id
  )

  vCategoryCols <- if ("Category" %in% names(dfWork)) "Category" else character(0)
  dfParameters <- dfWork |>
    dplyr::distinct(dplyr::across(dplyr::all_of(c(
      "parameter_id", "TestCD", "TestName", vCategoryCols
    )))) |>
    dplyr::mutate(
      parameter_category_1 = if ("Category" %in% names(dfWork)) {
        dplyr::coalesce(.data$Category, .env$strCategory)
      } else {
        .env$strCategory
      }
    ) |>
    dplyr::transmute(
      parameter_id = .data$parameter_id,
      parameter_name = paste0("Ratio Missing: ", .data$TestName),
      parameter_category_1 = .data$parameter_category_1,
      parameter_category_2 = .data$parameter_id,
      parameter_category_3 = "ratio_missing"
    ) |>
    as.data.frame()

  dfUntransformed <- dfWork |>
    dplyr::transmute(
      subject_id = .data$subject_id,
      parameter_category_2 = .data$parameter_id,
      timepoint_1_name = .data$timepoint_1_name,
      original_value = as.numeric(.data$Value),
      lower = NA_real_,
      upper = NA_real_,
      original_category = NA_character_
    ) |>
    as.data.frame()

  list(
    data = BuildCTASData(dfWork),
    parameters = dfParameters,
    untransformed = dfUntransformed
  )
}
