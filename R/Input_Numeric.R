#' Transform a standardised numeric findings frame for CTAS
#'
#' Consumes the long-format frame produced by [Standardize_Domain()] and
#' produces the same shape enriched with the CTAS `result`/`baseline` columns
#' and the parameter-category triad expected by [Analyze_CTAS()]. Values are
#' used as-is; use [Input_Range()] when reference ranges are available and
#' values must be made comparable across tests.
#'
#' @param df `data.frame` Long-format output of [Standardize_Domain()], with
#'   at minimum `subject_id`, `parameter_id`, `parameter_name`,
#'   `parameter_category_1`, `visit`, `visitnum`, `value`.
#' @param strPrefix `character` Prefix for the generated `parameter_id`, kept
#'   distinct per transformation so `range_normalized` and `ratio_missing`
#'   never collide on the same test.
#'
#' @return `data.frame` in the CTAS long-format vocabulary, ready to be passed
#'   to [Analyze_CTAS()]. `parameter_id` is prefixed with `strPrefix` so it
#'   stays unique per metric, while `parameter_category_2` keeps the raw
#'   input `parameter_id` so ctasapp can stitch this metric together with
#'   sibling metrics on the same field. All non-value columns are preserved.
#'
#' @export
Input_Numeric <- function(df, strPrefix = "NUM") {
  AssertColumns(
    df,
    c("subject_id", "parameter_id", "parameter_name",
      "parameter_category_1", "visit", "visitnum", "value"),
    "df"
  )

  df |>
    dplyr::filter(!is.na(.data$value)) |>
    dplyr::mutate(
      parameter_category_2 = .data$parameter_id,
      parameter_id = paste0(.env$strPrefix, "_", .data$parameter_id),
      parameter_name = paste0(.data$parameter_category_1, ": ", .data$parameter_name),
      parameter_category_3 = "numeric",
      timepoint_1_name = .data$visit,
      timepoint_2_name = NA_character_,
      timepoint_rank = as.numeric(.data$visitnum),
      result = as.numeric(.data$value),
      baseline = NA_real_
    ) |>
    as.data.frame()
}
