# Unit tests for MakeMetric_CTAS() and Prune_Metrics().

MakeResultsFixture <- function(bMultiFamily = FALSE) {
  df <- data.frame(
    parameter_category_2 = c("AST", "ALT", "AST"),
    parameter_category_3 = c("range_normalized", "range_normalized",
                             "ratio_missing"),
    parameter_id = c("RANGE_AST", "RANGE_ALT", "MISS_AST"),
    parameter_category_1 = "Labs",
    stringsAsFactors = FALSE
  )
  if (!bMultiFamily) {
    # Drop the second (ratio_missing) family so only range_normalized survives.
    df <- df[df$parameter_category_3 == "range_normalized", , drop = FALSE]
  }
  df
}

MakeInputFixture <- function() {
  data.frame(
    parameter_id = c("RANGE_AST", "RANGE_ALT", "MISS_AST"),
    parameter_name = c("Aspartate Aminotransferase",
                       "Alanine Aminotransferase",
                       "Aspartate Aminotransferase"),
    stringsAsFactors = FALSE
  )
}

MakeMetricWorkflowsFixture <- function() {
  list(
    range_normalized = list(meta = list(
      ID = "range_normalized",
      FeatureAutocorr = TRUE, FeatureAverage = TRUE, FeatureSD = TRUE,
      FeatureRange = TRUE, FeatureUniqueValueCountRelative = TRUE,
      FeatureOwnSiteSimilScore = FALSE, FeatureLOF = FALSE,
      MinTimepoints = 1, MinSubjects = 25, MaxShareMissing = 0.3,
      ScoringMethod = "ks", PadjustMethod = "fdr", Seed = 20260813
    )),
    ratio_missing = list(meta = list(
      ID = "ratio_missing",
      FeatureAutocorr = FALSE, FeatureAverage = TRUE, FeatureSD = TRUE,
      FeatureRange = FALSE, FeatureUniqueValueCountRelative = FALSE,
      FeatureOwnSiteSimilScore = FALSE, FeatureLOF = FALSE,
      MinTimepoints = 1, MinSubjects = 25, MaxShareMissing = 0.3,
      ScoringMethod = "ks", PadjustMethod = "fdr", Seed = 20260813
    ))
  )
}

test_that("MakeMetric_CTAS: one row per (field, metric_type) pair with unique MetricID", {
  dfMetrics <- MakeMetric_CTAS(
    MakeResultsFixture(bMultiFamily = TRUE),
    MakeMetricWorkflowsFixture()
  )

  # AST appears in two metric families -> two rows, distinct MetricIDs.
  expect_equal(nrow(dfMetrics), 3)
  expect_setequal(
    dfMetrics$MetricID,
    c("ctas_range_normalized_AST", "ctas_range_normalized_ALT",
      "ctas_ratio_missing_AST")
  )
  expect_equal(anyDuplicated(dfMetrics$MetricID), 0L)
  expect_setequal(unique(dfMetrics$parameter_category_3),
                  c("range_normalized", "ratio_missing"))
})

test_that("MakeMetric_CTAS: emits required gsm-shaped columns + audit extras", {
  dfMetrics <- MakeMetric_CTAS(
    MakeResultsFixture(),
    MakeMetricWorkflowsFixture()
  )

  vGsmCols <- c("MetricID", "Abbreviation", "Metric", "Score",
                "Threshold", "GroupLevel", "AnalysisType", "Model")
  expect_true(all(vGsmCols %in% names(dfMetrics)))
  expect_false(any(c("Numerator", "Denominator") %in% names(dfMetrics)))
  expect_setequal(unique(dfMetrics$GroupLevel), "Site")
  expect_setequal(unique(dfMetrics$AnalysisType), "CTAS")
  vIds <- c("parameter_id", "parameter_name", "parameter_category_1",
            "parameter_category_2", "parameter_category_3")
  expect_true(all(vIds %in% names(dfMetrics)))
})

test_that("MakeMetric_CTAS: parameter_id and parameter_category_1 are carried through", {
  dfMetrics <- MakeMetric_CTAS(
    MakeResultsFixture(bMultiFamily = TRUE),
    MakeMetricWorkflowsFixture()
  )
  dfAstRange <- dfMetrics[dfMetrics$MetricID == "ctas_range_normalized_AST", ]
  expect_equal(dfAstRange$parameter_id, "RANGE_AST")
  expect_equal(dfAstRange$parameter_category_1, "Labs")
  dfAstMiss <- dfMetrics[dfMetrics$MetricID == "ctas_ratio_missing_AST", ]
  expect_equal(dfAstMiss$parameter_id, "MISS_AST")
})

