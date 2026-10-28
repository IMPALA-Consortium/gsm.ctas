# Unit tests for util-ctas-schema.R.

test_that("EmptyCTASUntransformed returns a zero-row frame with the ctasapp schema", {
  df <- EmptyCTASUntransformed()

  expect_s3_class(df, "data.frame")
  expect_equal(nrow(df), 0)
  expect_equal(
    names(df),
    c(
      "subject_id", "parameter_category_2", "timepoint_1_name",
      "original_value", "lower", "upper", "original_category"
    )
  )
  expect_type(df$subject_id, "character")
  expect_type(df$original_value, "double")
  expect_type(df$lower, "double")
  expect_type(df$upper, "double")
  expect_type(df$original_category, "character")
})
