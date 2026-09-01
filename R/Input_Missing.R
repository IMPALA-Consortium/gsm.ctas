#' Convert findings to a running missing-ratio timeseries for CTAS
#'
#' Consumes the long-format frame produced by [Standardize_Domain()] and
#' replaces `value` with a running missing ratio per (subject, parameter,
#' visit) so CTAS can score sites on data-completeness patterns. Rows with
#' `NA` values are kept because they carry the signal.
#'
#' @param dfInput `data.frame` Long-format output of [Standardize_Domain()].
#' @param strPrefix `character` Prefix for the generated `parameter_id`.
#'
#' @return `data.frame` in the CTAS long-format vocabulary. `parameter_id`
#'   is prefixed with `strPrefix`; `parameter_category_2` keeps the raw
#'   input `parameter_id` so ctasapp can stitch this metric with sibling
#'   metrics on the same field.
#'
#' @export
Input_Missing <- function(dfInput, strPrefix = "MISS") {
  AssertColumns(
    dfInput,
    c("subject_id", "parameter_id", "parameter_name",
      "parameter_category_1", "parameter_category_2",
      "visit", "visitnum", "value"),
    "dfInput"
  )

  dfInput |>
    dplyr::arrange(.data$subject_id, .data$parameter_id,
                   .data$visitnum, .data$visit) |>
    dplyr::mutate(
      parameter_id = paste0(.env$strPrefix, "_", .data$parameter_category_2),
      parameter_name = paste0("Ratio Missing: ", .data$parameter_name),
      parameter_category_3 = "ratio_missing",
      timepoint_1_name = .data$visit,
      timepoint_2_name = NA_character_,
      timepoint_rank = as.numeric(.data$visitnum),
      result = Prepare_MissingRatio(
        vValue = .data$value,
        vSubjectID = .data$subject_id,
        vParameterID = .data$parameter_id
      ),
      baseline = NA_real_
    )
}
