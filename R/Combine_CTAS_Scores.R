#' Attach parameter identity and category to CTAS site scores
#'
#' `site_scores` identifies a row by `timeseries_id` and `feature` only, which
#' was sufficient while a study mapped a single domain. Once several domains
#' share one CTAS run - vital signs, range-normalised labs and lab missingness -
#' a feature name no longer identifies a metric, and each metric workflow needs
#' to select its own parameters.
#'
#' Two joins are needed, because CTAS spreads the identifying fields across its
#' inputs and outputs and discards some entirely:
#'
#' - `parameter_id` comes from `lResult$timeseries`.
#' - `parameter_category_1` (the domain, e.g. `"Labs"`) and
#'   `parameter_category_3` (the transformation, e.g. `"ratio_missing"`) come
#'   from `lInput$parameters`. The `Input_*()` functions set these, but
#'   `process_a_study()` does not return them on any of its four elements, so
#'   they can only be recovered from the input.
#'
#' Supplying `lInput` is optional but recommended. Without it, metrics can only
#' select parameters by pattern-matching `parameter_id` strings; with it they
#' can select on the categories directly, which is what those fields are for.
#'
#' This also satisfies the drill-down contract of the `ctasapp` dashboard (`site`, `timeseries_id`, `parameter_id`, `feature`,
#' `fdr_corrected_pvalue_logp`), which plain `site_scores` does not.
#'
#' @param lResult `list` Result of [Analyze_CTAS()].
#' @param lInput `list` Optional result of [Combine_CTAS_Input()], used to
#'   recover the parameter categories CTAS drops.
#'
#' @return `data.frame` `site_scores` with `parameter_id` added, plus
#'   `parameter_category_1` and `parameter_category_3` when `lInput` is given.
#'
#' @examples
#' Combine_CTAS_Scores(list(
#'   site_scores = data.frame(
#'     timeseries_id = "ts1", site = "001", country = "USA",
#'     feature = "average", fdr_corrected_pvalue_logp = 1.2
#'   ),
#'   timeseries = data.frame(timeseries_id = "ts1", parameter_id = "VS_SYSBP")
#' ))
#'
#' @export
Combine_CTAS_Scores <- function(lResult, lInput = NULL) {
  if (!is.list(lResult) || is.data.frame(lResult)) {
    cli::cli_abort("{.arg lResult} must be a list, as returned by {.fn Analyze_CTAS}.")
  }

  vMissing <- setdiff(c("site_scores", "timeseries"), names(lResult))
  if (length(vMissing) > 0) {
    cli::cli_abort(c(
      "{.arg lResult} is missing required element{?s}: {.val {vMissing}}.",
      "i" = "Pass the whole result of {.fn Analyze_CTAS}, not just {.field site_scores}."
    ))
  }

  AssertColumns(lResult$site_scores, "timeseries_id", "lResult$site_scores")
  AssertColumns(
    lResult$timeseries, c("timeseries_id", "parameter_id"), "lResult$timeseries"
  )

  dfScores <- lResult$site_scores |>
    dplyr::left_join(
      dplyr::distinct(
        dplyr::select(lResult$timeseries, "timeseries_id", "parameter_id")
      ),
      by = "timeseries_id"
    )

  # An unmatched timeseries would silently drop out of every parameter-filtered
  # metric, so fail here instead.
  if (any(is.na(dfScores$parameter_id))) {
    cli::cli_abort(
      "{.field timeseries_id} in {.field site_scores} has no match in {.field timeseries}."
    )
  }

  if (!is.null(lInput)) {
    dfScores <- AddParameterCategories(dfScores, lInput)
  }

  as.data.frame(dfScores)
}

#' Recover the parameter categories CTAS discards
#'
#' `process_a_study()` consumes `parameters` but returns none of its category
#' columns, so the only way to label a score with its domain is to join the
#' input back on.
#'
#' @param dfScores `data.frame` Site scores carrying `parameter_id`.
#' @param lInput `list` Result of [Combine_CTAS_Input()].
#'
#' @return `data.frame` `dfScores` with the category columns added.
#'
#' @keywords internal
AddParameterCategories <- function(dfScores, lInput) {
  if (!is.list(lInput) || is.data.frame(lInput) || !"parameters" %in% names(lInput)) {
    cli::cli_abort(c(
      "{.arg lInput} must be a list with a {.field parameters} element.",
      "i" = "Pass the result of {.fn Combine_CTAS_Input}."
    ))
  }

  vCategories <- c("parameter_category_1", "parameter_category_3")
  AssertColumns(
    lInput$parameters, c("parameter_id", vCategories), "lInput$parameters"
  )

  dfParameters <- dplyr::distinct(
    dplyr::select(lInput$parameters, "parameter_id", dplyr::all_of(vCategories))
  )

  # Check before joining rather than counting rows after: a duplicated
  # parameter would otherwise fan the scores out and only surface as a dplyr
  # many-to-many warning.
  if (anyDuplicated(dfParameters$parameter_id) > 0) {
    cli::cli_abort(
      "{.field parameter_id} is not unique in {.arg lInput$parameters}."
    )
  }

  dfJoined <- dplyr::left_join(dfScores, dfParameters, by = "parameter_id")

  if (any(is.na(dfJoined$parameter_category_1))) {
    cli::cli_abort(c(
      "Scored parameter{?s} {.val {unique(dfJoined$parameter_id[is.na(dfJoined$parameter_category_1)])}} are absent from {.arg lInput$parameters}.",
      "i" = "{.arg lResult} and {.arg lInput} must come from the same CTAS run."
    ))
  }

  dfJoined
}
