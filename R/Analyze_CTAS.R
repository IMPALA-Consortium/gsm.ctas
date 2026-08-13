#' Run the CTAS engine over a combined study input
#'
#' A gsm-friendly wrapper around [ctas::process_a_study()]. It validates the
#' input list produced by [Combine_CTAS_Input()], applies reproducible seeding,
#' and converts the degenerate cases CTAS signals by returning `NULL` elements
#' into an informative error.
#'
#' `process_a_study()` is an all-metrics-at-once engine: a single call scores
#' every (timeseries x feature x site) combination. It is therefore intended to
#' run once per study, in a high-`Priority` mapping workflow, with each metric
#' workflow filtering the shared result to one feature.
#'
#' @param lInput `list` Result of [Combine_CTAS_Input()].
#' @param strFeatures `character` Semicolon-delimited CTAS features.
#' @param nMinTimepoints `numeric` Minimum timepoints per timeseries.
#' @param nMinSubjects `numeric` Minimum subjects per timeseries.
#' @param dMaxShareMissing `numeric` Maximum share of missing timepoints.
#' @param bChangeFromBaseline `logical` Derive change-from-baseline timeseries.
#' @param bAutogenerate `logical` Autogenerate timeseries.
#' @param strScoringMethod `character` One of "ks", "mixedeffects",
#'   "avg_feat_value".
#' @param strPadjustMethod `character` Passed to [stats::p.adjust()].
#' @param nSeed `numeric` Optional seed for reproducibility.
#' @param ... Further arguments passed to [ctas::process_a_study()].
#'
#' @return `list` with `timeseries`, `timeseries_features`, `PCA_coordinates`
#'   and `site_scores`.
#'
#' @examples
#' \donttest{
#' lInput <- Combine_CTAS_Input(
#'   Input_Numeric(pharmaversesdtm::vs),
#'   dfSubjects = Input_Subjects(pharmaversesdtm::dm)
#' )
#' lCTAS <- Analyze_CTAS(lInput)
#' }
#'
#' @export
Analyze_CTAS <- function(lInput,
                         strFeatures = "autocorr;average;sd;unique_value_count_relative",
                         nMinTimepoints = 3,
                         nMinSubjects = 3,
                         dMaxShareMissing = 0.5,
                         bChangeFromBaseline = FALSE,
                         bAutogenerate = TRUE,
                         strScoringMethod = "ks",
                         strPadjustMethod = "fdr",
                         nSeed = NULL,
                         ...) {
  AssertCTASInput(lInput)

  strScoringMethod <- rlang::arg_match(
    strScoringMethod, c("ks", "mixedeffects", "avg_feat_value")
  )

  fnRun <- function() {
    ctas::process_a_study(
      subjects = lInput$subjects,
      parameters = lInput$parameters,
      data = lInput$data,
      custom_timeseries = lInput$custom_timeseries,
      custom_reference_groups = lInput$custom_reference_groups,
      default_timeseries_features_to_calculate = strFeatures,
      default_minimum_timepoints_per_series = nMinTimepoints,
      default_minimum_subjects_per_series = nMinSubjects,
      default_max_share_missing_timepoints_per_series = dMaxShareMissing,
      default_generate_change_from_baseline = bChangeFromBaseline,
      autogenerate_timeseries = bAutogenerate,
      site_scoring_method = strScoringMethod,
      padjust_method = strPadjustMethod,
      ...
    )
  }

  lCTAS <- if (is.null(nSeed)) {
    fnRun()
  } else {
    rlang::check_installed("withr", "to seed `Analyze_CTAS()`.")
    withr::with_seed(nSeed, fnRun())
  }

  AssertCTASResult(lCTAS)

  lCTAS
}

#' Validate a combined CTAS input list
#'
#' @param lInput `list` Result of [Combine_CTAS_Input()].
#'
#' @return `NULL`, invisibly. Aborts when the input is unusable.
#'
#' @keywords internal
AssertCTASInput <- function(lInput) {
  vRequired <- c(
    "data", "subjects", "parameters", "custom_timeseries",
    "custom_reference_groups"
  )

  if (!is.list(lInput) || is.data.frame(lInput)) {
    cli::cli_abort("{.arg lInput} must be a list, as returned by {.fn Combine_CTAS_Input}.")
  }

  vMissing <- setdiff(vRequired, names(lInput))
  if (length(vMissing) > 0) {
    cli::cli_abort(c(
      "{.arg lInput} is missing required element{?s}: {.val {vMissing}}.",
      "i" = "Build it with {.fn Combine_CTAS_Input}."
    ))
  }

  bFrames <- vapply(lInput[vRequired], is.data.frame, logical(1))
  if (!all(bFrames)) {
    cli::cli_abort(
      "Element{?s} {.val {vRequired[!bFrames]}} of {.arg lInput} must be {.cls data.frame}."
    )
  }

  if (nrow(lInput$data) == 0) {
    cli::cli_abort("{.arg lInput$data} has no rows; there is nothing for CTAS to analyse.")
  }

  if (nrow(lInput$parameters) == 0) {
    cli::cli_abort("{.arg lInput$parameters} has no rows; no parameter can be scored.")
  }

  nSites <- dplyr::n_distinct(lInput$subjects$site)
  if (nSites < 2) {
    cli::cli_abort(c(
      "CTAS compares sites against each other, so at least 2 sites are required.",
      "x" = "{.arg lInput$subjects} contains {nSites} site{?s}."
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
