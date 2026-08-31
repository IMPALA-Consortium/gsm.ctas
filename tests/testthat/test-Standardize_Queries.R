test_that("Standardize_Queries maps raw queries into the CTAS vocabulary", {
  dfQueries <- data.frame(
    study = c("A", "A", "A"),
    domain = c("LB", "VS", "EG"),
    field = c("ALT", "SYSBP", "HR"),
    subject_id = c("S1", "S1", "S2"),
    visit = c("WEEK 2", "SCREENING", "WEEK 4"),
    parameter_id = c("ALT", "SYSBP", "HR"),
    query_text = "text",
    query_answer = NA_character_,
    query_status = "Open",
    query_type = "Monitor",
    data_change = FALSE,
    value_first_entry = c("42", "120", "60"),
    value_at_query_open = c("42", "120", "60"),
    value_at_query_close = c("42", "120", "60"),
    value_now = c("42", "120", "60"),
    stringsAsFactors = FALSE
  )
  dfSubjects <- data.frame(
    studyid = c("A", "A"),
    subject_id = c("S1", "S2"),
    site = c("701", "702"),
    country = c("USA", "USA"),
    stringsAsFactors = FALSE
  )

  dfOut <- Standardize_Queries(dfQueries, dfSubjects)

  expect_s3_class(dfOut, "data.frame")
  expect_equal(nrow(dfOut), 3)
  expect_true(all(
    c("subject_id",
      "parameter_id", "parameter_category_1", "parameter_category_2",
      "timepoint_1_name") %in% names(dfOut)
  ))
  # `site`/`country`/`studyid` collide with ctasapp's downstream joins.
  expect_false("site" %in% names(dfOut))
  expect_false("country" %in% names(dfOut))
  expect_false("studyid" %in% names(dfOut))
  expect_setequal(
    dfOut$parameter_category_1,
    c("Labs", "Vital Signs", "ECG")
  )
  # Original query columns preserved verbatim.
  expect_true(all(
    c("query_text", "query_status", "data_change",
      "value_first_entry", "value_now") %in% names(dfOut)
  ))
})

test_that("Standardize_Queries fans out parameter_id onto transformed CTAS ids", {
  dfQueries <- data.frame(
    study = "A", domain = "LB", field = "AST",
    subject_id = "S1", visit = "WEEK 2", parameter_id = "AST",
    stringsAsFactors = FALSE
  )
  dfSubjects <- data.frame(
    studyid = "A", subject_id = "S1", stringsAsFactors = FALSE
  )
  dfInput <- data.frame(
    parameter_id = c("RANGE_AST", "MISS_AST", "NUM_SYSBP"),
    parameter_category_2 = c("AST", "AST", "SYSBP"),
    stringsAsFactors = FALSE
  )

  dfOut <- Standardize_Queries(dfQueries, dfSubjects, dfInput = dfInput)

  expect_setequal(dfOut$parameter_id, c("RANGE_AST", "MISS_AST"))
  expect_true(all(dfOut$parameter_category_2 == "AST"))
})

test_that("Standardize_Queries drops queries whose field is not in dfInput", {
  dfQueries <- data.frame(
    study = "A", domain = "LB", field = "AST",
    subject_id = "S1", visit = "WEEK 2", parameter_id = "AST",
    stringsAsFactors = FALSE
  )
  dfSubjects <- data.frame(
    studyid = "A", subject_id = "S1", stringsAsFactors = FALSE
  )
  dfInput <- data.frame(
    parameter_id = "NUM_SYSBP", parameter_category_2 = "SYSBP",
    stringsAsFactors = FALSE
  )

  dfOut <- Standardize_Queries(dfQueries, dfSubjects, dfInput = dfInput)

  expect_equal(nrow(dfOut), 0)
})

test_that("Standardize_Queries passes unrecognised domains through as category_1", {
  dfQueries <- data.frame(
    study = "A", domain = "AE", field = "AETERM",
    subject_id = "S1", visit = "WEEK 2", parameter_id = "AETERM",
    stringsAsFactors = FALSE
  )
  dfSubjects <- data.frame(
    studyid = "A", subject_id = "S1", site = "701",
    stringsAsFactors = FALSE
  )

  dfOut <- Standardize_Queries(dfQueries, dfSubjects)

  expect_equal(dfOut$parameter_category_1, "AE")
})

test_that("Standardize_Queries drops queries whose subject is not in dfSubjects", {
  dfQueries <- data.frame(
    study = c("A", "A"),
    domain = c("LB", "LB"),
    field = c("ALT", "ALT"),
    subject_id = c("S1", "S99"),
    visit = c("WEEK 2", "WEEK 2"),
    parameter_id = c("ALT", "ALT"),
    stringsAsFactors = FALSE
  )
  dfSubjects <- data.frame(
    studyid = "A", subject_id = "S1", site = "701",
    stringsAsFactors = FALSE
  )

  dfOut <- Standardize_Queries(dfQueries, dfSubjects)

  expect_equal(nrow(dfOut), 1)
  expect_equal(dfOut$subject_id, "S1")
})
