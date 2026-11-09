#' Normalize values by reference range
#'
#' Computes `(vValue - vLow) / (vHigh - vLow)`, so that values inside the
#' reference range fall between 0 and 1, below-range values are negative and
#' above-range values exceed 1. This makes parameters with different units and
#' scales comparable within a single CTAS timeseries frame.
#'
#' Returns `NA_real_` wherever the range is invalid, i.e. either bound is
#' missing or the range width is not strictly positive.
#'
#' @param vValue `numeric` Observed values.
#' @param vLow `numeric` Lower reference bounds.
#' @param vHigh `numeric` Upper reference bounds.
#'
#' @return `numeric` vector of the same length as `vValue`.
#'
#' @keywords internal
Prepare_Normalize <- function(vValue, vLow, vHigh) {
  vWidth <- vHigh - vLow
  bInvalid <- is.na(vWidth) | vWidth <= 0
  vResult <- (vValue - vLow) / vWidth
  vResult[bInvalid] <- NA_real_
  vResult
}

#' Running ratio of missing values over time
#'
#' For each subject and parameter, computes the cumulative proportion of
#' missing values in row order: row `k` of a group receives
#' `sum(is.na(vValue[1:k])) / k`. The result is a timeseries in its own right,
#' allowing CTAS to detect sites whose data completeness deviates over time.
#'
#' Rows are assumed to be supplied in chronological order within each group;
#' the returned vector is aligned to the input row order.
#'
#' @param vValue `numeric` Observed values, possibly containing `NA`.
#' @param vSubjectID `character` Subject identifiers.
#' @param vParameterID `character` Parameter identifiers.
#'
#' @return `numeric` vector of the same length as `vValue`.
#'
#' @keywords internal
Prepare_MissingRatio <- function(vValue, vSubjectID, vParameterID) {
  dfWork <- data.frame(
    Missing = as.numeric(is.na(vValue)),
    subject_id = vSubjectID,
    parameter_id = vParameterID,
    RowIndex = seq_along(vValue),
    stringsAsFactors = FALSE
  )

  dfWork <- dfWork |>
    dplyr::mutate(
      Rank = dplyr::row_number(),
      Ratio = cumsum(.data$Missing) / .data$Rank,
      .by = c("subject_id", "parameter_id")
    )

  dfWork$Ratio[order(dfWork$RowIndex)]
}

#' One-hot encode a categorical variable
#'
#' Expands a categorical vector into a long data frame with one row per
#' observation per observed level, so that each level becomes its own binary
#' CTAS timeseries. `NA` values are dropped rather than encoded as a level.
#'
#' @param vValue `character` Categorical values.
#' @param strPrefix `character` Prefix used to build level labels, typically the
#'   source parameter name.
#'
#' @return `data.frame` with columns `RowIndex` (`integer` row index of the
#'   source observation), `Level` (`character` label of the form
#'   `"{strPrefix}={value}"`) and `Encoded` (`integer`, 1 if the observation
#'   matches the level, else 0).
#'
#' @keywords internal
Prepare_Categorical <- function(vValue, strPrefix = "var") {
  vIndex <- which(!is.na(vValue))

  if (length(vIndex) == 0) {
    return(data.frame(
      RowIndex = integer(0),
      Level = character(0),
      Encoded = integer(0),
      stringsAsFactors = FALSE
    ))
  }

  vLevels <- sort(unique(vValue[vIndex]))

  lRows <- lapply(vLevels, function(strLevel) {
    data.frame(
      RowIndex = vIndex,
      Level = paste0(strPrefix, "=", strLevel),
      Encoded = as.integer(vValue[vIndex] == strLevel),
      stringsAsFactors = FALSE
    )
  })

  do.call(rbind, lRows)
}

#' Recalculate timepoint rank as a positional integer
#'
#' Replaces `timepoint_rank` with a contiguous 1, 2, 3, ... sequence within each
#' `(subject_id, parameter_id)` group, ordered by the incoming numeric
#' `timepoint_rank` (typically `VISITNUM`) with `timepoint_1_name` as a
#' tiebreaker. CTAS requires contiguous ranks, which the source visit numbers no
#' longer provide after filtering or after binding several domains together.
#'
#' @param dfInput `data.frame` Containing at least `subject_id`,
#'   `parameter_id`, `timepoint_1_name` and `timepoint_rank`.
#'
#' @return `data.frame` with `timepoint_rank` recalculated, sorted by group and
#'   rank.
#'
#' @keywords internal
Prepare_TimepointRank <- function(dfInput) {
  vRequired <- c(
    "subject_id", "parameter_id", "timepoint_1_name", "timepoint_rank"
  )
  vMissing <- setdiff(vRequired, names(dfInput))

  if (length(vMissing) > 0) {
    cli::cli_abort(
      "{.arg dfInput} is missing required column{?s}: {.val {vMissing}}."
    )
  }

  dfInput |>
    dplyr::arrange(
      .data$subject_id, .data$parameter_id,
      .data$timepoint_rank, .data$timepoint_1_name
    ) |>
    dplyr::mutate(
      timepoint_rank = dplyr::row_number(),
      .by = c("subject_id", "parameter_id")
    )
}
