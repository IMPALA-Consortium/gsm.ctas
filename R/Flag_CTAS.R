#' Flag CTAS scores with a gsm-shaped `Flag` column
#'
#' User-facing gsm-style flagging function that mirrors the
#' `gsm.core::Flag()` signature but with unsigned CTAS defaults appropriate
#' for the `-log10(p)` scoring scale. Adds a `Flag` column to `dfAnalyzed`
#' based on left-closed intervals of the score column.
#'
#' CTAS `-log10(p)` is one-sided and non-negative, so the defaults are two
#' ascending thresholds (`0.842`, `2.326` -- 80% and 99% one-sided normal
#' z-quantiles) with three flag levels (`0` = green, `1` = amber,
#' `2` = red). A `Flag = 2` means the site differs from its peers; the
#' unsigned scale carries no directional information.
#'
#' @param dfAnalyzed `data.frame` Aggregated CTAS scores, typically the
#'   output of [Summarize_CTAS()]. Must contain `strColumn`.
#' @param strColumn `character` Column to threshold. Default `"Score"`.
#' @param vThreshold `numeric` Ascending threshold values. Default
#'   `c(0.842, 2.326)`.
#' @param vFlag `numeric` Flag values, one longer than `vThreshold`. Default
#'   `c(0, 1, 2)`.
#' @param vFlagOrder `numeric` Sort order for the returned rows. Must
#'   contain the same values as `vFlag`. Default `c(2, 1, 0)` (red first).
#'   Pass `NULL` to leave rows unsorted.
#' @param nAccrualThreshold `numeric` Minimum accrual value below which
#'   `Score` and `Flag` are set to `NA`. Default `NULL` (no accrual filter).
#' @param strAccrualMetric `character` Column to compare against
#'   `nAccrualThreshold`. One of `"Numerator"`, `"Denominator"`,
#'   `"Difference"` (Denominator - Numerator). Required when
#'   `nAccrualThreshold` is set.
#'
#' @return `data.frame` `dfAnalyzed` with an added `Flag` column, optionally
#'   sorted by `vFlagOrder`.
#'
#' @seealso `gsm.core::Flag()` for the signed gsm-core variant.
#'
#' @examples
#' dfSummary <- data.frame(
#'   MetricID = "ctas_AST",
#'   GroupID = c("101", "102", "103"),
#'   Score = c(0.1, 1.2, 3.0),
#'   Numerator = c(2, 4, 3),
#'   Denominator = c(2, 4, 3)
#' )
#' Flag_CTAS(dfSummary)
#'
#' @export
Flag_CTAS <- function(dfAnalyzed,
                      strColumn = "Score",
                      vThreshold = c(0.842, 2.326),
                      vFlag = c(0, 1, 2),
                      vFlagOrder = c(2, 1, 0),
                      nAccrualThreshold = NULL,
                      strAccrualMetric = NULL) {
  if (!is.data.frame(dfAnalyzed)) {
    cli::cli_abort("{.arg dfAnalyzed} must be a data.frame.")
  }
  if (!is.character(strColumn) || length(strColumn) != 1) {
    cli::cli_abort("{.arg strColumn} must be a single column name.")
  }
  if (!strColumn %in% names(dfAnalyzed)) {
    cli::cli_abort(
      "{.arg strColumn} {.val {strColumn}} not found in {.arg dfAnalyzed}."
    )
  }
  if (!is.numeric(vThreshold) || length(vThreshold) < 1) {
    cli::cli_abort("{.arg vThreshold} must be a non-empty numeric vector.")
  }
  if (is.unsorted(vThreshold, strictly = TRUE)) {
    cli::cli_abort("{.arg vThreshold} must be in strictly ascending order.")
  }
  if (!is.numeric(vFlag) || length(vFlag) != length(vThreshold) + 1) {
    cli::cli_abort(
      "{.arg vFlag} must have {length(vThreshold) + 1} numeric elements."
    )
  }
  if (!is.null(vFlagOrder) &&
    (!is.numeric(vFlagOrder) || !setequal(vFlagOrder, vFlag))) {
    cli::cli_abort(
      "{.arg vFlagOrder} must contain the same values as {.arg vFlag}."
    )
  }
  if (!is.null(nAccrualThreshold)) {
    if (!is.numeric(nAccrualThreshold) || length(nAccrualThreshold) != 1) {
      cli::cli_abort("{.arg nAccrualThreshold} must be a single number.")
    }
    if (is.null(strAccrualMetric) ||
      !strAccrualMetric %in% c("Numerator", "Denominator", "Difference")) {
      cli::cli_abort(
        '{.arg strAccrualMetric} must be one of "Numerator", "Denominator", "Difference".'
      )
    }
    vAccrualCols <- if (strAccrualMetric == "Difference") {
      c("Numerator", "Denominator")
    } else {
      strAccrualMetric
    }
    AssertColumns(dfAnalyzed, vAccrualCols, "dfAnalyzed")
  }

  dfFlagged <- dfAnalyzed

  # Left-closed cut: CTAS `-log10(p)` is non-negative and one-sided.
  vBreaks <- c(-Inf, vThreshold, Inf)
  vIdx <- as.integer(cut(
    dfFlagged[[strColumn]],
    breaks = vBreaks,
    right = FALSE,
    include.lowest = TRUE
  ))
  dfFlagged$Flag <- vFlag[vIdx]

  if (!is.null(nAccrualThreshold)) {
    vAcc <- switch(strAccrualMetric,
      Numerator = dfFlagged$Numerator,
      Denominator = dfFlagged$Denominator,
      Difference = dfFlagged$Denominator - dfFlagged$Numerator
    )
    vBelow <- !is.na(vAcc) & vAcc < nAccrualThreshold
    if ("Score" %in% names(dfFlagged)) dfFlagged$Score[vBelow] <- NA
    dfFlagged$Flag[vBelow] <- NA
  }

  if (!is.null(vFlagOrder)) {
    dfFlagged <- dfFlagged[order(match(dfFlagged$Flag, vFlagOrder)), ,
      drop = FALSE
    ]
    rownames(dfFlagged) <- NULL
  }

  dfFlagged
}
