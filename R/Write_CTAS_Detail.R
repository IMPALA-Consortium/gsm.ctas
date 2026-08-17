#' Write the CTAS detail object to files `ctasapp` can load
#'
#' `ctasapp` reads flat files rather than R objects, so the handoff is a
#' directory of `results` / `input` / `untransformed` files - the same names its
#' upload tab and its `embedded:` config block expect.
#'
#' CSV is the default because it needs no extra dependency and is what the
#' dashboard's upload tab accepts. Use `strFormat = "parquet"` for a real study:
#' `Input` holds one row per subject x parameter x timepoint and becomes large
#' quickly, and a Posit Connect deployment reads parquet from `embedded:`.
#'
#' `Untransformed` is written only when it has rows, matching the dashboard's
#' treatment of it as optional.
#'
#' @param lDetail `list` Result of [Combine_CTAS_Detail()].
#' @param strPath `character` Directory to write into. Created if absent.
#' @param strFormat `character` `"csv"` or `"parquet"`.
#'
#' @return `character` Paths written, invisibly.
#'
#' @examples
#' \dontrun{
#' Write_CTAS_Detail(lDetail, tempdir())
#' }
#'
#' @export
Write_CTAS_Detail <- function(lDetail, strPath, strFormat = "csv") {
  strFormat <- rlang::arg_match(strFormat, c("csv", "parquet"))

  vRequired <- c("Results", "Input", "Untransformed")
  if (!is.list(lDetail) || is.data.frame(lDetail) ||
    length(setdiff(vRequired, names(lDetail))) > 0) {
    cli::cli_abort(c(
      "{.arg lDetail} must be a list with {.val {vRequired}}.",
      "i" = "Build it with {.fn Combine_CTAS_Detail}."
    ))
  }

  if (!rlang::is_character(strPath) || length(strPath) != 1) {
    cli::cli_abort("{.arg strPath} must be a single directory path.")
  }

  if (strFormat == "parquet") {
    rlang::check_installed("arrow", "to write the CTAS detail object as parquet.")
  }

  dir.create(strPath, recursive = TRUE, showWarnings = FALSE)

  lWrite <- list(
    results = lDetail$Results,
    input = lDetail$Input,
    untransformed = lDetail$Untransformed
  )

  # An empty untransformed frame is normal - only some `Input_*()` functions
  # record original values - and the dashboard treats the file as optional, so
  # write nothing rather than an empty file it would have to special-case.
  lWrite <- lWrite[vapply(lWrite, nrow, numeric(1)) > 0]

  vPaths <- vapply(names(lWrite), function(strName) {
    strFile <- file.path(strPath, paste0(strName, ".", strFormat))
    if (strFormat == "csv") {
      utils::write.csv(lWrite[[strName]], strFile, row.names = FALSE)
    } else {
      arrow::write_parquet(lWrite[[strName]], strFile)
    }
    strFile
  }, character(1))

  invisible(unname(vPaths))
}
