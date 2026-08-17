test_that("DropChart removes the named chart from every metric", {
  lCharts <- list(
    Analysis_ctas0001 = list(scatterPlot = 1, barChart = 2, metricTable = 3),
    Analysis_ctas0002 = list(scatterPlot = 4, barChart = 5, metricTable = 6)
  )

  lResult <- DropChart(lCharts, "scatterPlot")

  expect_named(lResult, c("Analysis_ctas0001", "Analysis_ctas0002"))
  expect_named(lResult$Analysis_ctas0001, c("barChart", "metricTable"))
  expect_named(lResult$Analysis_ctas0002, c("barChart", "metricTable"))
})

test_that("DropChart removes several charts at once", {
  lCharts <- list(m = list(scatterPlot = 1, barChart = 2, metricTable = 3))

  expect_named(
    DropChart(lCharts, c("scatterPlot", "barChart"))$m,
    "metricTable"
  )
})

test_that("DropChart leaves a chart list without the named chart unchanged", {
  lCharts <- list(m = list(barChart = 1, metricTable = 2))

  expect_equal(DropChart(lCharts, "scatterPlot"), lCharts)
})

test_that("DropChart preserves NULL metrics", {
  # `MakeCharts()` returns NULL for a metric with no matching results; the metric
  # must survive so the report still lists it as unevaluated.
  lCharts <- list(m1 = NULL, m2 = list(scatterPlot = 1, barChart = 2))

  lResult <- DropChart(lCharts, "scatterPlot")

  expect_named(lResult, c("m1", "m2"))
  expect_null(lResult$m1)
})

test_that("DropChart preserves widget attributes on retained charts", {
  # `Report_MetricCharts()` reads the `output_label` attribute to title each tab.
  chart <- structure(1, output_label = "Bar Chart")
  lCharts <- list(m = list(scatterPlot = 2, barChart = chart))

  lResult <- DropChart(lCharts, "scatterPlot")

  expect_equal(attr(lResult$m$barChart, "output_label"), "Bar Chart")
})

test_that("DropChart rejects bad input", {
  expect_error(DropChart("not a list"), "must be a")
  expect_error(DropChart(list(), strChart = 1), "character")
})
