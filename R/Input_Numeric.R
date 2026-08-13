#' Map a numeric findings domain to CTAS input
#'
#' Produces one CTAS timeseries per subject and test code from a plain numeric
#' findings domain such as VS. Values are used as-is; use [Input_Range()] when
#' reference ranges are available and values must be made comparable across
#' tests.
#'
#' The function is named for the *data type*, not the SDTM domain, so the same
#' code serves VS, EG or any other numeric findings domain. Domain-specific
#' knowledge lives in the column arguments, supplied from the workflow YAML.
#'
#' @inheritParams StandardizeDomain
#' @param strCategory `character` Value written to `parameter_category_1`,
#'   used as the display grouping in downstream tools.
#' @param strPrefix `character` Prefix for the generated `parameter_id`.
#'
#' @return `list` with elements `data`, `parameters` and `untransformed`,
#'   ready to be passed to [Combine_CTAS_Input()].
#'
#' @examples
#' Input_Numeric(data.frame(
#'   USUBJID = c("S1", "S1"),
#'   VSTESTCD = c("SYSBP", "SYSBP"),
#'   VSTEST = c("Systolic Blood Pressure", "Systolic Blood Pressure"),
#'   VISIT = c("WEEK 2", "WEEK 4"),
#'   VISITNUM = c(3, 4),
#'   VSSTRESN = c(120, 124)
#' ))
#'
#' @export
Input_Numeric <- function(dfDomain,
                          strSubjectCol = "USUBJID",
                          strTestCDCol = "VSTESTCD",
                          strTestCol = "VSTEST",
                          strValueCol = "VSSTRESN",
                          strVisitCol = "VISIT",
                          strVisitNumCol = "VISITNUM",
                          strVisitPattern = NULL,
                          strExcludePattern = "unsch",
                          strCategory = "Vital Signs",
                          strPrefix = "VS") {
  dfWork <- StandardizeDomain(
    dfDomain,
    strSubjectCol = strSubjectCol,
    strTestCDCol = strTestCDCol,
    strTestCol = strTestCol,
    strValueCol = strValueCol,
    strVisitCol = strVisitCol,
    strVisitNumCol = strVisitNumCol,
    strVisitPattern = strVisitPattern,
    strExcludePattern = strExcludePattern
  ) |>
    dplyr::filter(!is.na(.data$Value)) |>
    dplyr::mutate(
      parameter_id = paste0(.env$strPrefix, "_", .data$TestCD),
      result = as.numeric(.data$Value)
    )

  if (nrow(dfWork) == 0) {
    return(list(
      data = EmptyCTASData(),
      parameters = EmptyCTASParameters(),
      untransformed = EmptyCTASUntransformed()
    ))
  }

  dfParameters <- dfWork |>
    dplyr::distinct(.data$parameter_id, .data$TestCD, .data$TestName) |>
    dplyr::transmute(
      parameter_id = .data$parameter_id,
      parameter_name = paste0(.env$strCategory, ": ", .data$TestName),
      parameter_category_1 = .env$strCategory,
      parameter_category_2 = .data$parameter_id,
      parameter_category_3 = "numeric"
    ) |>
    as.data.frame()

  dfUntransformed <- dfWork |>
    dplyr::transmute(
      subject_id = .data$subject_id,
      parameter_category_2 = .data$parameter_id,
      timepoint_1_name = .data$timepoint_1_name,
      original_value = .data$result,
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
