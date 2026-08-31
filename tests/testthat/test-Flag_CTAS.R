# Unit tests for Flag_CTAS().

MakeScoresFixture <- function() {
  data.frame(
    MetricID = "ctas_AST",
    GroupID = c("101", "102", "103", "104"),
    Score = c(0.10, 0.842, 2.326, 3.00),   # edge values on the two thresholds
    Numerator = c(2, 2, 2, 0),
    Denominator = c(2, 2, 2, 0),
    stringsAsFactors = FALSE
  )
}

test_that("adds a Flag column with the correct level per interval", {
  df <- Flag_CTAS(MakeScoresFixture(), vFlagOrder = NULL)

  # Left-closed intervals: 0.842 -> 1, 2.326 -> 2.
  vExpected <- c(0, 1, 2, 2)
  expect_equal(df$Flag, vExpected)
})

test_that("vFlagOrder controls returned row order", {
  df <- Flag_CTAS(MakeScoresFixture())  # default c(2, 1, 0)

  # First rows should be Flag == 2, then 1, then 0.
  expect_equal(df$Flag, c(2, 2, 1, 0))
})

test_that("vFlagOrder = NULL leaves rows in input order", {
  df <- Flag_CTAS(MakeScoresFixture(), vFlagOrder = NULL)

  expect_equal(df$GroupID, c("101", "102", "103", "104"))
})

test_that("errors when strColumn is missing from dfAnalyzed", {
  df <- MakeScoresFixture()
  df$Score <- NULL

  expect_error(Flag_CTAS(df), "Score")
})

test_that("errors on non-ascending vThreshold", {
  expect_error(
    Flag_CTAS(MakeScoresFixture(), vThreshold = c(2.326, 0.842)),
    "ascending"
  )
})

test_that("errors when vFlag length doesn't match", {
  expect_error(
    Flag_CTAS(MakeScoresFixture(),
              vThreshold = c(0.842, 2.326),
              vFlag = c(0, 1)),
    "vFlag"
  )
})

test_that("errors when vFlagOrder doesn't match vFlag values", {
  expect_error(
    Flag_CTAS(MakeScoresFixture(), vFlagOrder = c(5, 6, 7)),
    "vFlagOrder"
  )
})

test_that("accrual filter NAs out Score and Flag when below threshold", {
  df <- Flag_CTAS(MakeScoresFixture(), vFlagOrder = NULL,
                  nAccrualThreshold = 1,
                  strAccrualMetric = "Denominator")

  # site 104 has Denominator = 0 < 1
  vBelow <- df$GroupID == "104"
  expect_true(all(is.na(df$Score[vBelow])))
  expect_true(all(is.na(df$Flag[vBelow])))
  # Others untouched
  expect_false(any(is.na(df$Score[!vBelow])))
})

test_that("accrual filter requires a valid strAccrualMetric", {
  expect_error(
    Flag_CTAS(MakeScoresFixture(), nAccrualThreshold = 1),
    "strAccrualMetric"
  )
  expect_error(
    Flag_CTAS(MakeScoresFixture(),
              nAccrualThreshold = 1,
              strAccrualMetric = "Bogus"),
    "strAccrualMetric"
  )
})
