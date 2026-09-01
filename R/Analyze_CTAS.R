#' Score sites with CTAS
#'
#' A gsm-friendly wrapper around [ctas::process_a_study()]. It takes a single
#' long data frame in the CTAS + [ctasapp](https://github.com/IMPALA-Consortium/ctasapp)
#' vocabulary (typically the output of an `Input_*()` function), splits by
#' study when the multi-study contract is active, runs `process_a_study()`
#' per study, and returns the flat `results` frame ctasapp displays.
#'
#' Only `results` is returned; the `input` and `untransformed` frames ctasapp
#' also consumes are pure projections of the input `dfInput`, so the metric
#' YAML assembles the ctasapp payload in a separate `base::list` step (see
#' `inst/workflow/2_metrics/*.yaml`).
#'
#' The single-df pattern follows
#' [ctasval](https://github.com/IMPALA-Consortium/ctasval): `subjects` and
#' `parameters` are re-derived from `dfInput` via `distinct()` inside the
#' function so callers only have to keep one frame consistent.
#'
#' Feature selection is a boolean-per-feature contract instead of the
#' semicolon-delimited string CTAS accepts, so metric YAMLs can toggle
#' features individually from `meta:`.
#'
#' @param dfInput `data.frame` Long-format CTAS input with at minimum
#'   `subject_id`, `site`, `parameter_id`, `parameter_name`,
#'   `parameter_category_1/2/3`, `timepoint_1_name`, `timepoint_2_name`,
#'   `timepoint_rank`, `result`, `baseline`. Additional CTAS subject columns
#'   (`country`, `region`) are carried through when present.
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
#' @param strStudyCol `character` Column on `dfInput` identifying the study.
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
#'
#' @export
Analyze_CTAS <- function(dfInput,
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
  AssertCTASInput(dfInput, strStudyCol = strStudyCol)

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

  vStudies <- if (!is.null(strStudyCol) && strStudyCol %in% names(dfInput)) {
    sort(unique(as.character(dfInput[[strStudyCol]])))
  } else {
    character(0)
  }

  fnAll <- function() {
    if (length(vStudies) <= 1) {
      lCTAS <- fnRunOne(dfInput)
      AssertCTASResult(lCTAS)
      if (length(vStudies) == 1) {
        lCTAS <- TagStudyID(lCTAS, vStudies, strStudyCol)
      }
      return(lCTAS)
    }

    lPerStudy <- lapply(vStudies, function(strStudy) {
      dfSub <- dfInput[dfInput[[strStudyCol]] == strStudy, , drop = FALSE]
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

  BuildResults(lCTAS = lCTAS, dfInput = dfInput, strStudyCol = strStudyCol)
}
