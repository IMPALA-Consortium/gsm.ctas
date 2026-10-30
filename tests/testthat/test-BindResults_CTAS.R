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

test_that("untransformed keeps rows without any original value", {
  lAnalysis <- list(
    A = list(untransformed = data.frame(
      subject_id = c("s1", "s2", "s3"),
      parameter_category_2 = "COLOR",
      timepoint_1_name = "WEEK 2",
      original_value = c(1.0, NA_real_, NA_real_),
      original_category = c(NA_character_, "Y", NA_character_),
      stringsAsFactors = FALSE
    ))
  )

  df <- BindResults_CTAS(lAnalysis, "untransformed")

  expect_equal(nrow(df), 3)
  expect_setequal(df$subject_id, c("s1", "s2", "s3"))
})

# The same source row arrives from every metric that reads its field; keep the fullest copy.
test_that("untransformed is de-duplicated on the join keys across metrics", {
  dfRange <- data.frame(
    studyid = c("A", "B"), subject_id = "s1", parameter_category_2 = "ALT",
    timepoint_1_name = "WEEK 2", parameter_id = "RANGE_ALT",
    value = c(10, 12), original_value = c(10, 12),
    lower = c(0, 0), upper = c(40, 40), original_category = NA_character_,
    stringsAsFactors = FALSE
  )
  dfMissing <- data.frame(
    studyid = c("A", "B"), subject_id = "s1", parameter_category_2 = "ALT",
    timepoint_1_name = "WEEK 2", parameter_id = "MISS_ALT",
    value = c(10, 12), original_value = c(10, 12),
    lower = NA_real_, upper = NA_real_, original_category = NA_character_,
    stringsAsFactors = FALSE
  )
  dfCategorical <- data.frame(
    studyid = "A", subject_id = "s1", parameter_category_2 = "OVRLRESP",
    timepoint_1_name = "WEEK 2", parameter_id = "OVRLRESP",
    value = "CR", original_value = NA_real_,
    lower = NA_real_, upper = NA_real_, original_category = "CR",
    stringsAsFactors = FALSE
  )

  df <- BindResults_CTAS(
    list(
      missing = list(untransformed = dfMissing),
      range = list(untransformed = dfRange),
      categorical = list(untransformed = dfCategorical)
    ),
    "untransformed"
  )

  expect_equal(nrow(df), 3)
  expect_false(any(c("value", "parameter_id") %in% names(df)))
  expect_equal(
    df$upper[df$parameter_category_2 == "ALT"],
    c(40, 40)
  )
  expect_equal(df$study[df$parameter_category_2 == "ALT"], c("A", "B"))
  expect_equal(df$original_category[df$parameter_category_2 == "OVRLRESP"], "CR")
})

test_that("studyid is renamed to study on any shard", {
  lAnalysis <- list(
    A = list(results = data.frame(studyid = "STUDY_A", x = 1, stringsAsFactors = FALSE))
  )

  df <- BindResults_CTAS(lAnalysis, "results")

  expect_true("study" %in% names(df))
  expect_false("studyid" %in% names(df))
})
