# Unit tests for Flag_CTAS().

MakeScoresFixture <- function() {
  data.frame(
    MetricID = "ctas_AST",
    GroupID = c("101", "102", "103", "104"),
    Score = c(0.10, 0.842, 2.326, 3.00), # edge values on the two thresholds
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
  df <- Flag_CTAS(MakeScoresFixture()) # default c(2, 1, 0)

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
      vFlag = c(0, 1)
    ),
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
  df <- Flag_CTAS(MakeScoresFixture(),
    vFlagOrder = NULL,
    nAccrualThreshold = 1,
    strAccrualMetric = "Denominator"
  )

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
      strAccrualMetric = "Bogus"
    ),
    "strAccrualMetric"
  )
})

test_that("errors when dfAnalyzed is not a data.frame", {
  expect_error(Flag_CTAS(list(Score = 1)), "data.frame")
})

test_that("errors when strColumn is not a single string", {
  expect_error(
    Flag_CTAS(MakeScoresFixture(), strColumn = c("a", "b")),
    "single column name"
  )
  expect_error(
    Flag_CTAS(MakeScoresFixture(), strColumn = 42),
    "single column name"
  )
})

test_that("errors when vThreshold is empty or non-numeric", {
  expect_error(
    Flag_CTAS(MakeScoresFixture(), vThreshold = numeric(0)),
    "non-empty numeric"
  )
  expect_error(
    Flag_CTAS(MakeScoresFixture(), vThreshold = c("a", "b")),
    "non-empty numeric"
  )
})

test_that("errors when vThreshold is not strictly ascending", {
  expect_error(
    Flag_CTAS(MakeScoresFixture(), vThreshold = c(2.0, 1.0)),
    "strictly ascending"
  )
})

test_that("errors when vFlag has the wrong length", {
  expect_error(
    Flag_CTAS(MakeScoresFixture(), vFlag = c(0, 1)),
    "numeric elements"
  )
})

test_that("errors when vFlagOrder does not match vFlag", {
  expect_error(
    Flag_CTAS(MakeScoresFixture(), vFlagOrder = c(0, 1, 99)),
    "same values as"
  )
})

test_that("errors when nAccrualThreshold is not a single number", {
  expect_error(
    Flag_CTAS(MakeScoresFixture(),
      nAccrualThreshold = c(1, 2),
      strAccrualMetric = "Numerator"
    ),
    "single number"
  )
})

test_that("Difference accrual metric NAs out sites below the threshold", {
  df <- MakeScoresFixture()
  df$Numerator <- c(1, 1, 1, 1)
  df$Denominator <- c(2, 5, 5, 5) # difference = 1, 4, 4, 4

  dfFlagged <- Flag_CTAS(
    df,
    nAccrualThreshold = 3,
    strAccrualMetric = "Difference",
    vFlagOrder = NULL
  )

  # First row's difference (1) is below 3 => Score and Flag are NA.
  expect_true(is.na(dfFlagged$Score[1]))
  expect_true(is.na(dfFlagged$Flag[1]))
  # Remaining sites keep their flag values.
  expect_false(any(is.na(dfFlagged$Flag[-1])))
})
