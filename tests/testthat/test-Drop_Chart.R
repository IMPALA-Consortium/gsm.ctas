# Unit tests for Drop_Chart().

MakeChartsFixture <- function() {
  list(
    ctas_AST = list(scatterPlot = "s1", barChart = "b1", metricTable = "t1"),
    ctas_ALT = list(scatterPlot = "s2", barChart = "b2", metricTable = "t2")
  )
}

test_that("Drop_Chart: removes named entry from every metric slot", {
  lOut <- Drop_Chart(MakeChartsFixture(), "scatterPlot")

  expect_setequal(names(lOut), c("ctas_AST", "ctas_ALT"))
  expect_false("scatterPlot" %in% names(lOut$ctas_AST))
  expect_false("scatterPlot" %in% names(lOut$ctas_ALT))
  expect_setequal(names(lOut$ctas_AST), c("barChart", "metricTable"))
})

test_that("Drop_Chart: multiple names dropped at once", {
  lOut <- Drop_Chart(MakeChartsFixture(),
                     c("scatterPlot", "metricTable"))

  expect_setequal(names(lOut$ctas_AST), "barChart")
  expect_setequal(names(lOut$ctas_ALT), "barChart")
})

test_that("Drop_Chart: empty or NULL vDropCharts is a no-op", {
  lIn <- MakeChartsFixture()
  expect_identical(Drop_Chart(lIn), lIn)
  expect_identical(Drop_Chart(lIn, character(0)), lIn)
  expect_identical(Drop_Chart(lIn, NULL), lIn)
})

test_that("Drop_Chart: unknown chart names are silently ignored", {
  lIn <- MakeChartsFixture()
  expect_identical(Drop_Chart(lIn, "not_a_chart"), lIn)
})

test_that("Drop_Chart: non-list inner slots pass through unchanged", {
  lIn <- list(ctas_AST = "not_a_list",
              ctas_ALT = list(scatterPlot = "s", barChart = "b"))
  lOut <- Drop_Chart(lIn, "scatterPlot")
  expect_identical(lOut$ctas_AST, "not_a_list")
  expect_setequal(names(lOut$ctas_ALT), "barChart")
})

test_that("Drop_Chart: errors on invalid inputs", {
  expect_error(Drop_Chart("not a list"), "must be a list")
  expect_error(Drop_Chart(MakeChartsFixture(), 1L),
               "character vector")
})
