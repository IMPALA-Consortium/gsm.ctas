#' Compose the CTAS feature string from boolean flags
#'
#' Aborts when every flag is `FALSE`, since `process_a_study()` fed an empty
#' feature string would fail with an opaque error deep inside the engine.
#'
#' @keywords internal
AssembleFeatures <- function(bAutocorr, bAverage, bSD, bRange,
                             bUniqueValueCountRelative,
                             bOwnSiteSimilScore, bLOF) {
  vFlags <- c(
    autocorr = isTRUE(bAutocorr),
    average = isTRUE(bAverage),
    sd = isTRUE(bSD),
    range = isTRUE(bRange),
    unique_value_count_relative = isTRUE(bUniqueValueCountRelative),
    own_site_simil_score = isTRUE(bOwnSiteSimilScore),
    lof = isTRUE(bLOF)
  )

  if (!any(vFlags)) {
    cli::cli_abort(
      "At least one {.arg b*} feature flag must be {.code TRUE}."
    )
  }

  paste(names(vFlags)[vFlags], collapse = ";")
}

#' Derive the CTAS-shaped `subjects`, `parameters` and `data` from a long frame
#'
#' Re-splits the single long frame consumed by [Analyze_CTAS()] into the three
#' data frames [ctas::process_a_study()] requires. `country` and `region` are
#' populated with `"no"` when absent, matching the ctas defaults used in
#' [ctas::ctas_data].
#'
#' @keywords internal
BuildCTASInput <- function(dfInput, strStudyCol, dfCustomTimeseries,
                           dfCustomReferenceGroups) {
  vSubjectCols <- intersect(
    c("subject_id", "site", "country", "region", strStudyCol),
    names(dfInput)
  )
  dfSubjects <- dplyr::distinct(dplyr::select(dfInput, dplyr::all_of(vSubjectCols)))
  if (!"country" %in% names(dfSubjects)) dfSubjects$country <- "no"
  if (!"region" %in% names(dfSubjects)) dfSubjects$region <- "no"

  vParamCols <- c(
    "parameter_id", "parameter_name",
    "parameter_category_1", "parameter_category_2",
    "parameter_category_3"
  )
  dfParameters <- dfInput |>
    dplyr::distinct(dplyr::across(dplyr::all_of(vParamCols))) |>
    dplyr::mutate(
      time_point_count_min = NA_real_,
      subject_count_min = NA_real_,
      max_share_missing = NA_real_,
      generate_change_from_baseline = NA,
      timeseries_features_to_calculate = NA_character_,
      use_only_custom_timeseries = FALSE
    )

  dfData <- dfInput |>
    dplyr::select(dplyr::all_of(c(
      "subject_id", "parameter_id",
      "timepoint_1_name", "timepoint_2_name", "timepoint_rank",
      "result", "baseline"
    ))) |>
    Prepare_TimepointRank() |>
    dplyr::mutate(timepoint_rank = as.numeric(.data$timepoint_rank))

  list(
    subjects = dfSubjects,
    parameters = dfParameters,
    data = dfData,
    custom_timeseries = dfCustomTimeseries,
    custom_reference_groups = dfCustomReferenceGroups
  )
}

#' Enrich `site_scores` with parameter metadata and rename `studyid` to `study`
#'
#' Joins CTAS `site_scores` to `timeseries` on `timeseries_id` to recover
#' `parameter_id`, and to the parameter metadata derived from `dfInput` to
#' recover the category columns CTAS discards. Renames `studyid` to `study`
#' (ctasapp vocabulary) when the multi-study contract is active.
#'
#' @keywords internal
BuildResults <- function(lCTAS, dfInput, strStudyCol) {
  vCategories <- c(
    "parameter_category_1", "parameter_category_2", "parameter_category_3"
  )

  dfTimeseries <- dplyr::distinct(
    dplyr::select(lCTAS$timeseries, "timeseries_id", "parameter_id")
  )

  dfParameters <- dplyr::distinct(
    dplyr::select(dfInput, "parameter_id", dplyr::all_of(vCategories))
  )
  if (anyDuplicated(dfParameters$parameter_id) > 0) {
    cli::cli_abort(
      "{.field parameter_id} is not unique in {.arg dfInput}; parameter metadata is inconsistent."
    )
  }

  dfResults <- lCTAS$site_scores |>
    dplyr::left_join(dfTimeseries, by = "timeseries_id") |>
    dplyr::left_join(dfParameters, by = "parameter_id")

  if (any(is.na(dfResults$parameter_id))) {
    cli::cli_abort(
      "{.field timeseries_id} in {.field site_scores} has no match in {.field timeseries}."
    )
  }

  if (!is.null(strStudyCol) && strStudyCol %in% names(dfResults)) {
    dfResults <- dplyr::rename(dfResults, study = dplyr::all_of(strStudyCol))
  }

  dfResults
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
