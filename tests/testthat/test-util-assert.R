# Unit tests for util-assert.R helpers.

test_that("AssertColumns is silent when every required column is present", {
  df <- data.frame(a = 1, b = 2)
  expect_silent(AssertColumns(df, c("a", "b"), "dfInput"))
  expect_null(AssertColumns(df, c("a", "b"), "dfInput"))
})

test_that("AssertColumns aborts with the label and missing columns", {
  df <- data.frame(a = 1)
  expect_error(
    AssertColumns(df, c("a", "b", "c"), "dfSubjects"),
    "dfSubjects"
  )
})

test_that("AssertColumns ignores NA entries in vColumns", {
  df <- data.frame(a = 1)
  expect_silent(AssertColumns(df, c("a", NA), "dfInput"))
})

MakeValidCTASInput <- function(bIncludeStudy = TRUE) {
  df <- data.frame(
    subject_id = c("s1", "s2", "s3", "s4"),
    site = c("site1", "site1", "site2", "site2"),
    parameter_id = "PARAM",
    parameter_name = "Param",
    parameter_category_1 = "Cat1",
    parameter_category_2 = "PARAM",
    parameter_category_3 = "numeric",
    timepoint_1_name = "VISIT 1",
    timepoint_2_name = NA_character_,
    timepoint_rank = 1,
    result = c(1.1, 1.2, 1.3, 1.4),
    baseline = NA_real_,
    stringsAsFactors = FALSE
  )
  if (bIncludeStudy) df$studyid <- "STUDY_A"
  df
}

test_that("AssertCTASInput aborts when strStudyCol is absent from dfInput", {
  df <- MakeValidCTASInput(bIncludeStudy = FALSE)
  expect_error(AssertCTASInput(df, strStudyCol = "studyid"), "studyid")
})

test_that("AssertCTASInput passes with strStudyCol = NULL when studyid is absent", {
  df <- MakeValidCTASInput(bIncludeStudy = FALSE)
  expect_silent(AssertCTASInput(df, strStudyCol = NULL))
})

test_that("AssertCTASInput aborts with <2 sites", {
  df <- MakeValidCTASInput()
  df$site <- "only_site"
  expect_error(AssertCTASInput(df), "at least 2 sites")
})

test_that("AssertCTASInput aborts on non-data.frame input", {
  expect_error(AssertCTASInput(list()), "data.frame")
})

test_that("AssertCTASInput aborts on zero-row input", {
  df <- MakeValidCTASInput()[0, , drop = FALSE]
  expect_error(AssertCTASInput(df), "no rows")
})
