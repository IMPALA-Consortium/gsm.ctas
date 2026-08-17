#' Assemble the timeseries-level detail object for `ctasapp` drill-down
#'
#' [Summarize_CTAS()] collapses many timeseries into one row per group, which is
#' what the gsm report needs and exactly what a reviewer investigating a flag
#' does not: once a site is flagged, the next question is *which* measurement
#' caused it. That question is answered by the `ctasapp` dashboard, so this
#' function preserves the join keys the aggregation discards -
#' `timeseries_id`, `parameter_id` and `feature` - in the shape `ctasapp` reads.
#'
#' The division of labour is deliberate: the gsm report performs signal
#' detection, `ctasapp` performs signal investigation. This is a *parallel*
#' output of the same CTAS run, not a stage of the gsm pipeline - nothing
#' downstream consumes it, and `ctasapp` does not consume the gsm reporting
#' layer.
#'
#' Three frames are returned, matching the files `ctasapp` accepts:
#'
#' - `Results` - one row per timeseries x feature x group, carrying `site`,
#'   `timeseries_id`, `parameter_id`, `feature` and
#'   `fdr_corrected_pvalue_logp`. This is [Combine_CTAS_Scores()] output
#'   unchanged, since that already satisfies the contract.
#' - `Input` - the CTAS `data` frame joined to `subjects` and `parameters`, so
#'   the dashboard can plot the underlying series with site and parameter
#'   labels.
#' - `Untransformed` - the pre-transformation values recorded by the
#'   `Input_*()` functions, letting the dashboard show a lab result in its
#'   original units alongside the range-normalised value actually analysed.
#'   Empty when no mapped domain records them.
#'
#' `strStudyID` is optional and adds a `study` column to `Results` and `Input`;
#' `ctasapp` uses it to hold several studies in one upload.
#'
#' @param dfScores `data.frame` Result of [Combine_CTAS_Scores()].
#' @param lInput `list` Result of [Combine_CTAS_Input()], the input to the same
#'   CTAS run.
#' @param strStudyID `character` Optional study identifier.
#'
#' @return `list` with elements `Results`, `Input` and `Untransformed`.
#'
#' @seealso [Write_CTAS_Detail()], which writes these frames to disk in the
#'   layout `ctasapp` expects.
#'
#' @examples
#' lInput <- Combine_CTAS_Input(
#'   Input_Numeric(data.frame(
#'     USUBJID = "S1", VSTESTCD = "SYSBP", VSTEST = "Systolic Blood Pressure",
#'     VISIT = "WEEK 2", VISITNUM = 3, VSSTRESN = 120
#'   )),
#'   dfSubjects = Input_Subjects(data.frame(
#'     USUBJID = "S1", SITEID = "701", COUNTRY = "USA"
#'   ))
#' )
#' dfScores <- data.frame(
#'   timeseries_id = "ts1", site = "701", feature = "average",
#'   parameter_id = "VS_SYSBP", fdr_corrected_pvalue_logp = 1.2
#' )
#' Combine_CTAS_Detail(dfScores, lInput)
#'
#' @export
Combine_CTAS_Detail <- function(dfScores, lInput, strStudyID = NULL) {
  AssertColumns(
    dfScores,
    c(
      "site", "timeseries_id", "parameter_id", "feature",
      "fdr_corrected_pvalue_logp"
    ),
    "dfScores"
  )

  if (!is.list(lInput) || is.data.frame(lInput)) {
    cli::cli_abort(
      "{.arg lInput} must be a list, as returned by {.fn Combine_CTAS_Input}."
    )
  }

  vRequired <- c("data", "subjects", "parameters")
  vMissing <- setdiff(vRequired, names(lInput))
  if (length(vMissing) > 0) {
    cli::cli_abort(c(
      "{.arg lInput} is missing required element{?s}: {.val {vMissing}}.",
      "i" = "Build it with {.fn Combine_CTAS_Input}."
    ))
  }

  if (!is.null(strStudyID) &&
    (!rlang::is_character(strStudyID) || length(strStudyID) != 1)) {
    cli::cli_abort("{.arg strStudyID} must be a single string or {.code NULL}.")
  }

  vCategories <- c(
    "parameter_category_1", "parameter_category_2", "parameter_category_3"
  )
  AssertColumns(
    lInput$parameters, c("parameter_id", "parameter_name", vCategories),
    "lInput$parameters"
  )
  AssertColumns(lInput$subjects, c("subject_id", "site"), "lInput$subjects")
  AssertColumns(lInput$data, c("subject_id", "parameter_id"), "lInput$data")

  dfInput <- lInput$data |>
    dplyr::left_join(lInput$subjects, by = "subject_id") |>
    dplyr::left_join(
      dplyr::select(
        lInput$parameters,
        "parameter_id", "parameter_name", dplyr::all_of(vCategories)
      ),
      by = "parameter_id"
    )

  # A measurement whose subject is absent from `subjects` would render in the
  # dashboard with no site, i.e. as a point that cannot be attributed to
  # anyone. Fail here instead.
  if (any(is.na(dfInput$site))) {
    cli::cli_abort(
      "{.field subject_id} in {.arg lInput$data} has no match in {.arg lInput$subjects}."
    )
  }

  dfUntransformed <- lInput$untransformed
  if (is.null(dfUntransformed)) {
    dfUntransformed <- EmptyCTASUntransformed()
  }

  list(
    Results = AddStudyID(as.data.frame(dfScores), strStudyID),
    Input = AddStudyID(as.data.frame(dfInput), strStudyID),
    Untransformed = as.data.frame(dfUntransformed)
  )
}

#' Add an optional study identifier column
#'
#' @param dfInput `data.frame` Frame to label.
#' @param strStudyID `character` Study identifier, or `NULL` to do nothing.
#'
#' @return `data.frame`, with a `study` column when `strStudyID` is given.
#'
#' @keywords internal
AddStudyID <- function(dfInput, strStudyID = NULL) {
  if (is.null(strStudyID)) {
    return(dfInput)
  }

  dfInput$study <- strStudyID
  dfInput
}
