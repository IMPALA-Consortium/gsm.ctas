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
#' @param strPrefix `character` Optional prefix applied to `parameter_id`
#'   (e.g. `"NUM"` -> `"NUM_SYSBP"`). Empty by default; `parameter_category_2`
#'   always keeps the raw test code so ctasapp can stitch sibling metrics.
#'
#' @return `data.frame` in the CTAS long-format vocabulary. Includes the raw
#'   SDTM-derived columns (`visit`, `visitnum`, `value`, and `low`/`high` when
#'   supplied) alongside the CTAS-ready columns (`parameter_category_2`,
#'   `parameter_category_3 = "numeric"`, `timepoint_1_name`, `timepoint_rank`,
#'   `result`, `baseline`). `visitnum` and `timepoint_rank` are recalculated
#'   as a contiguous `1..N` `row_number()` within each `(subject_id,
#'   parameter_id)` group, ordered by the source `VISITNUM` with `VISIT` as
#'   a tiebreaker -- matching ctasapp's `recalculate_timepoint_rank()`.
#'   The default output is ready to feed straight into
#'   [Analyze_CTAS()]; use [Transform_Range()] or [Transform_Missing()] to overwrite
#'   `result`/`parameter_category_3`/`parameter_id` for those transforms.
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
                               strPrefix = "") {
  AssertColumns(
    dfDomain,
    c(
      strSubjectCol, strTestCDCol, strTestCol, strValueCol,
      strVisitCol, strVisitNumCol, strLowCol, strHighCol
    ),
    "dfDomain"
  )
  AssertColumns(dfSubjects, c("subject_id", "site"), "dfSubjects")

  vValue <- dfDomain[[strValueCol]]
  # Character sources (e.g. RSSTRESC) leave `result` for Transform_OneHot to fill.
  vResult <- if (is.numeric(vValue)) as.numeric(vValue) else rep(NA_real_, length(vValue))

  dfLong <- dplyr::tibble(
    subject_id = as.character(dfDomain[[strSubjectCol]]),
    parameter_id = as.character(dfDomain[[strTestCDCol]]),
    parameter_name = as.character(dfDomain[[strTestCol]]),
    parameter_category_1 = strCategory,
    parameter_category_2 = as.character(dfDomain[[strTestCDCol]]),
    parameter_category_3 = "numeric",
    visit = as.character(dfDomain[[strVisitCol]]),
    visitnum = as.numeric(dfDomain[[strVisitNumCol]]),
    timepoint_1_name = as.character(dfDomain[[strVisitCol]]),
    timepoint_2_name = NA_character_,
    timepoint_rank = as.numeric(dfDomain[[strVisitNumCol]]),
    value = vValue,
    result = vResult,
    baseline = NA_real_
  )

  if (!is.null(strLowCol)) {
    dfLong$low <- as.numeric(dfDomain[[strLowCol]])
  }
  if (!is.null(strHighCol)) {
    dfLong$high <- as.numeric(dfDomain[[strHighCol]])
  }

  # Normalize visit rank to a contiguous 1..N per (subject_id, parameter_id),
  # mirroring ctasapp's recalculate_timepoint_rank().
  dfLong <- Prepare_TimepointRank(dfLong)
  dfLong$visitnum <- dfLong$timepoint_rank

  if (nzchar(strPrefix)) {
    dfLong$parameter_id <- paste0(strPrefix, "_", dfLong$parameter_id)
  }

  vSubjectCols <- intersect(
    c("studyid", "site", "country", "region"),
    names(dfSubjects)
  )
  dfSlim <- dplyr::distinct(dplyr::select(
    dfSubjects, dplyr::all_of(c("subject_id", vSubjectCols))
  ))

  dplyr::inner_join(dfLong, dfSlim, by = "subject_id")
}
