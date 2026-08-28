#' Bind ctasapp shards across metric workflows and write them to disk
#'
#' Binds the `results`, `input` and `untransformed` frames across a named list
#' of metric workflow outputs and writes them to `strDir` in the layout the
#' [ctasapp](https://github.com/IMPALA-Consortium/ctasapp) dashboard reads.
#'
#' `parquet` is the default: `input` grows quickly and Posit Connect
#' deployments of ctasapp read parquet from `embedded:`. `csv` is offered
#' because the dashboard's upload tab accepts it and it needs no extra
#' dependency.
#'
#' An empty `untransformed` is normal - only some `Input_*()` functions record
#' original values - and the dashboard treats the file as optional, so no file
#' is written when the bound frame has zero rows. `dfQueries` is optional and
#' external (typically an EDC export); when supplied it is written verbatim
#' alongside the other files.
#'
#' @param lAnalysis `list` Named list where each element is a metric workflow
#'   output with `results`, `input` and `untransformed` frames.
#' @param strDir `character` Directory to write into. Created if absent.
#' @param strFormat `character` `"parquet"` (default) or `"csv"`.
#' @param dfQueries `data.frame` Optional queries frame, written as-is.
#'
#' @return `character` Paths written, invisibly.
#'
#' @examples
#' \dontrun{
#' Write_Results(lAnalysis, tempdir())
#' }
#'
#' @export
Write_Results <- function(lAnalysis,
                          strDir,
                          strFormat = "parquet",
                          dfQueries = NULL) {
  strFormat <- rlang::arg_match(strFormat, c("parquet", "csv"))

  if (!is.list(lAnalysis) || is.data.frame(lAnalysis)) {
    cli::cli_abort(
      "{.arg lAnalysis} must be a list of metric workflow outputs."
    )
  }
  if (!rlang::is_character(strDir) || length(strDir) != 1) {
    cli::cli_abort("{.arg strDir} must be a single directory path.")
  }
  if (strFormat == "parquet") {
    rlang::check_installed("arrow", "to write ctasapp shards as parquet.")
  }

  fnPluck <- function(strName) {
    dplyr::bind_rows(lapply(lAnalysis, `[[`, strName))
  }

  dir.create(strDir, recursive = TRUE, showWarnings = FALSE)

  lWrite <- list(
    results = fnPluck("results"),
    input = fnPluck("input"),
    untransformed = fnPluck("untransformed"),
    queries = dfQueries
  )
  lWrite <- Filter(function(df) !is.null(df) && nrow(df) > 0, lWrite)

  vPaths <- vapply(names(lWrite), function(strName) {
    strFile <- file.path(strDir, paste0(strName, ".", strFormat))
    if (strFormat == "csv") {
      utils::write.csv(lWrite[[strName]], strFile, row.names = FALSE)
    } else {
      arrow::write_parquet(lWrite[[strName]], strFile)
    }
    strFile
  }, character(1))

  invisible(unname(vPaths))
}
