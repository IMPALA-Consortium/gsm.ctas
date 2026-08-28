#' Score sites with CTAS and emit ctasapp-shaped shards
#'
#' A gsm-friendly wrapper around [ctas::process_a_study()]. It validates the
#' input list produced by [Combine_CTAS_Input()], applies reproducible seeding,
#' runs `process_a_study()` per study, and returns three flat frames in the
#' shape [ctasapp](https://github.com/IMPALA-Consortium/ctasapp) uploads
#' consume.
#'
#' `process_a_study()` is single-study by construction. When `lInput$subjects`
#' contains more than one value in `strStudyCol`, the input is split by study,
#' scored per study, and the per-study `site_scores` and `timeseries` are
#' stacked. The output column is named `study` (ctasapp vocabulary), not
#' `studyid`.
#'
#' Feature selection is a boolean-per-feature contract instead of the
#' semicolon-delimited string CTAS accepts, so metric YAMLs can toggle
#' features individually from `meta:`.
#'
#' @param lInput `list` Result of [Combine_CTAS_Input()].
#' @param strID `character` Identifier written to the output list. Free-form.
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
#' @param strScoringMethod `character` One of "ks", "mixedeffects",
#'   "avg_feat_value".
#' @param strPadjustMethod `character` Passed to [stats::p.adjust()].
#' @param nSeed `numeric` Optional seed for reproducibility.
#' @param strStudyCol `character` Column on `lInput$subjects` identifying the
#'   study. `NULL` disables the split and drops the `study` output column.
#' @param ... Further arguments passed to [ctas::process_a_study()].
#'
#' @return `list` with elements:
#'   * `ID` - copy of `strID`.
#'   * `results` - flat data frame; one row per (site x timeseries x feature),
#'     carrying `parameter_id` and the category columns.
#'   * `input` - flat data frame; the CTAS run's `data` joined to `subjects`
#'     and `parameters`, in the shape ctasapp displays.
#'   * `untransformed` - `lInput$untransformed`, tagged with `study` when the
#'     multi-study contract is active.
#'
#' @examples
#' \donttest{
#' # Build a mapped numeric domain from raw SDTM. In practice this is done by
#' # the mapping workflow YAMLs; see `vignette("gsm-ctas")`.
#' dfVS <- data.frame(
#'   studyid = as.character(pharmaversesdtm::vs$STUDYID),
#'   subject_id = as.character(pharmaversesdtm::vs$USUBJID),
#'   parameter_id = as.character(pharmaversesdtm::vs$VSTESTCD),
#'   parameter_name = as.character(pharmaversesdtm::vs$VSTEST),
#'   parameter_category_1 = "Vital Signs",
#'   visit = as.character(pharmaversesdtm::vs$VISIT),
#'   visitnum = as.numeric(pharmaversesdtm::vs$VISITNUM),
#'   value = as.numeric(pharmaversesdtm::vs$VSSTRESN)
#' )
#' dfDM <- data.frame(
#'   studyid = as.character(pharmaversesdtm::dm$STUDYID),
#'   subject_id = as.character(pharmaversesdtm::dm$USUBJID),
#'   site = as.character(pharmaversesdtm::dm$SITEID),
#'   country = as.character(pharmaversesdtm::dm$COUNTRY)
#' )
#' lInput <- Combine_CTAS_Input(
#'   Input_Numeric(dfVS),
#'   dfSubjects = Input_Subjects(dfDM)
#' )
#' lAnalysis <- Analyze_CTAS(lInput, strID = "numeric")
#' }
#'
#' @export
Analyze_CTAS <- function(lInput,
                         strID = "ctas",
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
                         nSeed = NULL,
                         strStudyCol = "studyid",
                         ...) {
  AssertCTASInput(lInput, strStudyCol = strStudyCol)

  strScoringMethod <- rlang::arg_match(
    strScoringMethod, c("ks", "mixedeffects", "avg_feat_value")
  )

  strFeatures <- AssembleFeatures(
    bAutocorr = bAutocorr, bAverage = bAverage, bSD = bSD, bRange = bRange,
    bUniqueValueCountRelative = bUniqueValueCountRelative,
    bOwnSiteSimilScore = bOwnSiteSimilScore, bLOF = bLOF
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

  lCTAS <- if (is.null(nSeed)) {
    fnAll()
  } else {
    rlang::check_installed("withr", "to seed `Analyze_CTAS()`.")
    withr::with_seed(nSeed, fnAll())
  }

  BuildAnalysisList(
    strID = strID, lCTAS = lCTAS, lInput = lInput, strStudyCol = strStudyCol
  )
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

#' Build the ctasapp-shaped output list from a CTAS result and its input
#'
#' Joins `site_scores` to `timeseries` on `timeseries_id` to recover
#' `parameter_id`, and to `parameters` to recover the category columns CTAS
#' discards. Builds the flat `input` frame as `data ⨝ subjects ⨝ parameters`.
#' `studyid` is renamed to `study` on the way out so the output matches the
#' ctasapp upload contract.
#'
#' @keywords internal
BuildAnalysisList <- function(strID, lCTAS, lInput, strStudyCol) {
  vCategories <- c(
    "parameter_category_1", "parameter_category_2", "parameter_category_3"
  )
  AssertColumns(
    lInput$parameters, c("parameter_id", "parameter_name", vCategories),
    "lInput$parameters"
  )
  AssertColumns(lInput$subjects, c("subject_id", "site"), "lInput$subjects")

  dfTimeseries <- dplyr::distinct(
    dplyr::select(lCTAS$timeseries, "timeseries_id", "parameter_id")
  )

  dfParameters <- dplyr::distinct(
    dplyr::select(
      lInput$parameters, "parameter_id", dplyr::all_of(vCategories)
    )
  )
  if (anyDuplicated(dfParameters$parameter_id) > 0) {
    cli::cli_abort(
      "{.field parameter_id} is not unique in {.arg lInput$parameters}."
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
  if (any(is.na(dfResults$parameter_category_1))) {
    cli::cli_abort(
      "Scored parameter{?s} absent from {.arg lInput$parameters}."
    )
  }

  dfInput <- lInput$data |>
    dplyr::left_join(lInput$subjects, by = "subject_id") |>
    dplyr::left_join(
      dplyr::select(
        lInput$parameters, "parameter_id", "parameter_name",
        dplyr::all_of(vCategories)
      ),
      by = "parameter_id"
    )

  if (any(is.na(dfInput$site))) {
    cli::cli_abort(
      "{.field subject_id} in {.arg lInput$data} has no match in {.arg lInput$subjects}."
    )
  }

  dfUntransformed <- if (is.null(lInput$untransformed)) {
    EmptyCTASUntransformed()
  } else {
    lInput$untransformed
  }

  # untransformed carries subject_id but no study; add it from subjects.
  bStudy <- !is.null(strStudyCol) && strStudyCol %in% names(lInput$subjects)
  if (bStudy && nrow(dfUntransformed) > 0 &&
      !strStudyCol %in% names(dfUntransformed)) {
    dfUntransformed <- dfUntransformed |>
      dplyr::left_join(
        dplyr::distinct(
          dplyr::select(
            lInput$subjects, "subject_id", dplyr::all_of(strStudyCol)
          )
        ),
        by = "subject_id"
      )
  }

  if (bStudy) {
    if (strStudyCol %in% names(dfResults)) {
      dfResults <- dplyr::rename(dfResults, study = dplyr::all_of(strStudyCol))
    }
    if (strStudyCol %in% names(dfInput)) {
      dfInput <- dplyr::rename(dfInput, study = dplyr::all_of(strStudyCol))
    }
    if (strStudyCol %in% names(dfUntransformed)) {
      dfUntransformed <- dplyr::rename(
        dfUntransformed, study = dplyr::all_of(strStudyCol)
      )
    }
  }

  list(
    ID = strID,
    results = as.data.frame(dfResults),
    input = as.data.frame(dfInput),
    untransformed = as.data.frame(dfUntransformed)
  )
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
