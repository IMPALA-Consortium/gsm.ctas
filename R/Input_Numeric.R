#' Map a numeric findings frame to CTAS input
#'
#' Produces one CTAS timeseries per subject and test code from a plain numeric
#' findings frame. Values are used as-is; use [Input_Range()] when reference
#' ranges are available and values must be made comparable across tests.
#'
#' The function is named for the *data type*, not the SDTM domain, so the same
#' code serves VS, EG or any other numeric findings source. The metric YAML
#' points `Input_Numeric()` at the source columns via its `str*Col` overrides;
#' no intermediate mapping frame is required.
#'
#' @inheritParams StandardizeDomain
#' @param strCategory `character` Fallback value written to
#'   `parameter_category_1` when `strCategoryCol` is `NULL` or absent from
#'   `dfDomain`. Reads the category from the input column when it is present.
#' @param strPrefix `character` Prefix for the generated `parameter_id`, kept
#'   distinct per transformation so `range_normalized` and `ratio_missing`
#'   never collide on the same lab test.
#'
#' @return `list` with elements `data`, `parameters` and `untransformed`,
#'   ready to be passed to [Combine_CTAS_Input()].
#'
#' @examples
#' Input_Numeric(data.frame(
#'   studyid = "A",
#'   subject_id = c("S1", "S1"),
#'   parameter_id = c("SYSBP", "SYSBP"),
#'   parameter_name = c("Systolic Blood Pressure", "Systolic Blood Pressure"),
#'   parameter_category_1 = "Vital Signs",
#'   visit = c("WEEK 2", "WEEK 4"),
#'   visitnum = c(3, 4),
#'   value = c(120, 124)
#' ))
#'
#' @export
Input_Numeric <- function(dfDomain,
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
                          strPrefix = "NUM") {
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
      parameter_name = paste0(.data$parameter_category_1, ": ", .data$TestName),
      parameter_category_1 = .data$parameter_category_1,
      parameter_category_2 = .data$parameter_id,
      parameter_category_3 = "numeric"
    ) |>
    as.data.frame()

  # `untransformed` is deliberately empty for the plain-numeric input:
  # `result == original_value` here, so recording the pair would double the
  # payload without adding information.
  list(
    data = BuildCTASData(dfWork),
    parameters = dfParameters,
    untransformed = EmptyCTASUntransformed()
  )
}
