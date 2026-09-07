#' Write ctasapp shards to disk
#'
#' Writes the frames produced by the `3_reporting` workflows into `strDir` in
#' the layout the [ctasapp](https://github.com/IMPALA-Consortium/ctasapp)
#' dashboard reads. The function walks `lReporting` two levels deep: each
#' top-level element is a reporting-workflow output (a named list of frames)
#' and every data frame it contains is written using its inner name as the
#' file stem. Top-level bare data frames (e.g. `Reporting_Metrics`) are also
#' written, keyed by the lowercase workflow ID
#' (`Reporting_Metrics` -> `metrics.parquet`) so ctasapp picks them up even
#' when the Summary workflow that wraps them is skipped. This handles both
#' the metric side
#' (`Reporting_Results = list(results, input, untransformed)`) and the
#' queries side (`Reporting_Queries = list(queries)`) in a single call.
#'
#' `parquet` is the default: `input` grows quickly and Posit Connect
#' deployments of ctasapp read parquet from `embedded:`. `csv` is offered
#' because the dashboard's upload tab accepts it and it needs no extra
#' dependency.
#'
#' Empty frames are skipped (an empty `untransformed` is normal - only some
#' `Input_*()` functions record original values). The function errors if
#' `lReporting` contains no writable frames, so a mis-shaped input never
#' silently produces an empty output directory.
#'
#' @param lReporting `list` Output of `workr::RunWorkflows()` on the
#'   reporting workflows -- a named list whose elements are themselves named
#'   lists of data frames.
#' @param strDir `character` Directory to write into. Created if absent.
#' @param strFormat `character` `"parquet"` (default) or `"csv"`.
#'
#' @return `character` Paths written, invisibly.
#'
#' @examples
#' \dontrun{
#' Write_ctasapp(lReporting, tempdir())
#' }
#'
#' @export
Write_ctasapp <- function(lReporting,
                          strDir,
                          strFormat = "parquet") {
  strFormat <- rlang::arg_match(strFormat, c("parquet", "csv"))

  if (!is.list(lReporting) || is.data.frame(lReporting)) {
    cli::cli_abort(
      "{.arg lReporting} must be a list of reporting workflow outputs."
    )
  }
  if (!rlang::is_character(strDir) || length(strDir) != 1) {
    cli::cli_abort("{.arg strDir} must be a single directory path.")
  }
  if (strFormat == "parquet") {
    rlang::check_installed("arrow", "to write ctasapp shards as parquet.")
  }

  lFrames <- list()
  for (nmOuter in names(lReporting)) {
    xOuter <- lReporting[[nmOuter]]
    if (is.data.frame(xOuter)) {
      # Bare-frame reporting output (e.g. Reporting_Metrics) is written under
      # the lowercase workflow ID so ctasapp finds `metrics.parquet` even
      # when the Summary workflow is skipped.
      if (nrow(xOuter) > 0) {
        strStem <- tolower(sub("^Reporting_", "", nmOuter))
        lFrames[[strStem]] <- xOuter
      }
      next
    }
    if (!is.list(xOuter)) next
    for (nmInner in names(xOuter)) {
      xInner <- xOuter[[nmInner]]
      if (is.data.frame(xInner) && nrow(xInner) > 0) {
        lFrames[[nmInner]] <- xInner
      }
    }
  }

  if (length(lFrames) == 0) {
    cli::cli_abort(c(
      "{.arg lReporting} contains no writable data frames.",
      i = "Expected a list like `list(Reporting_Results = list(results = <df>, ...))`."
    ))
  }

  dir.create(strDir, recursive = TRUE, showWarnings = FALSE)

  vPaths <- vapply(names(lFrames), function(strName) {
    strFile <- file.path(strDir, paste0(strName, ".", strFormat))
    if (strFormat == "csv") {
      utils::write.csv(lFrames[[strName]], strFile, row.names = FALSE)
    } else {
      arrow::write_parquet(lFrames[[strName]], strFile)
    }
    strFile
  }, character(1))

  invisible(unname(vPaths))
}
