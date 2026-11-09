# Unit tests for util-metric-meta.R helpers.

test_that("FindMetricMeta returns list() for a NULL or empty workflow list", {
  expect_identical(FindMetricMeta("numeric", NULL), list())
  expect_identical(FindMetricMeta("numeric", list()), list())
})

test_that("FindMetricMeta returns list() when no workflow ID matches", {
  lWorkflows <- list(
    list(meta = list(ID = "numeric"))
  )
  expect_identical(FindMetricMeta("range_normalized", lWorkflows), list())
})

test_that("FindMetricMeta returns the matching workflow's meta block", {
  lMetaNumeric <- list(ID = "numeric", Threshold = "0.8;2.3")
  lMetaRange <- list(ID = "range_normalized", Threshold = "1.0")
  lWorkflows <- list(
    list(meta = lMetaNumeric),
    list(meta = lMetaRange)
  )

  expect_identical(FindMetricMeta("range_normalized", lWorkflows), lMetaRange)
  expect_identical(FindMetricMeta("numeric", lWorkflows), lMetaNumeric)
})
