#' Aggregate CTAS site scores into the gsm `Analysis_Analyzed` contract
#'
#' CTAS returns one score per (timeseries x feature x group). `Summarize_CTAS()`
#' collapses that grid over timeseries, producing one row per group per feature
#' (and per study, if `strStudyCol` is present). A single metric YAML therefore
#' emits every CTAS feature at once, without needing to filter the shared
#' `site_scores` frame by domain or by parameter pattern.
#'
#' Domain selection is intentionally removed: the mapping layer already
#' publishes standardised, transformation-specific input frames (`Mapped_Numeric`,
#' `Mapped_Range`), and each metric YAML runs its own CTAS pipeline on the
#' input it names, so a metric's `dfSiteScores` already contains only the
#' parameters that metric owns.
#'
#' Groups with no evaluated timeseries for a feature are retained with
#' `Denominator = 0`, `Metric = NA` and `Score = NA`, so that the report does
#' not silently drop them. Supply `vGroupIDs` to complete the grid against a
#' known group list; otherwise only groups present in `dfSiteScores` appear.
#' When `strStudyCol` is present, the grid is completed per study.
#'
#' `Denominator` counts the timeseries evaluated for the feature, not
#' participants. It is a coverage denominator, not an exposure one, and should
#' not be read as site size.
#'
#' The default thresholds `2.326` / `0.842` are drawn from experience: one-sided
#' normal z-quantiles (99% / 80%) applied to a -log10(p) scale, where they
#' correspond to p = 0.0047 and p = 0.144. Override from the workflow YAML
#' `meta` block where a different convention is wanted.
#'
#' @param dfSiteScores `data.frame` The `site_scores` element of
#'   [Analyze_CTAS()], normally via [Combine_CTAS_Scores()].
#' @param vFeatures `character` CTAS features to summarise. `NULL` (default)
#'   summarises every feature present in `dfSiteScores`.
#' @param strGroupLevel `character` gsm group level, `"Site"` or `"Country"`.
#' @param strStudyCol `character` Study identifier column expected on
#'   `dfSiteScores`. `NULL` disables the per-study grid.
#' @param vGroupIDs `character` Optional complete vector of group IDs.
#' @param dHigh `numeric` Score at or above which a timeseries triggers
#'   "Further Evaluation".
#' @param dLow `numeric` Score at or above which a timeseries is put on the
#'   "Watch List".
#'
#' @return `data.frame` with `GroupID`, `GroupLevel`, `Feature`, `Numerator`,
#'   `Denominator`, `Metric` and `Score`, plus the study column when
#'   `strStudyCol` is set.
#'
#' @examples
#' dfSiteScores <- data.frame(
#'   timeseries_id = c("ts1", "ts2", "ts1"),
#'   site = c("001", "001", "002"),
#'   country = "USA",
#'   parameter_id = c("NUM_SYSBP", "NUM_DIABP", "NUM_SYSBP"),
#'   feature = c("average", "sd", "average"),
#'   fdr_corrected_pvalue_logp = c(3.1, 0.5, 1.0)
#' )
#' Summarize_CTAS(dfSiteScores, strStudyCol = NULL)
#'
#' @export
Summarize_CTAS <- function(dfSiteScores,
                           vFeatures = NULL,
                           strGroupLevel = "Site",
                           strStudyCol = "studyid",
                           vGroupIDs = NULL,
                           dHigh = 2.326,
                           dLow = 0.842) {
  strGroupLevel <- rlang::arg_match(strGroupLevel, c("Site", "Country"))
  strGroupCol <- c(Site = "site", Country = "country")[[strGroupLevel]]

  AssertSiteScores(dfSiteScores, strGroupCol)

  bHasStudy <- !is.null(strStudyCol) && strStudyCol %in% names(dfSiteScores)

  # Retain a reference to the unfiltered scores so groups (and study-group
  # pairs) that only carry other features still appear in the grid with
  # Denominator = 0. Filtering by feature happens on the working copy.
  dfAll <- dfSiteScores

  if (!is.null(vFeatures)) {
    if (!rlang::is_character(vFeatures) || length(vFeatures) == 0) {
      cli::cli_abort("{.arg vFeatures} must be a non-empty character vector or {.code NULL}.")
    }
    dfSiteScores <- dfSiteScores[dfSiteScores$feature %in% vFeatures, , drop = FALSE]
  }

  dfTriggered <- AddCTASTrigger(dfSiteScores, dHigh = dHigh, dLow = dLow)

  vFeaturesOut <- if (is.null(vFeatures)) {
    sort(unique(as.character(dfAll$feature)))
  } else {
    sort(intersect(as.character(vFeatures), unique(as.character(dfAll$feature))))
  }

  # An explicit selection that intersects nothing is a legitimate "no metric
  # to publish" outcome (e.g. the ratio_missing YAML asking for `autocorr` on a
  # ratio series). Return the same-shaped empty frame the join below would.
  if (length(vFeaturesOut) == 0) {
    vCols <- c(
      if (bHasStudy) strStudyCol,
      "GroupID", "GroupLevel", "Feature",
      "Numerator", "Denominator", "Metric", "Score"
    )
    return(dplyr::as_tibble(stats::setNames(
      lapply(vCols, function(x) character(0)), vCols
    )))
  }

  bCustomGroups <- !is.null(vGroupIDs)
  vGroupIDs <- if (bCustomGroups) {
    sort(unique(as.character(vGroupIDs)))
  } else {
    sort(unique(as.character(dfAll[[strGroupCol]])))
  }

  dfGrid <- if (bHasStudy) {
    # Per-study grid: pair each study with the sites that actually belong to
    # it, then cross-join with features. This avoids inventing sites for
    # studies that never ran them, which is exactly the point of splitting
    # CTAS by studyid.
    dfStudyGroups <- if (bCustomGroups) {
      expand.grid(
        studyid = sort(unique(as.character(dfAll[[strStudyCol]]))),
        GroupID = vGroupIDs,
        stringsAsFactors = FALSE,
        KEEP.OUT.ATTRS = FALSE
      )
    } else {
      dfPairs <- unique(dfAll[, c(strStudyCol, strGroupCol), drop = FALSE])
      names(dfPairs) <- c("studyid", "GroupID")
      dfPairs$studyid <- as.character(dfPairs$studyid)
      dfPairs$GroupID <- as.character(dfPairs$GroupID)
      dfPairs
    }
    merge(dfStudyGroups, data.frame(Feature = vFeaturesOut, stringsAsFactors = FALSE))
  } else {
    expand.grid(
      GroupID = vGroupIDs,
      Feature = vFeaturesOut,
      stringsAsFactors = FALSE,
      KEEP.OUT.ATTRS = FALSE
    )
  }

  vGroupBy <- if (bHasStudy) c(strStudyCol, "GroupID", "Feature") else c("GroupID", "Feature")

  dfSummary <- dfTriggered
  dfSummary$GroupID <- as.character(dfSummary[[strGroupCol]])
  dfSummary$Feature <- as.character(dfSummary$feature)
  dfSummary <- dfSummary |>
    dplyr::summarise(
      Numerator = sum(.data$Trigger == "Further Evaluation", na.rm = TRUE),
      Denominator = dplyr::n(),
      Score = SafeMax(.data$fdr_corrected_pvalue_logp),
      .by = dplyr::all_of(vGroupBy)
    )

  # `dfGrid` uses `studyid` as its own column name so the join below matches
  # `strStudyCol` when it holds any other value.
  if (bHasStudy && strStudyCol != "studyid") {
    names(dfGrid)[names(dfGrid) == "studyid"] <- strStudyCol
  }

  dplyr::as_tibble(dfGrid) |>
    dplyr::left_join(dfSummary, by = vGroupBy) |>
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
      dplyr::any_of(strStudyCol),
      "GroupID", "GroupLevel", "Feature",
      "Numerator", "Denominator", "Metric", "Score"
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
