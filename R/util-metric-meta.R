#' Look up parameter_name for each parameter_id from a stacked input frame
#'
#' @keywords internal
LookupParameterName <- function(vParamId, dfInput) {
  if (is.null(dfInput) ||
    !all(c("parameter_id", "parameter_name") %in% names(dfInput))) {
    return(rep(NA_character_, length(vParamId)))
  }
  dfLookup <- dplyr::distinct(
    dfInput[, c("parameter_id", "parameter_name"), drop = FALSE]
  )
  dfLookup <- dfLookup[!duplicated(dfLookup$parameter_id), , drop = FALSE]
  as.character(
    dfLookup$parameter_name[match(vParamId, dfLookup$parameter_id)]
  )
}

# Columns follow the metric YAML meta block order so the audit table scans
# left-to-right the same way sponsors read the YAMLs.
vMetricParamCols <- c(
  "FeatureAutocorr", "FeatureAverage", "FeatureSD", "FeatureRange",
  "FeatureUniqueValueCountRelative", "FeatureOwnSiteSimilScore",
  "FeatureLOF",
  "MinTimepoints", "MinSubjects", "MaxShareMissing",
  "ScoringMethod", "PadjustMethod", "Seed"
)

#' Build one row per metric family from the metric workflow meta blocks
#'
#' @keywords internal
MetricParamsFrame <- function(vType, lMetricWorkflows) {
  lRows <- lapply(vType, function(strType) {
    lMeta <- FindMetricMeta(strType, lMetricWorkflows)
    vapply(
      vMetricParamCols,
      function(strCol) {
        val <- lMeta[[strCol]]
        if (is.null(val)) NA_character_ else as.character(val)
      },
      character(1)
    )
  })
  dfParams <- as.data.frame(
    do.call(rbind, lRows),
    stringsAsFactors = FALSE
  )
  names(dfParams) <- vMetricParamCols
  dfParams
}

#' Find the meta block whose `ID` matches a `parameter_category_3` value
#'
#' @keywords internal
FindMetricMeta <- function(strType, lMetricWorkflows) {
  if (is.null(lMetricWorkflows) || length(lMetricWorkflows) == 0L) {
    return(list())
  }
  for (lWorkflow in lMetricWorkflows) {
    if (identical(as.character(lWorkflow$meta$ID), strType)) {
      return(lWorkflow$meta)
    }
  }
  list()
}
