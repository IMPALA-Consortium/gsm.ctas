#' Aggregate CTAS site scores into the gsm `Analysis_Analyzed` contract
#'
#' CTAS returns one score per (timeseries x feature x group), while gsm expects
#' one row per group per metric. `Summarize_CTAS()` filters the shared
#' [Analyze_CTAS()] output to a single feature and collapses it over
#' timeseries.
#'
#' A single CTAS run covers every domain in the study, so `feature` alone does
#' not identify a metric once more than one domain is mapped: "average" spans
#' vital signs, range-normalised labs and lab missingness at the same time.
#' A metric must therefore also say which family of parameters it summarises.
#'
#' There are two ways to do so, and the category pair is preferred:
#'
#' - `strDomain` and `strTransformation` match `parameter_category_1` (e.g.
#'   `"Labs"`) and `parameter_category_3` (e.g. `"ratio_missing"`). These are
#'   the structured fields the `Input_*()` functions set, recovered by
#'   [Combine_CTAS_Scores()]. **Both** are needed to identify a family:
#'   `parameter_category_3` is `"numeric"` for every plain numeric domain, so
#'   it would select vital signs and ECG together.
#' - `strParameterPattern` matches a regular expression against `parameter_id`.
#'   This works without the category columns, but re-derives from a string what
#'   the categories already state, and is easy to get subtly wrong - `"^LB_"`
#'   selects both lab families where `"^LB_MISS_"` selects one.
#'
#' Groups with no evaluated timeseries for the feature are retained with
#' `Denominator = 0`, `Metric = NA` and `Score = NA`, so that the report does
#' not silently drop them. Supply `vGroupIDs` to complete the grid against a
#' known group list; otherwise only groups present in `dfSiteScores` appear.
#'
#' `Denominator` counts the timeseries evaluated for the feature, not
#' participants. Sites are normally assessed on the same timeseries, so the
#' denominator is usually constant across sites within a metric, and varies only
#' where a site contributes no data at all for a parameter. It differs *between*
#' metrics, because CTAS autogenerates one timeseries per timepoint combination
#' and those differ by domain. It is a coverage denominator, not an exposure
#' one, and should not be read as site size.
#'
#' The default thresholds `2.326` / `0.842` are drawn from experience rather
#' than derived. They are one-sided normal z-quantiles (99% / 80%) applied to a
#' -log10(p) scale, where they correspond to p = 0.0047 and p = 0.144. Override
#' them from the workflow YAML `meta` block where a different convention is
#' wanted.
#'
#' @param dfSiteScores `data.frame` The `site_scores` element of
#'   [Analyze_CTAS()], normally via [Combine_CTAS_Scores()].
#' @param strFeature `character` Single CTAS feature to summarise, e.g.
#'   `"average"`.
#' @param strGroupLevel `character` gsm group level, `"Site"` or `"Country"`.
#' @param strDomain `character` Optional `parameter_category_1` to keep, e.g.
#'   `"Labs"`. Must be given together with `strTransformation`.
#' @param strTransformation `character` Optional `parameter_category_3` to keep,
#'   e.g. `"ratio_missing"`. Must be given together with `strDomain`.
#' @param strParameterPattern `character` Optional regular expression matched
#'   against `parameter_id`, as an alternative to the category pair for inputs
#'   that lack the category columns.
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
#'   parameter_id = c("VS_SYSBP", "LB_NORM_ALB", "VS_SYSBP"),
#'   parameter_category_1 = c("Vital Signs", "Labs", "Vital Signs"),
#'   parameter_category_3 = c("numeric", "range_normalized", "numeric"),
#'   feature = "average",
#'   fdr_corrected_pvalue_logp = c(3.1, 0.5, 1.0)
#' )
#' Summarize_CTAS(
#'   dfSiteScores,
#'   strFeature = "average",
#'   strDomain = "Vital Signs",
#'   strTransformation = "numeric"
#' )
#'
#' @export
Summarize_CTAS <- function(dfSiteScores,
                           strFeature,
                           strGroupLevel = "Site",
                           strDomain = NULL,
                           strTransformation = NULL,
                           strParameterPattern = NULL,
                           vGroupIDs = NULL,
                           dHigh = 2.326,
                           dLow = 0.842) {
  strGroupLevel <- rlang::arg_match(strGroupLevel, c("Site", "Country"))
  strGroupCol <- c(Site = "site", Country = "country")[[strGroupLevel]]

  AssertSiteScores(dfSiteScores, strGroupCol)

  if (!rlang::is_character(strFeature) || length(strFeature) != 1) {
    cli::cli_abort("{.arg strFeature} must be a single string.")
  }

  dfScores <- FilterParameters(
    dfSiteScores,
    strDomain = strDomain,
    strTransformation = strTransformation,
    strParameterPattern = strParameterPattern
  )

  dfTriggered <- dfScores |>
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

#' Restrict CTAS site scores to one family of parameters
#'
#' Filtering is a no-op when no selector is given, so single-domain studies need
#' neither the category columns nor `parameter_id`.
#'
#' The category pair is the intended selector. `strDomain` and
#' `strTransformation` must be supplied together: `parameter_category_3` is
#' `"numeric"` for every plain numeric domain, so on its own it cannot separate
#' vital signs from ECG, and `parameter_category_1` is `"Labs"` for both lab
#' views. Neither field identifies a family alone. `strParameterPattern` remains
#' available for scores that lack the categories.
#'
#' A selector that matches nothing is an error rather than an empty result:
#' silently summarising zero timeseries would present every site as unevaluated,
#' which is indistinguishable from a genuinely empty domain.
#'
#' @param dfSiteScores `data.frame` CTAS site scores.
#' @param strDomain `character` `parameter_category_1` to keep, or `NULL`.
#' @param strTransformation `character` `parameter_category_3` to keep, or
#'   `NULL`.
#' @param strParameterPattern `character` Regular expression matched against
#'   `parameter_id`, or `NULL`.
#'
#' @return `data.frame` A filtered copy of `dfSiteScores`.
#'
#' @keywords internal
FilterParameters <- function(dfSiteScores,
                             strDomain = NULL,
                             strTransformation = NULL,
                             strParameterPattern = NULL) {
  bCategory <- !is.null(strDomain) || !is.null(strTransformation)

  if (bCategory && !is.null(strParameterPattern)) {
    cli::cli_abort(c(
      "Give either the category pair or {.arg strParameterPattern}, not both.",
      "i" = "They are alternative ways to select the same thing."
    ))
  }

  if (bCategory) {
    return(FilterByCategory(dfSiteScores, strDomain, strTransformation))
  }

  if (is.null(strParameterPattern)) {
    return(dfSiteScores)
  }

  FilterByPattern(dfSiteScores, strParameterPattern)
}

#' Filter site scores on the CTAS parameter categories
#'
#' @inheritParams FilterParameters
#'
#' @return `data.frame` A filtered copy of `dfSiteScores`.
#'
#' @keywords internal
FilterByCategory <- function(dfSiteScores, strDomain, strTransformation) {
  # Requiring both is a guard, not pedantry: `parameter_category_3 =
  # "ratio_missing"` alone would silently widen to every domain that ever gains
  # a missingness view, and `"numeric"` alone to every numeric domain.
  if (is.null(strDomain) || is.null(strTransformation)) {
    cli::cli_abort(c(
      "{.arg strDomain} and {.arg strTransformation} must be given together.",
      "i" = "Neither identifies a parameter family on its own."
    ))
  }

  AssertScalarString(strDomain, "strDomain")
  AssertScalarString(strTransformation, "strTransformation")

  vCategories <- c("parameter_category_1", "parameter_category_3")
  vMissing <- setdiff(vCategories, names(dfSiteScores))
  if (length(vMissing) > 0) {
    cli::cli_abort(c(
      "{.arg dfSiteScores} is missing {.field {vMissing}}.",
      "i" = "CTAS drops the categories; pass {.arg lInput} to {.fn Combine_CTAS_Scores} to recover them."
    ))
  }

  bKeep <- dfSiteScores$parameter_category_1 == strDomain &
    dfSiteScores$parameter_category_3 == strTransformation

  if (!any(bKeep)) {
    vAvailable <- unique(paste(
      dfSiteScores$parameter_category_1, dfSiteScores$parameter_category_3,
      sep = " / "
    ))
    cli::cli_abort(c(
      "No parameter matches {.val {strDomain}} / {.val {strTransformation}}.",
      "i" = "Available: {.val {vAvailable}}."
    ))
  }

  dfSiteScores[bKeep, , drop = FALSE]
}

#' Filter site scores by a `parameter_id` pattern
#'
#' @inheritParams FilterParameters
#'
#' @return `data.frame` A filtered copy of `dfSiteScores`.
#'
#' @keywords internal
FilterByPattern <- function(dfSiteScores, strParameterPattern) {
  AssertScalarString(strParameterPattern, "strParameterPattern")

  if (!"parameter_id" %in% names(dfSiteScores)) {
    cli::cli_abort(c(
      "{.arg dfSiteScores} needs a {.field parameter_id} column to filter on {.arg strParameterPattern}.",
      "i" = "It lives on the CTAS {.field timeseries} frame; {.fn Combine_CTAS_Scores} joins it on."
    ))
  }

  bKeep <- grepl(strParameterPattern, as.character(dfSiteScores$parameter_id))

  if (!any(bKeep)) {
    cli::cli_abort(c(
      "No parameter in {.arg dfSiteScores} matches {.val {strParameterPattern}}.",
      "i" = "Available: {.val {unique(as.character(dfSiteScores$parameter_id))}}."
    ))
  }

  dfSiteScores[bKeep, , drop = FALSE]
}

#' Assert that a value is a single string
#'
#' @param x Value to check.
#' @param strName `character` Argument name for the message.
#'
#' @return `NULL`, invisibly. Aborts when `x` is not a scalar string.
#'
#' @keywords internal
AssertScalarString <- function(x, strName) {
  if (!rlang::is_character(x) || length(x) != 1) {
    cli::cli_abort("{.arg {strName}} must be a single string or {.code NULL}.")
  }
  invisible(NULL)
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
