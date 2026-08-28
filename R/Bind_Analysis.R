#' Bind one named shard across metric workflow outputs
#'
#' Stacks the `strName` element (`"results"`, `"input"` or `"untransformed"`)
#' from every entry of `lAnalysis` into a single data frame. Used by the
#' reporting workflow to concatenate metric shards into the frames
#' [ctasapp](https://github.com/IMPALA-Consortium/ctasapp) reads, and reused
#' internally by [Write_Results()].
#'
#' `studyid` is renamed to `study` when present so the bound frames match
#' the ctasapp column convention. For `"untransformed"`, rows with a missing
#' `original_value` are dropped because only some `Input_*()` functions
#' record originals and the ctasapp `untransformed` file is empty-optional.
#'
#' @param lAnalysis `list` Named list of metric workflow outputs, each with
#'   `results`, `input` and optionally `untransformed` frames.
#' @param strName `character` Shard name to pluck from each entry.
#'
#' @return `data.frame` The bound frame. Zero rows when no entry contained
#'   the shard.
#'
#' @examples
#' \dontrun{
#' Bind_Analysis(lAnalysis, "results")
#' }
#'
#' @export
Bind_Analysis <- function(lAnalysis, strName) {
  if (!is.list(lAnalysis) || is.data.frame(lAnalysis)) {
    cli::cli_abort(
      "{.arg lAnalysis} must be a list of metric workflow outputs."
    )
  }
  if (!rlang::is_character(strName) || length(strName) != 1) {
    cli::cli_abort("{.arg strName} must be a single shard name.")
  }

  df <- dplyr::bind_rows(lapply(lAnalysis, `[[`, strName))

  if (!is.null(df) && "studyid" %in% names(df) && !"study" %in% names(df)) {
    df <- dplyr::rename(df, study = "studyid")
  }

  if (strName == "untransformed") {
    if (!is.null(df) && "original_value" %in% names(df)) {
      df <- df[!is.na(df$original_value), , drop = FALSE]
    } else {
      df <- df[0, , drop = FALSE]
    }
  }

  df
}
