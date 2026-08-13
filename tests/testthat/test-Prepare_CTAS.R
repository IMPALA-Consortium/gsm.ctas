test_that("Prepare_Normalize scales values relative to the reference range", {
  expect_equal(
    Prepare_Normalize(c(5, 7.5, 10), vLow = rep(5, 3), vHigh = rep(10, 3)),
    c(0, 0.5, 1)
  )
})

test_that("Prepare_Normalize signals out-of-range values", {
  vResult <- Prepare_Normalize(c(0, 20), vLow = c(5, 5), vHigh = c(10, 10))

  expect_lt(vResult[1], 0)
  expect_gt(vResult[2], 1)
})

test_that("Prepare_Normalize returns NA for invalid ranges", {
  expect_equal(
    Prepare_Normalize(
      vValue = c(1, 1, 1, 1),
      vLow = c(5, 5, NA, 5),
      vHigh = c(5, 4, 10, NA)
    ),
    rep(NA_real_, 4)
  )
})

test_that("Prepare_Normalize preserves length and propagates missing values", {
  vResult <- Prepare_Normalize(c(5, NA), vLow = c(0, 0), vHigh = c(10, 10))

  expect_length(vResult, 2)
  expect_true(is.na(vResult[2]))
})

test_that("Prepare_MissingRatio computes a cumulative missing proportion", {
  expect_equal(
    Prepare_MissingRatio(
      vValue = c(1, NA, NA, 4),
      vSubjectID = rep("S1", 4),
      vParameterID = rep("SYSBP", 4)
    ),
    c(0, 1 / 2, 2 / 3, 2 / 4)
  )
})

test_that("Prepare_MissingRatio restarts per subject and parameter", {
  expect_equal(
    Prepare_MissingRatio(
      vValue = c(NA, 2, NA, 4),
      vSubjectID = c("S1", "S1", "S2", "S2"),
      vParameterID = rep("SYSBP", 4)
    ),
    c(1, 0.5, 1, 0.5)
  )

  expect_equal(
    Prepare_MissingRatio(
      vValue = c(NA, 2, NA, 4),
      vSubjectID = rep("S1", 4),
      vParameterID = c("SYSBP", "SYSBP", "DIABP", "DIABP")
    ),
    c(1, 0.5, 1, 0.5)
  )
})

test_that("Prepare_MissingRatio returns values aligned to the input row order", {
  vResult <- Prepare_MissingRatio(
    vValue = c(NA, NA, 3, 4),
    vSubjectID = c("S2", "S1", "S2", "S1"),
    vParameterID = rep("SYSBP", 4)
  )

  expect_equal(vResult, c(1, 1, 0.5, 0.5))
})

test_that("Prepare_MissingRatio handles zero-length input", {
  expect_length(
    Prepare_MissingRatio(numeric(0), character(0), character(0)),
    0
  )
})

test_that("Prepare_Categorical creates one row per observation per level", {
  dfResult <- Prepare_Categorical(c("CR", "PR"), strPrefix = "OVRLRESP")

  expect_equal(nrow(dfResult), 4)
  expect_equal(sort(unique(dfResult$Level)), c("OVRLRESP=CR", "OVRLRESP=PR"))
  expect_equal(sum(dfResult$Encoded), 2)
})

test_that("Prepare_Categorical encodes matches as 1 and non-matches as 0", {
  dfResult <- Prepare_Categorical(c("CR", "PR"), strPrefix = "R")

  expect_equal(dfResult$Encoded[dfResult$Level == "R=CR"], c(1L, 0L))
  expect_equal(dfResult$Encoded[dfResult$Level == "R=PR"], c(0L, 1L))
})

test_that("Prepare_Categorical drops missing values but keeps source row index", {
  dfResult <- Prepare_Categorical(c("CR", NA, "CR"), strPrefix = "R")

  expect_equal(dfResult$RowIndex, c(1L, 3L))
  expect_equal(unique(dfResult$Level), "R=CR")
})

test_that("Prepare_Categorical returns an empty frame when all values are missing", {
  dfResult <- Prepare_Categorical(c(NA_character_, NA_character_))

  expect_equal(nrow(dfResult), 0)
  expect_named(dfResult, c("RowIndex", "Level", "Encoded"))
})

test_that("Prepare_TimepointRank produces contiguous ranks per group", {
  dfResult <- Prepare_TimepointRank(data.frame(
    subject_id = c("S1", "S1", "S2"),
    parameter_id = c("SYSBP", "SYSBP", "SYSBP"),
    timepoint_1_name = c("WEEK 12", "WEEK 2", "WEEK 2"),
    timepoint_rank = c(7, 3, 3)
  ))

  expect_equal(dfResult$timepoint_rank, c(1L, 2L, 1L))
  expect_equal(dfResult$timepoint_1_name, c("WEEK 2", "WEEK 12", "WEEK 2"))
})

test_that("Prepare_TimepointRank orders by visit number, not visit name", {
  dfResult <- Prepare_TimepointRank(data.frame(
    subject_id = "S1",
    parameter_id = "SYSBP",
    timepoint_1_name = c("WEEK 12", "WEEK 2"),
    timepoint_rank = c(12, 2)
  ))

  expect_equal(dfResult$timepoint_1_name, c("WEEK 2", "WEEK 12"))
})

test_that("Prepare_TimepointRank breaks ties on timepoint name", {
  dfResult <- Prepare_TimepointRank(data.frame(
    subject_id = "S1",
    parameter_id = "SYSBP",
    timepoint_1_name = c("VISIT B", "VISIT A"),
    timepoint_rank = c(1, 1)
  ))

  expect_equal(dfResult$timepoint_1_name, c("VISIT A", "VISIT B"))
  expect_equal(dfResult$timepoint_rank, c(1L, 2L))
})

test_that("Prepare_TimepointRank errors informatively on missing columns", {
  expect_error(
    Prepare_TimepointRank(data.frame(subject_id = "S1")),
    "parameter_id"
  )
})

