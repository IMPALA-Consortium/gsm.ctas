test_that("SDTM domain datasets ship with the package", {
  for (strName in c("dm", "lb", "vs", "eg", "rs")) {
    e <- new.env()
    data(list = strName, package = "gsm.ctas", envir = e)
    df <- e[[strName]]
    expect_s3_class(df, "data.frame")
    expect_gt(nrow(df), 0)
    expect_true(all(c("STUDYID", "USUBJID") %in% names(df)))
  }
})

test_that("queries dataset matches the ctasapp upload contract", {
  e <- new.env()
  data("queries", package = "gsm.ctas", envir = e)
  q <- e$queries

  expect_s3_class(q, "data.frame")
  expect_gt(nrow(q), 0)
  expect_setequal(
    names(q),
    c("study", "domain", "field", "subject_id", "visit", "parameter_id",
      "query_text", "query_answer", "query_status", "query_type",
      "data_change", "value_first_entry", "value_at_query_open",
      "value_at_query_close", "value_now")
  )
  expect_type(q$data_change, "logical")
  expect_true(all(q$query_status %in% c("Open", "Answered", "Closed")))
  expect_true(all(q$domain %in% c("LB", "VS", "EG", "RS")))
})
