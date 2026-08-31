test_that("Filter_Flagged drops MetricIDs whose max flag is below iMinFlag", {
  dfFlagged <- data.frame(
    MetricID = c("m1", "m1", "m2", "m2", "m3", "m3"),
    GroupID = c("A", "B", "A", "B", "A", "B"),
    Score = c(0.1, 3.0, 0.2, 0.3, 0.4, 1.5),
    Flag = c(0, 2, 0, 0, 0, 1),
    stringsAsFactors = FALSE
  )
  out <- Filter_Flagged(dfFlagged, iMinFlag = 1L)
  expect_setequal(unique(out$MetricID), c("m1", "m3"))
})

test_that("Filter_Flagged with iMinFlag = 2 keeps only reds", {
  dfFlagged <- data.frame(
    MetricID = c("m1", "m2", "m2"),
    GroupID = c("A", "A", "B"),
    Score = c(3.0, 1.0, 0.1),
    Flag = c(2, 1, 0),
    stringsAsFactors = FALSE
  )
  out <- Filter_Flagged(dfFlagged, iMinFlag = 2L)
  expect_equal(unique(out$MetricID), "m1")
})

test_that("Filter_Flagged with iMinFlag = 0 or NULL is a no-op", {
  dfFlagged <- data.frame(
    MetricID = c("m1", "m2"),
    Flag = c(0, 0),
    stringsAsFactors = FALSE
  )
  expect_equal(nrow(Filter_Flagged(dfFlagged, iMinFlag = 0L)), 2L)
  expect_equal(nrow(Filter_Flagged(dfFlagged, iMinFlag = NULL)), 2L)
})

test_that("Filter_Flagged handles NA flags without keeping empty groups", {
  dfFlagged <- data.frame(
    MetricID = c("m1", "m1", "m2"),
    Flag = c(NA_real_, NA_real_, 2),
    stringsAsFactors = FALSE
  )
  out <- Filter_Flagged(dfFlagged, iMinFlag = 1L)
  expect_equal(unique(out$MetricID), "m2")
})

test_that("Filter_Flagged errors on missing columns", {
  expect_error(Filter_Flagged(data.frame(x = 1), iMinFlag = 1L))
})
