#' Aggregate CTAS site scores into the gsm `Analysis_Analyzed` contract
#'
#' CTAS returns one score per (timeseries x feature x group), while gsm expects
#' one row per group per metric. `Summarize_CTAS()` filters the shared
#' [Analyze_CTAS()] output to a single feature and collapses it over
#' timeseries.
#'
#' Groups with no evaluated timeseries for the feature are retained with
#' `Denominator = 0`, `Metric = NA` and `Score = NA`, so that the report does
#' not silently drop them. Supply `vGroupIDs` to complete the grid against a
#' known group list; otherwise only groups present in `dfSiteScores` appear.
#'
#' `Denominator` counts the timeseries evaluated for the feature, not
#' participants. Every site is normally assessed on the same timeseries, so the
#' denominator is usually constant across sites and varies only where a site
#' contributes no data at all for a parameter. It is a coverage denominator, not
#' an exposure one, and should not be read as site size.
#'
#' The default thresholds `2.326` / `0.842` are drawn from experience rather
#' than derived. They are one-sided normal z-quantiles (99% / 80%) applied to a
#' -log10(p) scale, where they correspond to p = 0.0047 and p = 0.144. Override
#' them from the workflow YAML `meta` block where a different convention is
#' wanted.
#'
#' @param dfSiteScores `data.frame` The `site_scores` element of
#'   [Analyze_CTAS()].
#' @param strFeature `character` Single CTAS feature to summarise, e.g.
#'   `"average"`.
#' @param strGroupLevel `character` gsm group level, `"Site"` or `"Country"`.
#' @param vGroupIDs `character` Optional complete vector of group IDs.
#' @param dHigh `numeric` Score at or above which a timeseries triggers
#'   "Further Evaluation".
#' @param dLow `numeric` Score at or above which a timeseries is put on the
#'   "Watch List".
#'
#' @return `data.frame` with `GroupID`, `GroupLevel`, `Numerator`,
#'   `Denominator`, `Metric` and `Score`.
#'
#' @examples
#' dfSiteScores <- data.frame(
#'   timeseries_id = c("ts1", "ts2", "ts1"),
#'   site = c("001", "001", "002"),
#'   country = "USA",
#'   feature = "average",
#'   fdr_corrected_pvalue_logp = c(3.1, 0.5, 1.0)
#' )
#' Summarize_CTAS(dfSiteScores, strFeature = "average")
#'
#' @export
Summarize_CTAS <- function(dfSiteScores,
                           strFeature,
                           strGroupLevel = "Site",
                           vGroupIDs = NULL,
                           dHigh = 2.326,
                           dLow = 0.842) {
  strGroupLevel <- rlang::arg_match(strGroupLevel, c("Site", "Country"))
  strGroupCol <- c(Site = "site", Country = "country")[[strGroupLevel]]

  AssertSiteScores(dfSiteScores, strGroupCol)

  if (!rlang::is_character(strFeature) || length(strFeature) != 1) {
    cli::cli_abort("{.arg strFeature} must be a single string.")
  }

  dfTriggered <- dfSiteScores |>
    dplyr::filter(.data$feature == .env$strFeature) |>
    AddCTASTrigger(dHigh = dHigh, dLow = dLow)

  if (is.null(vGroupIDs)) {
    vGroupIDs <- unique(dfTriggered[[strGroupCol]])
  }
  vGroupIDs <- sort(unique(as.character(vGroupIDs)))

  dfSummary <- dfTriggered |>
    dplyr::mutate(GroupID = as.character(.data[[strGroupCol]])) |>
    dplyr::summarise(
      Numerator = sum(.data$Trigger == "Further Evaluation", na.rm = TRUE),
      Denominator = dplyr::n(),
      Score = SafeMax(.data$fdr_corrected_pvalue_logp),
      .by = "GroupID"
    )

  dplyr::tibble(GroupID = vGroupIDs) |>
    dplyr::left_join(dfSummary, by = "GroupID") |>
    dplyr::mutate(
      GroupLevel = .env$strGroupLevel,
      Numerator = dplyr::coalesce(as.numeric(.data$Numerator), 0),
      Denominator = dplyr::coalesce(as.numeric(.data$Denominator), 0),
      Metric = dplyr::if_else(
        .data$Denominator > 0,
        .data$Numerator / .data$Denominator,
        NA_real_
      )
    ) |>
    dplyr::select(
      "GroupID", "GroupLevel", "Numerator", "Denominator", "Metric", "Score"
    )
}

