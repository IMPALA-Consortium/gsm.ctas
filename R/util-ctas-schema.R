#' Empty untransformed detail frame
#'
#' @return `data.frame` with zero rows and the untransformed detail schema.
#'
#' @keywords internal
EmptyCTASUntransformed <- function() {
  data.frame(
    subject_id = character(0),
    parameter_category_2 = character(0),
    timepoint_1_name = character(0),
    original_value = numeric(0),
    lower = numeric(0),
    upper = numeric(0),
    original_category = character(0),
    stringsAsFactors = FALSE
  )
}

#' Empty CTAS results frame
#'
#' @param bStudy `logical` Include the `study` column.
#'
#' @return `data.frame` with zero rows and the [Analyze_CTAS()] results schema.
#'
#' @keywords internal
EmptyCTASResults <- function(bStudy = TRUE) {
  df <- data.frame(
    timeseries_id = character(0),
    site = character(0),
    country = character(0),
    region = character(0),
    feature = character(0),
    pvalue_kstest_logp = numeric(0),
    kstest_statistic = numeric(0),
    fdr_corrected_pvalue_logp = numeric(0),
    ref_group = character(0),
    subject_count = integer(0),
    study = character(0),
    parameter_id = character(0),
    parameter_category_1 = character(0),
    parameter_category_2 = character(0),
    parameter_category_3 = character(0),
    stringsAsFactors = FALSE
  )
  if (!bStudy) {
    df$study <- NULL
  }
  df
}
