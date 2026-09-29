#' Check that required columns are present
#'
#' @param dfInput `data.frame` Data frame to check.
#' @param vColumns `character` Required column names.
#' @param strLabel `character` Name used in the error message.
#'
#' @return `NULL`, invisibly. Aborts if columns are missing.
#'
#' @keywords internal
AssertColumns <- function(dfInput, vColumns, strLabel = "dfInput") {
  vColumns <- vColumns[!is.na(vColumns)]
  vMissing <- setdiff(vColumns, names(dfInput))

  if (length(vMissing) > 0) {
    cli::cli_abort(
      "{.arg {strLabel}} is missing required column{?s}: {.val {vMissing}}."
    )
  }

  invisible(NULL)
}

#' Validate a CTAS long-format input frame
#'
#' @param dfInput `data.frame` Long-format CTAS input.
#' @param strStudyCol `character` Optional study column expected on `dfInput`.
#'
#' @return `NULL`, invisibly. Aborts when the input is unusable.
#'
#' @keywords internal
AssertCTASInput <- function(dfInput, strStudyCol = "studyid") {
  if (!is.data.frame(dfInput)) {
    cli::cli_abort("{.arg dfInput} must be a {.cls data.frame}.")
  }

  vRequired <- c(
    "subject_id", "site",
    "parameter_id", "parameter_name",
    "parameter_category_1", "parameter_category_2", "parameter_category_3",
    "timepoint_1_name", "timepoint_2_name", "timepoint_rank",
    "result", "baseline"
  )

  vMissing <- setdiff(vRequired, names(dfInput))
  if (length(vMissing) > 0) {
    cli::cli_abort(c(
      "{.arg dfInput} is missing required column{?s}: {.val {vMissing}}.",
      "i" = "Build {.arg dfInput} with {.fn Standardize_Domain} and an {.fn Input_*} function."
    ))
  }

  if (nrow(dfInput) == 0) {
    cli::cli_abort("{.arg dfInput} has no rows; there is nothing for CTAS to analyse.")
  }

  if (!is.null(strStudyCol) && !strStudyCol %in% names(dfInput)) {
    cli::cli_abort(c(
      "{.arg dfInput} is missing study column {.val {strStudyCol}}.",
      "i" = "Set {.arg strStudyCol} to {.code NULL} to opt out of the multi-study contract."
    ))
  }

  nSites <- dplyr::n_distinct(dfInput$site)
  if (nSites < 2) {
    cli::cli_abort(c(
      "CTAS compares sites against each other, so at least 2 sites are required.",
      "x" = "{.arg dfInput} contains {nSites} site{?s}."
    ))
  }

  invisible(NULL)
}

#' Validate the CTAS result
#'
#' `process_a_study()` returns a list of `NULL`s when no timeseries could be
#' constructed. Turn that into an actionable message rather than letting it
#' surface as a downstream subsetting failure.
#'
#' @param lCTAS `list` Result of [ctas::process_a_study()].
#'
#' @return `NULL`, invisibly. Aborts when the result is degenerate.
#'
#' @keywords internal
AssertCTASResult <- function(lCTAS) {
  if (is.null(lCTAS$timeseries_features) || nrow(lCTAS$timeseries_features) == 0) {
    cli::cli_abort(c(
      "CTAS produced no timeseries features.",
      "i" = "Relax {.arg nMinTimepoints}, {.arg nMinSubjects} or {.arg dMaxShareMissing}."
    ))
  }

  if (is.null(lCTAS$site_scores) || nrow(lCTAS$site_scores) == 0) {
    cli::cli_abort(c(
      "CTAS produced no site scores.",
      "i" = "Too few sites or subjects contribute complete timeseries."
    ))
  }

  invisible(NULL)
}
