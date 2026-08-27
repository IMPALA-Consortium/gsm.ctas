#' Run the CTAS engine over a combined study input
#'
#' A gsm-friendly wrapper around [ctas::process_a_study()]. It validates the
#' input list produced by [Combine_CTAS_Input()], applies reproducible seeding,
#' and converts the degenerate cases CTAS signals by returning `NULL` elements
#' into an informative error.
#'
#' `process_a_study()` is single-study by construction. When `lInput$subjects`
#' contains more than one value in `strStudyCol`, the input is split by study,
#' scored per study, and the four result frames are stacked with `studyid`
#' tagged onto every row so the downstream contract is study-aware without
#' calling code learning a second function.
#'
#' `process_a_study()` is an all-metrics-at-once engine: a single call scores
#' every (timeseries x feature x site) combination. It is therefore intended to
#' run once per study, with each metric workflow filtering the shared result to
#' one feature family.
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
#' @param strStudyCol `character` Column on `lInput$subjects` identifying the
#'   study. `NULL` disables the split and runs `process_a_study()` once on the
#'   whole input.
#' @param ... Further arguments passed to [ctas::process_a_study()].
#'
#' @return `list` with `timeseries`, `timeseries_features`, `PCA_coordinates`
#'   and `site_scores`. Each frame carries the `strStudyCol` column when the
#'   split was active.
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
                         strStudyCol = "studyid",
                         ...) {
  AssertCTASInput(lInput, strStudyCol = strStudyCol)

  strScoringMethod <- rlang::arg_match(
    strScoringMethod, c("ks", "mixedeffects", "avg_feat_value")
  )

  fnRunOne <- function(lSub) {
    ctas::process_a_study(
      subjects = lSub$subjects,
      parameters = lSub$parameters,
      data = lSub$data,
      custom_timeseries = lSub$custom_timeseries,
      custom_reference_groups = lSub$custom_reference_groups,
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

  vStudies <- if (!is.null(strStudyCol) && strStudyCol %in% names(lInput$subjects)) {
    sort(unique(as.character(lInput$subjects[[strStudyCol]])))
  } else {
    character(0)
  }

  fnAll <- function() {
    if (length(vStudies) <= 1) {
      lCTAS <- fnRunOne(lInput)
      AssertCTASResult(lCTAS)
      if (length(vStudies) == 1) {
        lCTAS <- TagStudyID(lCTAS, vStudies, strStudyCol)
      }
      return(lCTAS)
    }

    lPerStudy <- lapply(vStudies, function(strStudy) {
      lSub <- SubsetCTASInput(lInput, strStudy, strStudyCol)
      lRes <- fnRunOne(lSub)
      AssertCTASResult(lRes)
      TagStudyID(lRes, strStudy, strStudyCol)
    })

    list(
      site_scores = dplyr::bind_rows(lapply(lPerStudy, `[[`, "site_scores")),
      timeseries = dplyr::bind_rows(lapply(lPerStudy, `[[`, "timeseries")),
      timeseries_features = dplyr::bind_rows(lapply(lPerStudy, `[[`, "timeseries_features")),
      PCA_coordinates = dplyr::bind_rows(lapply(lPerStudy, `[[`, "PCA_coordinates"))
    )
  }

  if (is.null(nSeed)) {
    fnAll()
  } else {
    rlang::check_installed("withr", "to seed `Analyze_CTAS()`.")
    withr::with_seed(nSeed, fnAll())
  }
}

#' Subset a CTAS input list to a single study
#'
#' @param lInput `list` Result of [Combine_CTAS_Input()].
#' @param strStudy `character` One study id.
#' @param strStudyCol `character` Column on `lInput$subjects`.
#'
#' @return `list` A single-study copy of `lInput`.
#'
#' @keywords internal
SubsetCTASInput <- function(lInput, strStudy, strStudyCol) {
  vKeep <- lInput$subjects[[strStudyCol]] == strStudy
  dfSubjectsSub <- lInput$subjects[vKeep, , drop = FALSE]
  vSubjects <- dfSubjectsSub$subject_id

  dfDataSub <- lInput$data[lInput$data$subject_id %in% vSubjects, , drop = FALSE]

  # Trim `parameters` to what has data in this study so `process_a_study()`
  # cannot try to score a parameter with no rows.
  dfParametersSub <- lInput$parameters[
    lInput$parameters$parameter_id %in% unique(dfDataSub$parameter_id), ,
    drop = FALSE
  ]

  list(
    data = dfDataSub,
    subjects = dfSubjectsSub,
    parameters = dfParametersSub,
    custom_timeseries = lInput$custom_timeseries,
    custom_reference_groups = lInput$custom_reference_groups,
    untransformed = lInput$untransformed
  )
}

#' Tag every result frame with a studyid column
#'
#' @param lCTAS `list` Result of [ctas::process_a_study()].
#' @param strStudy `character` Study id to write.
#' @param strStudyCol `character` Column name to use.
#'
#' @return `list` `lCTAS` with `strStudyCol` present on every non-null frame.
#'
#' @keywords internal
TagStudyID <- function(lCTAS, strStudy, strStudyCol) {
  vFrames <- c("site_scores", "timeseries", "timeseries_features", "PCA_coordinates")
  for (strFrame in vFrames) {
    if (!is.null(lCTAS[[strFrame]]) && nrow(lCTAS[[strFrame]]) > 0) {
      lCTAS[[strFrame]][[strStudyCol]] <- strStudy
    }
  }
  lCTAS
}

#' Validate a combined CTAS input list
#'
#' @param lInput `list` Result of [Combine_CTAS_Input()].
#' @param strStudyCol `character` Optional study column expected on
#'   `lInput$subjects`.
#'
#' @return `NULL`, invisibly. Aborts when the input is unusable.
#'
#' @keywords internal
AssertCTASInput <- function(lInput, strStudyCol = "studyid") {
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

  if (!is.null(strStudyCol) && !strStudyCol %in% names(lInput$subjects)) {
    cli::cli_abort(c(
      "{.arg lInput$subjects} is missing study column {.val {strStudyCol}}.",
      "i" = "Rebuild {.arg lInput} with {.fn Combine_CTAS_Input} or set {.arg strStudyCol} to {.code NULL}."
    ))
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
