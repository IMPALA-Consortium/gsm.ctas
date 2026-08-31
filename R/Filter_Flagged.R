#' Drop MetricIDs that never triggered a flag
#'
#' Removes every row whose `MetricID` group has no row with
#' `Flag >= iMinFlag`, so the downstream KRI report only lists fields where
#' at least one site was flagged. Set `iMinFlag = 0` (or `NULL`) to disable.
#'
#' @param dfFlagged `data.frame` Output of [Flag_CTAS()]. Must contain
#'   `MetricID` and `Flag`.
#' @param iMinFlag `integer` Minimum flag value that a `MetricID` group must
#'   reach for its rows to be kept. Default `1L` (drop metrics that stayed
#'   green everywhere). Use `0` or `NULL` to keep every row.
#'
#' @return `data.frame` `dfFlagged` filtered to `MetricID` groups whose
#'   maximum non-`NA` `Flag` is at least `iMinFlag`, row order preserved.
#'
#' @examples
#' dfFlagged <- data.frame(
#'   MetricID = c("ctas_AST", "ctas_AST", "ctas_ALT", "ctas_ALT"),
#'   GroupID = c("101", "102", "101", "102"),
#'   Score = c(0.1, 3.0, 0.2, 0.3),
#'   Flag = c(0, 2, 0, 0)
#' )
#' Filter_Flagged(dfFlagged)
#'
#' @export
Filter_Flagged <- function(dfFlagged, iMinFlag = 1L) {
  if (!is.data.frame(dfFlagged)) {
    cli::cli_abort("{.arg dfFlagged} must be a data.frame.")
  }
  if (is.null(iMinFlag) || (is.numeric(iMinFlag) && iMinFlag <= 0)) {
    return(dfFlagged)
  }
  if (!is.numeric(iMinFlag) || length(iMinFlag) != 1) {
    cli::cli_abort("{.arg iMinFlag} must be a single number or NULL.")
  }
  AssertColumns(dfFlagged, c("MetricID", "Flag"), "dfFlagged")
  if (nrow(dfFlagged) == 0) {
    return(dfFlagged)
  }

  vMaxByMetric <- tapply(
    dfFlagged$Flag, dfFlagged$MetricID,
    function(v) suppressWarnings(max(v, na.rm = TRUE))
  )
  vKeep <- names(vMaxByMetric)[
    is.finite(vMaxByMetric) & vMaxByMetric >= iMinFlag
  ]
  dfFlagged[dfFlagged$MetricID %in% vKeep, , drop = FALSE]
}
