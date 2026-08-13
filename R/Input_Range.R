#' Map a numeric findings domain with reference ranges to CTAS input
#'
#' Like [Input_Numeric()], but normalises each value by its own reference range
#' via [Prepare_Normalize()], so that tests measured on different scales become
#' directly comparable. Intended for LB, but applies to any domain carrying
#' low/high bounds.
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
#'   USUBJID = c("S1", "S1"),
#'   LBTESTCD = c("ALT", "ALT"),
#'   LBTEST = c("Alanine Aminotransferase", "Alanine Aminotransferase"),
#'   VISIT = c("WEEK 2", "WEEK 4"),
#'   VISITNUM = c(3, 4),
#'   LBSTRESN = c(20, 30),
#'   LBSTNRLO = c(10, 10),
#'   LBSTNRHI = c(40, 40)
#' ))
#'
#' @export
Input_Range <- function(dfDomain,
                        strSubjectCol = "USUBJID",
                        strTestCDCol = "LBTESTCD",
                        strTestCol = "LBTEST",
                        strValueCol = "LBSTRESN",
                        strLowCol = "LBSTNRLO",
                        strHighCol = "LBSTNRHI",
                        strVisitCol = "VISIT",
                        strVisitNumCol = "VISITNUM",
                        strVisitPattern = NULL,
                        strExcludePattern = "unsch",
                        strCategory = "Labs",
                        strPrefix = "LB_NORM") {
  AssertColumns(dfDomain, c(strLowCol, strHighCol), "dfDomain")

  dfBase <- StandardizeDomain(
    dfDomain,
    strSubjectCol = strSubjectCol,
    strTestCDCol = strTestCDCol,
    strTestCol = strTestCol,
    strValueCol = strValueCol,
    strVisitCol = strVisitCol,
    strVisitNumCol = strVisitNumCol,
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

  dfParameters <- dfWork |>
    dplyr::distinct(.data$parameter_id, .data$TestCD, .data$TestName) |>
    dplyr::transmute(
      parameter_id = .data$parameter_id,
      parameter_name = paste0(.env$strCategory, " (norm): ", .data$TestName),
      parameter_category_1 = .env$strCategory,
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
