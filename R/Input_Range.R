#' Normalise reference-bounded numeric findings for CTAS
#'
#' Consumes the long-format frame produced by [Standardize_Domain()] and
#' normalises `value` against the reference bounds `low`/`high` so results from
#' different tests are comparable on the same scale. The original values are
#' preserved as extra columns (`original_value`, `lower`, `upper`,
#' `original_category`) so [Analyze_CTAS()] can emit the ctasapp-shaped
#' `untransformed` frame without extra bookkeeping.
#'
#' @param dfInput `data.frame` Long-format output of [Standardize_Domain()] with
#'   the reference range columns `low`/`high`.
#' @param strPrefix `character` Prefix for the generated `parameter_id`.
#'
#' @return `data.frame` in the CTAS long-format vocabulary carrying the extra
#'   `original_value`/`lower`/`upper`/`original_category` columns.
#'   `parameter_id` is prefixed with `strPrefix`; `parameter_category_2` keeps
#'   the raw input `parameter_id` so ctasapp can stitch this metric with
#'   sibling metrics on the same field.
#'
#' @export
Input_Range <- function(dfInput, strPrefix = "RANGE") {
  AssertColumns(
    dfInput,
    c("subject_id", "parameter_id", "parameter_name",
      "parameter_category_1", "parameter_category_2",
      "visit", "visitnum",
      "value", "low", "high"),
    "dfInput"
  )

  dfInput |>
    dplyr::filter(!is.na(.data$value)) |>
    dplyr::mutate(
      original_value = as.numeric(.data$value),
      lower = as.numeric(.data$low),
      upper = as.numeric(.data$high),
      original_category = NA_character_,
      parameter_id = paste0(.env$strPrefix, "_", .data$parameter_category_2),
      parameter_name = paste0(.data$parameter_category_1, " (norm): ", .data$parameter_name),
      parameter_category_3 = "range_normalized",
      timepoint_1_name = .data$visit,
      timepoint_2_name = NA_character_,
      timepoint_rank = as.numeric(.data$visitnum),
      result = Prepare_Normalize(.data$original_value, .data$lower, .data$upper),
      baseline = NA_real_
    ) |>
    dplyr::filter(!is.na(.data$result))
}
