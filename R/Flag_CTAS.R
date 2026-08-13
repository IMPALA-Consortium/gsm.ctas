#' Flag aggregated CTAS scores
#'
#' Thin wrapper around [gsm.core::Flag()] that fixes the flagging to be
#' one-sided. CTAS reports an unsigned -log10(p): it says "this site differs
#' from the others", not in which direction. Signed flags would therefore be
#' fabricated, so only `0` / `1` / `2` are emitted and no negative flag is ever
#' produced in v1.
#'
#' Groups with `Score = NA` (no evaluated timeseries for the feature) keep
#' `Flag = NA`; they are shown as not evaluated rather than as not flagged.
#'
#' @param dfAnalyzed `data.frame` Result of [Summarize_CTAS()].
#' @param vThreshold `numeric` Ascending thresholds on the `Score` scale.
#'   Defaults to `c(0.842, 2.326)`, drawn from experience.
#' @param strColumn `character` Column to flag on.
#'
#' @return `dfAnalyzed` with an added `Flag` column, sorted by flag severity.
#'
#' @examples
#' dfAnalyzed <- data.frame(
#'   GroupID = c("001", "002", "003"),
#'   GroupLevel = "Site",
#'   Numerator = c(1, 0, 0),
#'   Denominator = c(2, 2, 0),
#'   Metric = c(0.5, 0, NA),
#'   Score = c(3.1, 0.2, NA)
#' )
#' Flag_CTAS(dfAnalyzed)
#'
#' @export
Flag_CTAS <- function(dfAnalyzed,
                      vThreshold = c(0.842, 2.326),
                      strColumn = "Score") {
  if (!is.data.frame(dfAnalyzed)) {
    cli::cli_abort("{.arg dfAnalyzed} must be a {.cls data.frame}.")
  }
  if (!is.numeric(vThreshold) || length(vThreshold) != 2) {
    cli::cli_abort(c(
      "{.arg vThreshold} must be two numbers.",
      "i" = "CTAS flagging is one-sided, so exactly two cut points are used."
    ))
  }
  if (is.unsorted(vThreshold)) {
    cli::cli_abort("{.arg vThreshold} must be in ascending order.")
  }
  if (!strColumn %in% names(dfAnalyzed)) {
    cli::cli_abort("{.arg strColumn} ({strColumn}) not found in {.arg dfAnalyzed}.")
  }

  rlang::check_installed("gsm.core", "to flag CTAS results.")

  dfFlagged <- gsm.core::Flag(
    dfAnalyzed = dfAnalyzed,
    strColumn = strColumn,
    vThreshold = vThreshold,
    vFlag = c(0, 1, 2),
    vFlagOrder = c(2, 1, 0)
  )

  dfFlagged$Flag[is.na(dfFlagged[[strColumn]])] <- NA_real_

  dfFlagged
}
