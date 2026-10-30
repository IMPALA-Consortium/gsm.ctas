#' Normalise reference-bounded numeric findings for CTAS
#'
#' Consumes the long-format frame produced by [Standardize_Domain()] and
#' normalises `value` against the reference bounds `low`/`high` so results from
#' different tests are comparable on the same scale. The original values are
#' preserved as extra columns (`original_value`, `lower`, `upper`,
#' `original_category`).
#'
#' Rows are never dropped within a field: rows with a missing value or an
#' unusable reference range keep `result = NA` so CTAS can apply its
#' missingness threshold. Fields where more than `dMaxShareMissingRange` of
#' the observed values lack a usable range are emitted unnormalised as
#' `parameter_category_3 = "numeric"` with the `strFallbackPrefix` prefix.
#' Fields without any observed value are kept with `result = NA` and listed
#' in a message, so they still anchor source data in ctasapp.
#'
#' @param dfInput `data.frame` Long-format output of [Standardize_Domain()] with
#'   the reference range columns `low`/`high`.
#' @param strPrefix `character` Prefix for the generated `parameter_id`.
#' @param strFallbackPrefix `character` Prefix for fields switched to raw
#'   numeric values.
#' @param dMaxShareMissingRange `numeric` Maximum share of observed values
#'   per field without a usable reference range before the field switches to
#'   raw numeric values.
#'
#' @section Data Specification:
#' `dfInput` must include:
#' - `subject_id` - Subject identifier.
#' - `parameter_id` - Raw test code (e.g. `LBTESTCD`).
#' - `parameter_name` - Human-readable test label.
#' - `parameter_category_1` - Domain label (e.g. `"Labs"`).
#' - `parameter_category_2` - Field anchor; retained as the grouping key.
#' - `visit`, `visitnum` - Visit label and numeric ordering.
#' - `value`, `low`, `high` - Numeric result and reference bounds.
#'
#' @return `data.frame` in the CTAS long-format vocabulary carrying the extra
#'   `original_value`/`lower`/`upper`/`original_category` columns.
#'   `parameter_id` is prefixed with `strPrefix` (or `strFallbackPrefix`);
#'   `parameter_category_2` keeps the raw input `parameter_id` so ctasapp can
#'   stitch this metric with sibling metrics on the same field.
#'
#' @export
Transform_Range <- function(dfInput,
                            strPrefix = "RANGE",
                            strFallbackPrefix = "NUM",
                            dMaxShareMissingRange = 0.5) {
  AssertColumns(
    dfInput,
    c(
      "subject_id", "parameter_id", "parameter_name",
      "parameter_category_1", "parameter_category_2",
      "visit", "visitnum",
      "value", "low", "high"
    ),
    "dfInput"
  )

  if (!"original_category" %in% names(dfInput)) {
    dfInput$original_category <- NA_character_
  }

  dfFields <- dfInput |>
    dplyr::mutate(
      bHasValue = !is.na(.data$value),
      bNoRange = .data$bHasValue &
        is.na(Prepare_Normalize(.data$value, .data$low, .data$high))
    ) |>
    dplyr::summarise(
      nValues = sum(.data$bHasValue),
      dShareNoRange = sum(.data$bNoRange) / max(.data$nValues, 1),
      .by = "parameter_category_2"
    )

  vEmpty <- dfFields$parameter_category_2[dfFields$nValues == 0]
  vFallback <- dfFields$parameter_category_2[
    dfFields$nValues > 0 & dfFields$dShareNoRange > dMaxShareMissingRange
  ]

  if (length(vEmpty) > 0) {
    cli::cli_inform(
      "{.fn Transform_Range}: {length(vEmpty)} field{?s} {?is/are} 100% missing for all subjects: {.val {vEmpty}}."
    )
  }
  if (length(vFallback) > 0) {
    cli::cli_inform(
      "{.fn Transform_Range} kept {length(vFallback)} field{?s} as raw {.val numeric} because most values lack a usable reference range: {.val {vFallback}}."
    )
  }

  dfOut <- dfInput |>
    dplyr::mutate(
      bFallback = .data$parameter_category_2 %in% .env$vFallback,
      original_value = as.numeric(.data$value),
      lower = as.numeric(.data$low),
      upper = as.numeric(.data$high),
      original_category = as.character(.data$original_category),
      parameter_id = paste0(
        ifelse(.data$bFallback, .env$strFallbackPrefix, .env$strPrefix),
        "_", .data$parameter_category_2
      ),
      parameter_name = ifelse(
        .data$bFallback,
        paste0(.data$parameter_category_1, ": ", .data$parameter_name),
        paste0(.data$parameter_category_1, " (norm): ", .data$parameter_name)
      ),
      parameter_category_3 = ifelse(.data$bFallback, "numeric", "range_normalized"),
      timepoint_1_name = .data$visit,
      timepoint_2_name = NA_character_,
      timepoint_rank = as.numeric(.data$visitnum),
      result = ifelse(
        .data$bFallback,
        .data$original_value,
        Prepare_Normalize(.data$original_value, .data$lower, .data$upper)
      ),
      baseline = NA_real_
    ) |>
    dplyr::select(-"bFallback")

  dfOut
}
