#' Bind one named shard across metric workflow outputs
#'
#' Stacks the `strName` element (`"results"`, `"input"` or `"untransformed"`)
#' from every entry of `lAnalysis` into a single data frame. Used by the
#' reporting workflow to concatenate metric shards into the frames
#' [ctasapp](https://github.com/IMPALA-Consortium/ctasapp) reads, and reused
#' internally by [Write_ctasapp()].
#'
#' `studyid` is renamed to `study` when present so the bound frames match
#' the ctasapp column convention. For `"untransformed"`, rows are dropped
#' only when both `original_value` and `original_category` are missing --
#' numeric metrics carry `original_value`, categorical metrics carry
#' `original_category`, and either signal is enough to keep the row.
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
#' BindResults_CTAS(lAnalysis, "results")
#' }
#'
#' @export
BindResults_CTAS <- function(lAnalysis, strName) {
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
    if (is.null(df) || nrow(df) == 0) {
      return(df[0, , drop = FALSE])
    }
    vHasValue <- if ("original_value" %in% names(df)) !is.na(df$original_value) else rep(FALSE, nrow(df))
    vHasCategory <- if ("original_category" %in% names(df)) !is.na(df$original_category) else rep(FALSE, nrow(df))
    df <- df[vHasValue | vHasCategory, , drop = FALSE]
  }

  df
}
