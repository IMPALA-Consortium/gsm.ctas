#' Score sites with CTAS
#'
#' A gsm-friendly wrapper around [ctas::process_a_study()]. It takes a single
#' long data frame in the CTAS + [ctasapp](https://github.com/IMPALA-Consortium/ctasapp)
#' vocabulary (typically the output of an `Input_*()` function), splits by
#' study when the multi-study contract is active, runs `process_a_study()`
#' per study, and returns the flat `results` frame ctasapp displays.
#'
#' Only `results` is returned; the `input` and `untransformed` shards ctasapp
#' also consumes are pure projections of the input `df`, so the metric YAML
#' assembles the ctasapp payload in a separate `base::list` step (see
#' `inst/workflow/2_metrics/*.yaml`).
#'
#' The single-df pattern follows
#' [ctasval](https://github.com/IMPALA-Consortium/ctasval): `subjects` and
#' `parameters` are re-derived from `df` via `distinct()` inside the function
#' so callers only have to keep one frame consistent.
#'
#' Feature selection is a boolean-per-feature contract instead of the
#' semicolon-delimited string CTAS accepts, so metric YAMLs can toggle
#' features individually from `meta:`.
#'
#' @param df `data.frame` Long-format CTAS input with at minimum `subject_id`,
#'   `site`, `parameter_id`, `parameter_name`, `parameter_category_1/2/3`,
#'   `timepoint_1_name`, `timepoint_2_name`, `timepoint_rank`, `result`,
#'   `baseline`. Additional CTAS subject columns (`country`, `region`) are
#'   carried through when present.
#' @param bAutocorr `logical` Score the `autocorr` feature.
#' @param bAverage `logical` Score the `average` feature.
#' @param bSD `logical` Score the `sd` feature.
#' @param bRange `logical` Score the `range` feature.
#' @param bUniqueValueCountRelative `logical` Score the
#'   `unique_value_count_relative` feature.
#' @param bOwnSiteSimilScore `logical` Score the `own_site_simil_score`
#'   feature.
#' @param bLOF `logical` Score the `lof` feature.
#' @param nMinTimepoints `numeric` Minimum timepoints per timeseries.
#' @param nMinSubjects `numeric` Minimum subjects per timeseries.
#' @param dMaxShareMissing `numeric` Maximum share of missing timepoints.
#' @param bChangeFromBaseline `logical` Derive change-from-baseline timeseries.
#' @param bAutogenerate `logical` Autogenerate timeseries.
#' @param strScoringMethod `character` One of `"ks"`, `"mixedeffects"`,
#'   `"avg_feat_value"`.
#' @param strPadjustMethod `character` Passed to [stats::p.adjust()].
#' @param dfCustomTimeseries `data.frame` Custom timeseries table forwarded
#'   to [ctas::process_a_study()]. Defaults to the shipped `ctas::ctas_data`.
#' @param dfCustomReferenceGroups `data.frame` Custom reference-group table
#'   forwarded to [ctas::process_a_study()]. Defaults to
#'   `ctas::ctas_data$custom_reference_groups`.
#' @param nSeed `numeric` Optional seed for reproducibility.
#' @param strStudyCol `character` Column on `df` identifying the study.
#'   `NULL` disables the split and drops the `study` output column.
#' @param ... Further arguments passed to [ctas::process_a_study()].
#'
#' @return `data.frame` One row per (site x timeseries x feature), carrying
#'   `parameter_id`, the category columns, and `study` (when the multi-study
#'   contract is active).
#'
#' @examples
#' \donttest{
#' dfSubjects <- data.frame(
#'   studyid = pharmaversesdtm::dm$STUDYID,
#'   subject_id = pharmaversesdtm::dm$USUBJID,
#'   site = pharmaversesdtm::dm$SITEID,
#'   country = pharmaversesdtm::dm$COUNTRY
#' )
#' dfValues <- Standardize_Domain(
#'   dfDomain = pharmaversesdtm::vs,
#'   dfSubjects = dfSubjects,
#'   strTestCDCol = "VSTESTCD", strTestCol = "VSTEST",
#'   strValueCol = "VSSTRESN",
#'   strCategory = "Vital Signs"
#' )
#' dfResults <- Analyze_CTAS(dfValues, nSeed = 1)
#' lAnalysis <- list(ID = "numeric", results = dfResults,
#'                   input = dfValues, untransformed = dfValues)
#' }
#' lAnalysis <- list(ID = "numeric", results = dfResults,
#'                   input = dfValues, untransformed = dfValues)
#' }
#'
#' @export
Analyze_CTAS <- function(df,
                         bAutocorr = TRUE,
                         bAverage = TRUE,
                         bSD = TRUE,
                         bRange = FALSE,
                         bUniqueValueCountRelative = TRUE,
                         bOwnSiteSimilScore = FALSE,
                         bLOF = FALSE,
                         nMinTimepoints = 3,
                         nMinSubjects = 3,
                         dMaxShareMissing = 0.5,
                         bChangeFromBaseline = FALSE,
                         bAutogenerate = TRUE,
                         strScoringMethod = "ks",
                         strPadjustMethod = "fdr",
                         dfCustomTimeseries = ctas::ctas_data$custom_timeseries,
                         dfCustomReferenceGroups = ctas::ctas_data$custom_reference_groups,
                         nSeed = NULL,
                         strStudyCol = "studyid",
                         ...) {
  AssertCTASInput(df, strStudyCol = strStudyCol)

  strScoringMethod <- rlang::arg_match(
    strScoringMethod, c("ks", "mixedeffects", "avg_feat_value")
  )

  strFeatures <- AssembleFeatures(
    bAutocorr = bAutocorr, bAverage = bAverage, bSD = bSD, bRange = bRange,
    bUniqueValueCountRelative = bUniqueValueCountRelative,
    bOwnSiteSimilScore = bOwnSiteSimilScore, bLOF = bLOF
  )

  fnRunOne <- function(dfSub) {
    lIn <- BuildCTASInput(dfSub, strStudyCol,
                          dfCustomTimeseries, dfCustomReferenceGroups)
    ctas::process_a_study(
      subjects = lIn$subjects,
      parameters = lIn$parameters,
      data = lIn$data,
      custom_timeseries = lIn$custom_timeseries,
      custom_reference_groups = lIn$custom_reference_groups,
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

  vStudies <- if (!is.null(strStudyCol) && strStudyCol %in% names(df)) {
    sort(unique(as.character(df[[strStudyCol]])))
  } else {
    character(0)
  }

  fnAll <- function() {
    if (length(vStudies) <= 1) {
      lCTAS <- fnRunOne(df)
      AssertCTASResult(lCTAS)
      if (length(vStudies) == 1) {
        lCTAS <- TagStudyID(lCTAS, vStudies, strStudyCol)
      }
      return(lCTAS)
    }

    lPerStudy <- lapply(vStudies, function(strStudy) {
      dfSub <- df[df[[strStudyCol]] == strStudy, , drop = FALSE]
      lRes <- fnRunOne(dfSub)
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

  lCTAS <- if (is.null(nSeed)) {
    fnAll()
  } else {
    rlang::check_installed("withr", "to seed `Analyze_CTAS()`.")
    withr::with_seed(nSeed, fnAll())
  }

  BuildResults(lCTAS = lCTAS, df = df, strStudyCol = strStudyCol)
}

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
BuildCTASInput <- function(df, strStudyCol, dfCustomTimeseries,
                           dfCustomReferenceGroups) {
  vSubjectCols <- intersect(
    c("subject_id", "site", "country", "region", strStudyCol),
    names(df)
  )
  dfSubjects <- dplyr::distinct(dplyr::select(df, dplyr::all_of(vSubjectCols)))
  if (!"country" %in% names(dfSubjects)) dfSubjects$country <- "no"
  if (!"region" %in% names(dfSubjects)) dfSubjects$region <- "no"

  vParamCols <- c("parameter_id", "parameter_name",
                  "parameter_category_1", "parameter_category_2",
                  "parameter_category_3")
  dfParameters <- df |>
    dplyr::distinct(dplyr::across(dplyr::all_of(vParamCols))) |>
    dplyr::mutate(
      time_point_count_min = NA_real_,
      subject_count_min = NA_real_,
      max_share_missing = NA_real_,
      generate_change_from_baseline = NA,
      timeseries_features_to_calculate = NA_character_,
      use_only_custom_timeseries = FALSE
    ) |>
    as.data.frame()

  dfData <- df |>
    dplyr::select(dplyr::all_of(c(
      "subject_id", "parameter_id",
      "timepoint_1_name", "timepoint_2_name", "timepoint_rank",
      "result", "baseline"
    ))) |>
    Prepare_TimepointRank() |>
    dplyr::mutate(timepoint_rank = as.numeric(.data$timepoint_rank)) |>
    as.data.frame()

  list(
    subjects = as.data.frame(dfSubjects),
    parameters = dfParameters,
    data = dfData,
    custom_timeseries = dfCustomTimeseries,
    custom_reference_groups = dfCustomReferenceGroups
  )
}

#' Enrich `site_scores` with parameter metadata and rename `studyid` to `study`
#'
#' Joins CTAS `site_scores` to `timeseries` on `timeseries_id` to recover
#' `parameter_id`, and to the parameter metadata derived from `df` to recover
#' the category columns CTAS discards. Renames `studyid` to `study` (ctasapp
#' vocabulary) when the multi-study contract is active.
#'
#' @keywords internal
BuildResults <- function(lCTAS, df, strStudyCol) {
  vCategories <- c(
    "parameter_category_1", "parameter_category_2", "parameter_category_3"
  )

  dfTimeseries <- dplyr::distinct(
    dplyr::select(lCTAS$timeseries, "timeseries_id", "parameter_id")
  )

  dfParameters <- dplyr::distinct(
    dplyr::select(df, "parameter_id", dplyr::all_of(vCategories))
  )
  if (anyDuplicated(dfParameters$parameter_id) > 0) {
    cli::cli_abort(
      "{.field parameter_id} is not unique in {.arg df}; parameter metadata is inconsistent."
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

  as.data.frame(dfResults)
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

#' Validate a CTAS long-format input frame
#'
#' @param df `data.frame` Long-format CTAS input.
#' @param strStudyCol `character` Optional study column expected on `df`.
#'
#' @return `NULL`, invisibly. Aborts when the input is unusable.
#'
#' @keywords internal
AssertCTASInput <- function(df, strStudyCol = "studyid") {
  if (!is.data.frame(df)) {
    cli::cli_abort("{.arg df} must be a {.cls data.frame}.")
  }

  vRequired <- c(
    "subject_id", "site",
    "parameter_id", "parameter_name",
    "parameter_category_1", "parameter_category_2", "parameter_category_3",
    "timepoint_1_name", "timepoint_2_name", "timepoint_rank",
    "result", "baseline"
  )

  vMissing <- setdiff(vRequired, names(df))
  if (length(vMissing) > 0) {
    cli::cli_abort(c(
      "{.arg df} is missing required column{?s}: {.val {vMissing}}.",
      "i" = "Build {.arg df} with {.fn Standardize_Domain} and an {.fn Input_*} function."
    ))
  }

  if (nrow(df) == 0) {
    cli::cli_abort("{.arg df} has no rows; there is nothing for CTAS to analyse.")
  }

  if (!is.null(strStudyCol) && !strStudyCol %in% names(df)) {
    cli::cli_abort(c(
      "{.arg df} is missing study column {.val {strStudyCol}}.",
      "i" = "Set {.arg strStudyCol} to {.code NULL} to opt out of the multi-study contract."
    ))
  }

  nSites <- dplyr::n_distinct(df$site)
  if (nSites < 2) {
    cli::cli_abort(c(
      "CTAS compares sites against each other, so at least 2 sites are required.",
      "x" = "{.arg df} contains {nSites} site{?s}."
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
