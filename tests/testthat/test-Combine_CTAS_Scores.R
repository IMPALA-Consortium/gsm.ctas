MakeResult <- function() {
  list(
    site_scores = dplyr::tibble(
      timeseries_id = c("ts1", "ts2", "ts1"),
      site = c("001", "001", "002"),
      feature = c("average", "average", "sd"),
      fdr_corrected_pvalue_logp = c(3.0, 0.5, 1.0)
    ),
    timeseries = dplyr::tibble(
      timeseries_id = c("ts1", "ts2"),
      parameter_id = c("VS_SYSBP", "LB_NORM_ALB")
    )
  )
}

test_that("Combine_CTAS_Scores attaches parameter_id to every score", {
  dfScores <- Combine_CTAS_Scores(MakeResult())

  expect_s3_class(dfScores, "data.frame")
  expect_equal(nrow(dfScores), 3)
  expect_equal(dfScores$parameter_id, c("VS_SYSBP", "LB_NORM_ALB", "VS_SYSBP"))
})

test_that("Combine_CTAS_Scores satisfies the ctasapp drill-down contract", {
  # site_scores alone lacks parameter_id, which is why the join exists.
  expect_true(all(
    c("site", "timeseries_id", "parameter_id", "feature", "fdr_corrected_pvalue_logp") %in%
      names(Combine_CTAS_Scores(MakeResult()))
  ))
})

test_that("Combine_CTAS_Scores does not duplicate rows", {
  lResult <- MakeResult()
  # `timeseries` carries one row per timeseries and baseline variant, so a naive
  # join could fan out. Force the case.
  lResult$timeseries <- dplyr::bind_rows(lResult$timeseries, lResult$timeseries)

  expect_equal(nrow(Combine_CTAS_Scores(lResult)), 3)
})

test_that("Combine_CTAS_Scores rejects malformed input", {
  expect_error(Combine_CTAS_Scores(data.frame(x = 1)), "must be a list")
  expect_error(Combine_CTAS_Scores(list(site_scores = data.frame())), "missing required")

  lResult <- MakeResult()
  lResult$timeseries$parameter_id <- NULL
  expect_error(Combine_CTAS_Scores(lResult), "missing required column")
})

test_that("Combine_CTAS_Scores fails on an unmatched timeseries", {
  # Silently yielding NA would drop the timeseries from every parameter-filtered
  # metric without any indication.
  lResult <- MakeResult()
  lResult$timeseries <- lResult$timeseries[1, ]

  expect_error(Combine_CTAS_Scores(lResult), "no match")
})

# --- parameter categories -----------------------------------------------------

MakeInput <- function() {
  list(parameters = dplyr::tibble(
    parameter_id = c("VS_SYSBP", "LB_NORM_ALB"),
    parameter_category_1 = c("Vital Signs", "Labs"),
    parameter_category_3 = c("numeric", "range_normalized")
  ))
}

test_that("Combine_CTAS_Scores recovers the categories CTAS discards", {
  # process_a_study() consumes `parameters` but returns none of its category
  # columns, so the input is the only place they can come from.
  dfScores <- Combine_CTAS_Scores(MakeResult(), MakeInput())

  expect_equal(dfScores$parameter_category_1, c("Vital Signs", "Labs", "Vital Signs"))
  expect_equal(dfScores$parameter_category_3, c("numeric", "range_normalized", "numeric"))
})

test_that("Combine_CTAS_Scores leaves the categories out when lInput is absent", {
  # Single-domain studies should not be forced to thread the input through.
  expect_false("parameter_category_1" %in% names(Combine_CTAS_Scores(MakeResult())))
})

test_that("Combine_CTAS_Scores rejects an input from a different run", {
  # A silent NA category would make the metric's filter match nothing, which
  # surfaces far downstream as an unrelated error.
  lInput <- MakeInput()
  lInput$parameters <- lInput$parameters[1, ]

  expect_error(Combine_CTAS_Scores(MakeResult(), lInput), "same CTAS run")
})

test_that("Combine_CTAS_Scores rejects a duplicated parameter", {
  lInput <- MakeInput()
  lInput$parameters <- dplyr::bind_rows(
    lInput$parameters, dplyr::mutate(lInput$parameters[1, ], parameter_category_3 = "other")
  )

  expect_error(Combine_CTAS_Scores(MakeResult(), lInput), "not unique")
})

test_that("Combine_CTAS_Scores validates lInput", {
  expect_error(Combine_CTAS_Scores(MakeResult(), data.frame(x = 1)), "must be a list")
  expect_error(Combine_CTAS_Scores(MakeResult(), list(data = 1)), "parameters")

  lInput <- MakeInput()
  lInput$parameters$parameter_category_3 <- NULL
  expect_error(Combine_CTAS_Scores(MakeResult(), lInput), "missing required column")
})