#' Classify CTAS timeseries scores into trigger categories
#'
#' Classifies each timeseries score against the two trigger cut points.
#'
#' @param dfSiteScores `data.frame` CTAS site scores.
#' @param dHigh `numeric` "Further Evaluation" threshold.
#' @param dLow `numeric` "Watch List" threshold.
#'
#' @return `dfSiteScores` with an added `Trigger` column.
#'
#' @keywords internal
AddCTASTrigger <- function(dfSiteScores, dHigh = 2.326, dLow = 0.842) {
  if (!is.numeric(dHigh) || !is.numeric(dLow) ||
    length(dHigh) != 1 || length(dLow) != 1) {
    cli::cli_abort("{.arg dHigh} and {.arg dLow} must each be a single number.")
  }
  if (dHigh < dLow) {
    cli::cli_abort("{.arg dHigh} ({dHigh}) must not be below {.arg dLow} ({dLow}).")
  }

  dfSiteScores |>
    dplyr::mutate(
      Trigger = dplyr::case_when(
        is.na(.data$fdr_corrected_pvalue_logp) ~ NA_character_,
        .data$fdr_corrected_pvalue_logp >= .env$dHigh ~ "Further Evaluation",
        .data$fdr_corrected_pvalue_logp >= .env$dLow ~ "Watch List",
        .default = "No Action"
      )
    )
}

#' Count timeseries per group for a given trigger category
#'
#' Note that a naive `filter(trigger == trigger)` would compare the column to
#' itself, the argument being shadowed by the column of the same name, and so
#' always evaluate to `TRUE`, counting every timeseries rather than the
#' triggered ones. Here the argument is disambiguated with `.env`.
#'
#' @param dfSiteScores `data.frame` CTAS site scores with a `Trigger` column,
#'   as returned by [AddCTASTrigger()].
#' @param strTrigger `character` Trigger category to count.
#' @param strGroupCol `character` Grouping column.
#'
#' @return `data.frame` with the grouping column and `N`.
#'
#' @keywords internal
CountTriggered <- function(dfSiteScores,
                           strTrigger = "Further Evaluation",
                           strGroupCol = "site") {
  dfSiteScores |>
    dplyr::filter(.data$Trigger == .env$strTrigger) |>
    dplyr::summarise(N = dplyr::n(), .by = dplyr::all_of(strGroupCol))
}

#' Validate CTAS site scores
#'
#' @param dfSiteScores `data.frame` CTAS site scores.
#' @param strGroupCol `character` Required grouping column.
#'
#' @return `NULL`, invisibly. Aborts when the input is unusable.
#'
#' @keywords internal
AssertSiteScores <- function(dfSiteScores, strGroupCol) {
  if (!is.data.frame(dfSiteScores)) {
    cli::cli_abort("{.arg dfSiteScores} must be a {.cls data.frame}.")
  }

  vRequired <- c(strGroupCol, "feature", "fdr_corrected_pvalue_logp")
  vMissing <- setdiff(vRequired, names(dfSiteScores))
  if (length(vMissing) > 0) {
    cli::cli_abort(c(
      "{.arg dfSiteScores} is missing required column{?s}: {.val {vMissing}}.",
      "i" = "Pass the {.field site_scores} element of {.fn Analyze_CTAS}."
    ))
  }

  invisible(NULL)
}

#' Maximum that returns `NA` rather than `-Inf` for an empty vector
#'
#' @param x `numeric` Vector to reduce.
#'
#' @return `numeric` of length 1.
#'
#' @keywords internal
SafeMax <- function(x) {
  x <- x[!is.na(x)]
  if (length(x) == 0) NA_real_ else max(x)
}
