# Unit tests for BindResults_CTAS() covering input validation and the
# empty/absent-shard branches.

test_that("errors when lAnalysis is not a list", {
  expect_error(
    BindResults_CTAS(iris, "results"),
    "list of metric workflow outputs"
  )
})

test_that("errors when strName is not a single character string", {
  expect_error(BindResults_CTAS(list(), c("a", "b")), "single shard name")
  expect_error(BindResults_CTAS(list(), 123), "single shard name")
})

test_that("untransformed returns a zero-row frame when the shard is absent", {
  df <- BindResults_CTAS(
    list(A = list(results = data.frame(x = 1)), B = list(results = data.frame(x = 2))),
    "untransformed"
  )

  expect_s3_class(df, "data.frame")
  expect_equal(nrow(df), 0)
})

test_that("untransformed keeps rows with either original_value or original_category", {
  lAnalysis <- list(
    A = list(untransformed = data.frame(
      subject_id = c("s1", "s2", "s3"),
      original_value = c(1.0, NA_real_, NA_real_),
      original_category = c(NA_character_, "Y", NA_character_),
      stringsAsFactors = FALSE
    ))
  )

  df <- BindResults_CTAS(lAnalysis, "untransformed")

  expect_equal(nrow(df), 2)
  expect_setequal(df$subject_id, c("s1", "s2"))
})

test_that("studyid is renamed to study on any shard", {
  lAnalysis <- list(
    A = list(results = data.frame(studyid = "STUDY_A", x = 1, stringsAsFactors = FALSE))
  )

  df <- BindResults_CTAS(lAnalysis, "results")

  expect_true("study" %in% names(df))
  expect_false("studyid" %in% names(df))
})
