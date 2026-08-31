# Unit tests for Make_KRI_Metrics().

MakeSummaryFixture <- function(bByFeature = FALSE) {
  df <- data.frame(
    MetricID = c("ctas_AST", "ctas_ALT"),
    GroupID = c("101", "101"),
    Score = c(1.0, 2.0),
    parameter_category_2 = c("AST", "ALT"),
    stringsAsFactors = FALSE
  )
  if (bByFeature) {
    df$MetricID <- c("ctas_AST_average", "ctas_ALT_sd")
    df$feature <- c("average", "sd")
  }
  df
}

test_that("Make_KRI_Metrics: one row per unique MetricID", {
  dfMetrics <- Make_KRI_Metrics(MakeSummaryFixture())

  expect_setequal(dfMetrics$MetricID, c("ctas_AST", "ctas_ALT"))
  expect_equal(nrow(dfMetrics), 2)
})

test_that("Make_KRI_Metrics: emits required gsm KRI columns", {
  dfMetrics <- Make_KRI_Metrics(MakeSummaryFixture())

  vRequired <- c("MetricID", "Abbreviation", "Metric",
                 "Numerator", "Denominator", "Score",
                 "Threshold", "GroupLevel", "AnalysisType", "Model")
  expect_true(all(vRequired %in% names(dfMetrics)))
  expect_setequal(unique(dfMetrics$GroupLevel), "Site")
  expect_setequal(unique(dfMetrics$AnalysisType), "CTAS")
})

test_that("Make_KRI_Metrics: Abbreviation is parameter_category_2 (drives site-overview column header)", {
  dfMetrics <- Make_KRI_Metrics(MakeSummaryFixture())
  expect_setequal(dfMetrics$Abbreviation, c("AST", "ALT"))
  expect_false(any(is.na(dfMetrics$Abbreviation) |
                     dfMetrics$Abbreviation == ""))

  dfMetricsFeat <- Make_KRI_Metrics(MakeSummaryFixture(bByFeature = TRUE))
  expect_true(any(grepl("\\(average\\)", dfMetricsFeat$Abbreviation)))
})

test_that("Make_KRI_Metrics: Threshold serialises verbatim as comma-sep", {
  dfMetrics <- Make_KRI_Metrics(MakeSummaryFixture(),
                                vThreshold = c(0.842, 2.326))
  expect_setequal(unique(dfMetrics$Threshold), "0.842,2.326")
})

test_that("Make_KRI_Metrics: labels include feature when present", {
  dfMetrics <- Make_KRI_Metrics(MakeSummaryFixture(bByFeature = TRUE))
  expect_true(any(grepl("\\(average\\)", dfMetrics$Metric)))
})
