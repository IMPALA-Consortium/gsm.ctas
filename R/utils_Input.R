#' Filter a domain to the visits of interest
#'
#' Applied before any CTAS timeseries is constructed. Both patterns are
#' deliberately parameterised: sponsors encode scheduled visits differently, so
#' the defaults must stay permissive and any sponsor-specific convention must be
#' supplied through the workflow YAML rather than baked into the mapping layer.
#'
#' @param dfInput `data.frame` Containing the visit column.
#' @param strVisitCol `character` Name of the visit column.
#' @param strVisitPattern `character` Regular expression that a visit must match
#'   to be retained. `NULL` (default) keeps all visits.
#' @param strExcludePattern `character` Regular expression whose matches are
#'   dropped. Matched case-insensitively. Default `"unsch"` removes unscheduled
#'   visits. `NULL` disables the exclusion.
#'
#' @return `data.frame` A filtered copy of `dfInput`.
#'
#' @keywords internal
FilterVisits <- function(dfInput,
                         strVisitCol = "VISIT",
                         strVisitPattern = NULL,
                         strExcludePattern = "unsch") {
  vVisit <- as.character(dfInput[[strVisitCol]])

  bKeep <- rep(TRUE, nrow(dfInput))

  if (!is.null(strVisitPattern)) {
    bKeep <- bKeep & grepl(strVisitPattern, vVisit, ignore.case = TRUE)
  }

  if (!is.null(strExcludePattern)) {
    bKeep <- bKeep & !grepl(strExcludePattern, vVisit, ignore.case = TRUE)
  }

  dfInput[!is.na(bKeep) & bKeep, , drop = FALSE]
}

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

#' Empty CTAS `data` frame
#'
#' @return `data.frame` with zero rows and the CTAS `data` schema.
#'
#' @keywords internal
EmptyCTASData <- function() {
  data.frame(
    subject_id = character(0),
    parameter_id = character(0),
    timepoint_1_name = character(0),
    timepoint_2_name = character(0),
    timepoint_rank = numeric(0),
    result = numeric(0),
    baseline = numeric(0),
    stringsAsFactors = FALSE
  )
}

#' Empty CTAS `parameters` frame
#'
#' @return `data.frame` with zero rows and the CTAS `parameters` schema, before
#'   the defaults added by [Combine_CTAS_Input()].
#'
#' @keywords internal
EmptyCTASParameters <- function() {
  data.frame(
    parameter_id = character(0),
    parameter_name = character(0),
    parameter_category_1 = character(0),
    parameter_category_2 = character(0),
    parameter_category_3 = character(0),
    stringsAsFactors = FALSE
  )
}

#' Empty untransformed detail frame
#'
#' @return `data.frame` with zero rows and the untransformed detail schema.
#'
#' @keywords internal
EmptyCTASUntransformed <- function() {
  data.frame(
    subject_id = character(0),
    parameter_category_2 = character(0),
    timepoint_1_name = character(0),
    original_value = numeric(0),
    lower = numeric(0),
    upper = numeric(0),
    original_category = character(0),
    stringsAsFactors = FALSE
  )
}

#' Standardise a domain into the shared CTAS working frame
#'
#' Renames the sponsor's SDTM columns into the CTAS vocabulary and filters
#' visits. Shared by all `Input_*()` functions so that column-name
#' parameterisation is implemented once.
#'
#' @inheritParams FilterVisits
#' @param dfDomain `data.frame` An SDTM domain.
#' @param strSubjectCol `character` Subject identifier column.
#' @param strTestCDCol `character` Short test-code column.
#' @param strTestCol `character` Long test-name column. Falls back to
#'   `strTestCDCol` when `NULL`.
#' @param strValueCol `character` Result column.
#' @param strVisitNumCol `character` Numeric visit-order column.
#'
#' @return `data.frame` with columns `subject_id`, `TestCD`, `TestName`,
#'   `timepoint_1_name`, `timepoint_rank` and `Value`.
#'
#' @keywords internal
StandardizeDomain <- function(dfDomain,
                              strSubjectCol = "USUBJID",
                              strTestCDCol = "VSTESTCD",
                              strTestCol = "VSTEST",
                              strValueCol = "VSSTRESN",
                              strVisitCol = "VISIT",
                              strVisitNumCol = "VISITNUM",
                              strVisitPattern = NULL,
                              strExcludePattern = "unsch") {
  AssertColumns(
    dfDomain,
    c(strSubjectCol, strTestCDCol, strTestCol, strValueCol, strVisitCol, strVisitNumCol),
    "dfDomain"
  )

  strNameCol <- if (is.null(strTestCol)) strTestCDCol else strTestCol

  dfDomain |>
    FilterVisits(
      strVisitCol = strVisitCol,
      strVisitPattern = strVisitPattern,
      strExcludePattern = strExcludePattern
    ) |>
    dplyr::transmute(
      subject_id = as.character(.data[[strSubjectCol]]),
      TestCD = as.character(.data[[strTestCDCol]]),
      TestName = as.character(.data[[strNameCol]]),
      timepoint_1_name = as.character(.data[[strVisitCol]]),
      timepoint_rank = as.numeric(.data[[strVisitNumCol]]),
      Value = .data[[strValueCol]]
    )
}

#' Assemble the CTAS `data` frame from a standardised working frame
#'
#' @param dfWork `data.frame` With `subject_id`, `parameter_id`,
#'   `timepoint_1_name`, `timepoint_rank` and `result`.
#'
#' @return `data.frame` in the CTAS `data` schema, with contiguous ranks.
#'
#' @keywords internal
BuildCTASData <- function(dfWork) {
  dfWork |>
    dplyr::transmute(
      subject_id = .data$subject_id,
      parameter_id = .data$parameter_id,
      timepoint_1_name = .data$timepoint_1_name,
      timepoint_2_name = NA_character_,
      timepoint_rank = as.numeric(.data$timepoint_rank),
      result = as.numeric(.data$result),
      baseline = NA_real_
    ) |>
    Prepare_TimepointRank() |>
    dplyr::mutate(timepoint_rank = as.numeric(.data$timepoint_rank)) |>
    as.data.frame()
}
