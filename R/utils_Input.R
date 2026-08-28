#' Filter a domain to the visits of interest
#'
#' Applied by [Standardize_Domain()] before any CTAS timeseries is constructed.
#' Sponsors encode scheduled visits differently, so the defaults stay
#' permissive and any sponsor-specific convention must be supplied through the
#' workflow YAML rather than baked into the mapping layer.
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
#' @export
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
