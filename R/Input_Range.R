#' Map a numeric findings frame with reference ranges to CTAS input
#'
#' Like [Input_Numeric()], but normalises each value by its own reference range
#' via [Prepare_Normalize()], so that tests measured on different scales become
#' directly comparable. Intended for lab-shaped data, but applies to any
#' standardised frame carrying `low`/`high` bounds.
#'
#' Rows with an invalid range (missing bound or non-positive width) yield `NA`
#' and are dropped, since CTAS cannot use them.
#'
#' @inheritParams Input_Numeric
#' @param strLowCol `character` Lower reference-bound column.
#' @param strHighCol `character` Upper reference-bound column.
#'
#' @return `list` with elements `data`, `parameters` and `untransformed`.
#'
#' @examples
#' Input_Range(data.frame(
#'   studyid = "A",
#'   subject_id = c("S1", "S1"),
#'   parameter_id = c("ALT", "ALT"),
#'   parameter_name = c("Alanine Aminotransferase", "Alanine Aminotransferase"),
#'   parameter_category_1 = "Labs",
#'   visit = c("WEEK 2", "WEEK 4"),
#'   visitnum = c(3, 4),
#'   value = c(20, 30),
#'   low = c(10, 10),
#'   high = c(40, 40)
#' ))
#'
#' @export
Input_Range <- function(dfDomain,
                        strSubjectCol = "subject_id",
                        strTestCDCol = "parameter_id",
                        strTestCol = "parameter_name",
                        strValueCol = "value",
                        strLowCol = "low",
                        strHighCol = "high",
                        strVisitCol = "visit",
                        strVisitNumCol = "visitnum",
                        strStudyCol = "studyid",
                        strCategoryCol = "parameter_category_1",
                        strVisitPattern = NULL,
                        strExcludePattern = NULL,
                        strCategory = NA_character_,
                        strPrefix = "RANGE") {
  AssertColumns(dfDomain, c(strLowCol, strHighCol), "dfDomain")

  dfBase <- StandardizeDomain(
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
  )

  dfBounds <- dfDomain |>
    FilterVisits(
      strVisitCol = strVisitCol,
      strVisitPattern = strVisitPattern,
      strExcludePattern = strExcludePattern
    )

  dfBase$Low <- as.numeric(dfBounds[[strLowCol]])
  dfBase$High <- as.numeric(dfBounds[[strHighCol]])

  dfWork <- dfBase |>
    dplyr::mutate(
      parameter_id = paste0(.env$strPrefix, "_", .data$TestCD),
      result = Prepare_Normalize(
        as.numeric(.data$Value), .data$Low, .data$High
      )
    ) |>
    dplyr::filter(!is.na(.data$result))

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
      parameter_name = paste0(.data$parameter_category_1, " (norm): ", .data$TestName),
      parameter_category_1 = .data$parameter_category_1,
      parameter_category_2 = .data$parameter_id,
      parameter_category_3 = "range_normalized"
    ) |>
    as.data.frame()

  dfUntransformed <- dfWork |>
    dplyr::transmute(
      subject_id = .data$subject_id,
      parameter_category_2 = .data$parameter_id,
      timepoint_1_name = .data$timepoint_1_name,
      original_value = as.numeric(.data$Value),
      lower = .data$Low,
      upper = .data$High,
      original_category = NA_character_
    ) |>
    as.data.frame()

  list(
    data = BuildCTASData(dfWork),
    parameters = dfParameters,
    untransformed = dfUntransformed
  )
}
