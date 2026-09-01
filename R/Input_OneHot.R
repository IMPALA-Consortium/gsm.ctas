#' One-hot encode a categorical findings frame for CTAS
#'
#' Consumes the long-format frame produced by [Standardize_Domain()] on a
#' categorical source (e.g. SDTM RS with `RSSTRESC`) and expands it into one
#' row per (observation x observed level of the same test), so that each
#' level becomes its own binary CTAS timeseries. Levels are enumerated within
#' each `parameter_category_2` so tests with different level sets stay
#' separated.
#'
#' @param dfInput `data.frame` Long-format output of [Standardize_Domain()], with
#'   at minimum `subject_id`, `parameter_id`, `parameter_name`,
#'   `parameter_category_1`, `parameter_category_2`, `visit`, `visitnum`,
#'   `value`. `value` is treated as a character categorical.
#' @param strPrefix `character` Prefix for the generated `parameter_id`.
#'
#' @return `data.frame` in the CTAS long-format vocabulary carrying the extra
#'   `original_category` column. `parameter_id` is prefixed with `strPrefix`
#'   and includes the level (`CAT_OVRLRESP=CR`); `parameter_category_2` keeps
#'   the raw input test code so ctasapp stitches every level of the same
#'   test into a single faceted field entry. `result` is the 0/1 indicator
#'   used by [Analyze_CTAS()].
#'
#' @export
Input_OneHot <- function(dfInput, strPrefix = "CAT") {
  AssertColumns(
    dfInput,
    c("subject_id", "parameter_id", "parameter_name",
      "parameter_category_1", "parameter_category_2",
      "visit", "visitnum", "value"),
    "dfInput"
  )

  dfClean <- dfInput |>
    dplyr::filter(!is.na(.data$value), nzchar(as.character(.data$value))) |>
    dplyr::mutate(original_category = as.character(.data$value)) |>
    dplyr::group_by(.data$parameter_category_2) |>
    dplyr::mutate(RowIndex = dplyr::row_number()) |>
    dplyr::ungroup()

  if (nrow(dfClean) == 0) {
    return(dfClean)
  }

  dfEncoded <- dfClean |>
    dplyr::group_by(.data$parameter_category_2) |>
    dplyr::group_modify(~ Prepare_Categorical(
      .x$original_category,
      strPrefix = .y$parameter_category_2
    )) |>
    dplyr::ungroup()

  dfOut <- dplyr::inner_join(
    dfClean, dfEncoded,
    by = c("parameter_category_2", "RowIndex")
  )

  dfOut |>
    dplyr::mutate(
      parameter_id = paste0(.env$strPrefix, "_", .data$Level),
      parameter_name = paste0(
        .data$parameter_category_1, ": ", .data$parameter_name,
        " - ", .data$Level
      ),
      parameter_category_3 = "categorical",
      timepoint_1_name = .data$visit,
      timepoint_2_name = NA_character_,
      timepoint_rank = as.numeric(.data$visitnum),
      result = as.numeric(.data$Encoded),
      # `value` is coerced to the 0/1 CTAS signal so `Write_ctasapp` can
      # bind_rows with numeric-`value` shards; the raw label is kept as
      # `original_category`.
      value = as.numeric(.data$Encoded),
      baseline = NA_real_
    ) |>
    dplyr::select(-dplyr::all_of(c("RowIndex", "Level", "Encoded")))
}
