#' Bind one named shard across metric workflow outputs
#'
#' Stacks the `strName` element (`"results"`, `"input"` or `"untransformed"`)
#' from every entry of `lAnalysis` into a single data frame. Used by the
#' reporting workflow to concatenate metric shards into the frames
#' [ctasapp](https://github.com/IMPALA-Consortium/ctasapp) reads, and reused
#' internally by [Write_ctasapp()].
#'
#' `studyid` is renamed to `study` when present so the bound frames match
#' the ctasapp column convention.
#'
#' For `"untransformed"`, the transformation columns (`value`, `result`,
#' `low`, `high`, `parameter_id`, `parameter_category_3`) are removed
#' before binding, since their types differ between metrics. Rows where no
#' value was reported are kept so source data stays visible in ctasapp. Rows
#' are de-duplicated on the ctasapp join keys (`study`, `subject_id`,
#' `parameter_category_2`, `timepoint_1_name`), keeping the row with the most
#' non-missing `original_value`/`lower`/`upper`/`original_category`, so a
#' field fed into several metrics appears once.
#'
#' @param lAnalysis `list` Named list of metric workflow outputs, each with
#'   `results`, `input` and optionally `untransformed` frames.
#' @param strName `character` Frame name to pluck from each entry.
#'
#' @return `data.frame` The bound frame. Zero rows when no entry contained
#'   the frame.
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

  lFrames <- lapply(lAnalysis, `[[`, strName)

  if (strName == "untransformed") {
    vDrop <- c(
      "value", "result", "low", "high", "parameter_id", "parameter_category_3"
    )
    lFrames <- lapply(lFrames, function(df) {
      if (is.null(df)) {
        return(NULL)
      }
      df[, setdiff(names(df), vDrop), drop = FALSE]
    })
  }

  df <- dplyr::bind_rows(lFrames)

  if (!is.null(df) && "studyid" %in% names(df) && !"study" %in% names(df)) {
    df <- dplyr::rename(df, study = "studyid")
  }

  if (strName == "untransformed") {
    if (is.null(df) || nrow(df) == 0) {
      return(df[0, , drop = FALSE])
    }
    vKeys <- intersect(
      c("study", "subject_id", "parameter_category_2", "timepoint_1_name"),
      names(df)
    )
    if (length(vKeys) == 0) {
      return(df)
    }
    # Fields read by several metrics arrive once per metric; keep the fullest copy.
    vInfo <- intersect(
      c("original_value", "lower", "upper", "original_category"),
      names(df)
    )
    df <- df |>
      dplyr::arrange(dplyr::desc(rowSums(!is.na(df[, vInfo, drop = FALSE])))) |>
      dplyr::distinct(dplyr::across(dplyr::all_of(vKeys)), .keep_all = TRUE)
  }

  df
}
