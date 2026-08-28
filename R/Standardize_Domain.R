#' Rename an SDTM findings domain into the CTAS long-format vocabulary
#'
#' The single step that translates SDTM column names into the CTAS +
#' [ctasapp](https://github.com/IMPALA-Consortium/ctasapp) vocabulary and joins
#' the standardised subject metadata (`studyid`, `site`, `country`) onto every
#' row. Downstream `Input_*()` functions consume the resulting long frame and
#' transform values without needing to know which SDTM domain fed them.
#'
#' Reference-bound columns (`strLowCol`/`strHighCol`) are optional and only
#' meaningful for range-carrying sources such as LB.
#'
#' @param dfDomain `data.frame` Raw SDTM findings.
#' @param dfSubjects `data.frame` Standardised subject table with `subject_id`,
#'   `site`, and optionally `studyid`, `country`, `region`.
#' @param strSubjectCol,strTestCDCol,strTestCol,strValueCol,strVisitCol,strVisitNumCol
#'   `character` SDTM column names to translate.
#' @param strLowCol,strHighCol `character` Reference-bound columns. `NULL`
#'   when the source has no ranges.
#' @param strCategory `character` Constant stamped onto `parameter_category_1`.
#' @param strVisitPattern,strExcludePattern `character` Passed to
#'   [FilterVisits()].
#'
#' @return `data.frame` in the CTAS long-format vocabulary. Columns:
#'   `studyid` (when present on `dfSubjects`), `subject_id`, `site`, `country`,
#'   `region`, `parameter_id`, `parameter_name`, `parameter_category_1`,
#'   `visit`, `visitnum`, `value`, and `low`/`high` when the range columns
#'   were supplied.
#'
#' @examples
#' Standardize_Domain(
#'   dfDomain = data.frame(
#'     USUBJID = "S1", VSTESTCD = "SYSBP", VSTEST = "Systolic Blood Pressure",
#'     VSSTRESN = 120, VISIT = "WEEK 2", VISITNUM = 3
#'   ),
#'   dfSubjects = data.frame(
#'     studyid = "A", subject_id = "S1", site = "701", country = "USA"
#'   ),
#'   strTestCDCol = "VSTESTCD", strTestCol = "VSTEST", strValueCol = "VSSTRESN",
#'   strCategory = "Vital Signs"
#' )
#'
#' @export
Standardize_Domain <- function(dfDomain,
                               dfSubjects,
                               strSubjectCol = "USUBJID",
                               strTestCDCol,
                               strTestCol,
                               strValueCol,
                               strVisitCol = "VISIT",
                               strVisitNumCol = "VISITNUM",
                               strLowCol = NULL,
                               strHighCol = NULL,
                               strCategory,
                               strVisitPattern = NULL,
                               strExcludePattern = "unsch") {
  AssertColumns(
    dfDomain,
    c(strSubjectCol, strTestCDCol, strTestCol, strValueCol,
      strVisitCol, strVisitNumCol, strLowCol, strHighCol),
    "dfDomain"
  )
  AssertColumns(dfSubjects, c("subject_id", "site"), "dfSubjects")

  dfFiltered <- FilterVisits(
    dfDomain,
    strVisitCol = strVisitCol,
    strVisitPattern = strVisitPattern,
    strExcludePattern = strExcludePattern
  )

  dfLong <- dplyr::tibble(
    subject_id = as.character(dfFiltered[[strSubjectCol]]),
    parameter_id = as.character(dfFiltered[[strTestCDCol]]),
    parameter_name = as.character(dfFiltered[[strTestCol]]),
    parameter_category_1 = strCategory,
    visit = as.character(dfFiltered[[strVisitCol]]),
    visitnum = as.numeric(dfFiltered[[strVisitNumCol]]),
    value = dfFiltered[[strValueCol]]
  )

  if (!is.null(strLowCol)) {
    dfLong$low <- as.numeric(dfFiltered[[strLowCol]])
  }
  if (!is.null(strHighCol)) {
    dfLong$high <- as.numeric(dfFiltered[[strHighCol]])
  }

  vSubjectCols <- intersect(
    c("studyid", "site", "country", "region"),
    names(dfSubjects)
  )
  dfSlim <- dplyr::distinct(dplyr::select(
    dfSubjects, dplyr::all_of(c("subject_id", vSubjectCols))
  ))

  dfOut <- dplyr::inner_join(dfLong, dfSlim, by = "subject_id")
  as.data.frame(dfOut)
}
