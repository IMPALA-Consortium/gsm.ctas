# Direct unit tests for MakeCharts() and Visualize_CTAS().
#
# These exercise the branches the end-to-end workflow render in
# test_workflow.R does not reach: absent SnapshotDate column, absent
# strMetricID, dfMetrics dropped when strMetricID is not present, and the
# multi-snapshot timeSeries branch. We inspect the returned widget objects
# with expect_s3_class(..., "htmlwidget") instead of rendering to HTML --
# the full render is covered end-to-end by test_workflow.R.

skip_if_not_installed("gsm.kri")
skip_if_not_installed("gsm.core")

MakeVizFixture <- function(bMultiSnapshot = FALSE) {
  vSites <- c("101", "102", "103")
  df <- data.frame(
    MetricID = "ctas_AST",
    GroupID = vSites,
    GroupLevel = "Site",
    StudyID = "STUDY_A",
    SnapshotDate = as.Date("2026-01-01"),
    Score = c(0.3, 1.5, 3.0),
    Flag = c(0, 1, 2),
    parameter_category_2 = "AST",
    stringsAsFactors = FALSE
  )
  if (bMultiSnapshot) {
    df2 <- df
    df2$SnapshotDate <- as.Date("2026-02-01")
    df2$Score <- c(0.4, 1.7, 2.9)
    df <- rbind(df, df2)
  }
  df
}

MakeMetricsFixture <- function() {
  data.frame(
    MetricID = "ctas_AST",
    parameter_category_2 = "AST",
    GroupLevel = "Site",
    Threshold = "0.842,2.326",
    stringsAsFactors = FALSE
  )
}

MakeGroupsFixture <- function() {
  data.frame(
    GroupID = c("101", "102", "103"),
    GroupLevel = "Site",
    Param = "Enrolled",
    Value = c(5, 4, 3),
    stringsAsFactors = FALSE
  )
}

test_that("Visualize_CTAS returns a barChart + metricTable for a single snapshot", {
  lCharts <- Visualize_CTAS(
    dfResults = MakeVizFixture(),
    dfMetrics = MakeMetricsFixture(),
    dfGroups = MakeGroupsFixture(),
    strMetricID = "ctas_AST"
  )

  expect_type(lCharts, "list")
  expect_setequal(names(lCharts), c("barChart", "metricTable"))
  expect_s3_class(lCharts$barChart, "htmlwidget")
})

test_that("Visualize_CTAS adds SnapshotDate when the column is absent", {
  df <- MakeVizFixture()
  df$SnapshotDate <- NULL

  lCharts <- Visualize_CTAS(
    dfResults = df,
    dfMetrics = MakeMetricsFixture(),
    dfGroups = MakeGroupsFixture(),
    strMetricID = "ctas_AST"
  )

  expect_s3_class(lCharts$barChart, "htmlwidget")
})

test_that("Visualize_CTAS returns NULL when strMetricID is absent from dfResults", {
  lCharts <- Visualize_CTAS(
    dfResults = MakeVizFixture(),
    dfMetrics = MakeMetricsFixture(),
    dfGroups = MakeGroupsFixture(),
    strMetricID = "ctas_UNKNOWN"
  )

  expect_null(lCharts)
})

test_that("Visualize_CTAS drops dfMetrics when strMetricID is absent from it", {
  dfMetricsOther <- MakeMetricsFixture()
  dfMetricsOther$MetricID <- "ctas_OTHER"

  lCharts <- Visualize_CTAS(
    dfResults = MakeVizFixture(),
    dfMetrics = dfMetricsOther,
    dfGroups = MakeGroupsFixture(),
    strMetricID = "ctas_AST"
  )

  expect_type(lCharts, "list")
  expect_true("barChart" %in% names(lCharts))
  expect_true("metricTable" %in% names(lCharts))
})

test_that("Visualize_CTAS handles dfMetrics = NULL", {
  lCharts <- Visualize_CTAS(
    dfResults = MakeVizFixture(),
    dfMetrics = NULL,
    dfGroups = MakeGroupsFixture()
  )

  expect_type(lCharts, "list")
  expect_true("barChart" %in% names(lCharts))
  expect_true("metricTable" %in% names(lCharts))
})

test_that("Visualize_CTAS returns NULL when no rows survive the snapshot filter", {
  lCharts <- Visualize_CTAS(
    dfResults = MakeVizFixture(),
    dfMetrics = MakeMetricsFixture(),
    dfGroups = MakeGroupsFixture(),
    strMetricID = "ctas_AST",
    strSnapshotDate = as.Date("1900-01-01")
  )

  expect_null(lCharts)
})

test_that("Visualize_CTAS adds a timeSeries widget when there are multiple snapshots", {
  lCharts <- Visualize_CTAS(
    dfResults = MakeVizFixture(bMultiSnapshot = TRUE),
    dfMetrics = MakeMetricsFixture(),
    dfGroups = MakeGroupsFixture(),
    strMetricID = "ctas_AST"
  )

  expect_true("timeSeries" %in% names(lCharts))
  expect_s3_class(lCharts$timeSeries, "htmlwidget")
})

test_that("MakeCharts returns a named list keyed by MetricID", {
  lCharts <- MakeCharts(
    dfResults = MakeVizFixture(),
    dfMetrics = MakeMetricsFixture(),
    dfGroups = MakeGroupsFixture()
  )

  expect_type(lCharts, "list")
  expect_equal(names(lCharts), "ctas_AST")
  expect_s3_class(lCharts[["ctas_AST"]]$barChart, "htmlwidget")
})