test_that("MakeMetric_CTAS: parameter_name is looked up from dfInput", {
  dfMetrics <- MakeMetric_CTAS(
    MakeResultsFixture(bMultiFamily = TRUE),
    MakeMetricWorkflowsFixture(),
    dfInput = MakeInputFixture()
  )
  dfAstRange <- dfMetrics[dfMetrics$MetricID == "ctas_range_normalized_AST", ]
  expect_equal(dfAstRange$parameter_name, "Aspartate Aminotransferase")
  dfAlt <- dfMetrics[dfMetrics$MetricID == "ctas_range_normalized_ALT", ]
  expect_equal(dfAlt$parameter_name, "Alanine Aminotransferase")
})

test_that("MakeMetric_CTAS: parameter_name is NA when dfInput is not passed", {
  dfMetrics <- MakeMetric_CTAS(
    MakeResultsFixture(),
    MakeMetricWorkflowsFixture()
  )
  expect_true(all(is.na(dfMetrics$parameter_name)))
})

test_that("MakeMetric_CTAS: Abbreviation is parameter_category_2", {
  dfMetrics <- MakeMetric_CTAS(
    MakeResultsFixture(),
    MakeMetricWorkflowsFixture()
  )
  expect_setequal(dfMetrics$Abbreviation, c("AST", "ALT"))
})

test_that("MakeMetric_CTAS: Threshold serialises verbatim as comma-sep", {
  dfMetrics <- MakeMetric_CTAS(
    MakeResultsFixture(),
    MakeMetricWorkflowsFixture(),
    vThreshold = c(0.842, 2.326)
  )
  expect_setequal(unique(dfMetrics$Threshold), "0.842,2.326")
})

test_that("MakeMetric_CTAS: CTAS parameter columns come from the matching metric YAML", {
  dfMetrics <- MakeMetric_CTAS(
    MakeResultsFixture(bMultiFamily = TRUE),
    MakeMetricWorkflowsFixture()
  )

  vParamCols <- c(
    "FeatureAutocorr", "FeatureAverage", "FeatureSD", "FeatureRange",
    "FeatureUniqueValueCountRelative", "FeatureOwnSiteSimilScore",
    "FeatureLOF",
    "MinTimepoints", "MinSubjects", "MaxShareMissing",
    "ScoringMethod", "PadjustMethod", "Seed"
  )
  expect_true(all(vParamCols %in% names(dfMetrics)))

  # range_normalized enables autocorr; ratio_missing disables it.
  dfRange <- dfMetrics[dfMetrics$parameter_category_3 == "range_normalized", ]
  dfMissing <- dfMetrics[dfMetrics$parameter_category_3 == "ratio_missing", ]
  expect_setequal(unique(dfRange$FeatureAutocorr), "TRUE")
  expect_setequal(unique(dfMissing$FeatureAutocorr), "FALSE")

  # Scalars are stringified verbatim so the audit table can round-trip via parquet/csv.
  expect_setequal(unique(dfRange$MinSubjects), "25")
  expect_setequal(unique(dfRange$ScoringMethod), "ks")
})

test_that("MakeMetric_CTAS: parameter columns are NA when no matching workflow is passed", {
  dfMetrics <- MakeMetric_CTAS(
    MakeResultsFixture(),
    lMetricWorkflows = NULL
  )
  vParamCols <- c(
    "FeatureAutocorr", "FeatureAverage", "MinTimepoints", "Seed"
  )
  expect_true(all(is.na(dfMetrics[, vParamCols])))
})

test_that("Prune_Metrics: collapses audit to field-level MetricIDs matching dfSummary", {
  dfMetrics <- MakeMetric_CTAS(
    MakeResultsFixture(bMultiFamily = TRUE),
    MakeMetricWorkflowsFixture()
  )
  dfSummary <- data.frame(
    MetricID = "ctas_AST",
    stringsAsFactors = FALSE
  )
  dfPruned <- Prune_Metrics(dfMetrics, dfSummary)

  expect_equal(nrow(dfPruned), 1)
  expect_equal(dfPruned$MetricID, "ctas_AST")
  expect_equal(dfPruned$parameter_category_2, "AST")
  # Column order preserved from the audit table.
  expect_identical(names(dfPruned), names(dfMetrics))
})

test_that("Prune_Metrics: empty summary yields empty frame with same columns", {
  dfMetrics <- MakeMetric_CTAS(
    MakeResultsFixture(),
    MakeMetricWorkflowsFixture()
  )
  dfPruned <- Prune_Metrics(
    dfMetrics,
    data.frame(MetricID = character(0), stringsAsFactors = FALSE)
  )

  expect_equal(nrow(dfPruned), 0)
  expect_identical(names(dfPruned), names(dfMetrics))
})
