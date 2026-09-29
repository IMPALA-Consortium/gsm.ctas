# Unit tests for the internal CTAS engine adapters. These functions are
# also exercised indirectly by Analyze_CTAS; the direct tests here pin down
# the validation branches and metadata edge cases required by the 100%
# coverage gate.

test_that("AssembleFeatures aborts when every flag is FALSE", {
  expect_error(
    AssembleFeatures(FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE),
    "must be"
  )
})

test_that("AssembleFeatures returns semicolon-separated flag names", {
  strFeatures <- AssembleFeatures(
    bAutocorr = TRUE,
    bAverage = TRUE,
    bSD = FALSE,
    bRange = FALSE,
    bUniqueValueCountRelative = FALSE,
    bOwnSiteSimilScore = FALSE,
    bLOF = FALSE
  )
  expect_equal(strFeatures, "autocorr;average")
})

test_that("BuildResults aborts when parameter_id has inconsistent metadata", {
  dfInput <- data.frame(
    parameter_id = c("P1", "P1"),
    parameter_category_1 = c("Cat1", "Cat1"),
    parameter_category_2 = c("A", "B"),
    parameter_category_3 = c("numeric", "numeric"),
    stringsAsFactors = FALSE
  )
  lCTAS <- list(
    timeseries = data.frame(
      timeseries_id = "t1", parameter_id = "P1", stringsAsFactors = FALSE
    ),
    site_scores = data.frame(
      timeseries_id = "t1", stringsAsFactors = FALSE
    )
  )

  expect_error(
    BuildResults(lCTAS, dfInput, strStudyCol = NULL),
    "parameter metadata is inconsistent"
  )
})

test_that("BuildResults aborts when site_scores references an unknown timeseries", {
  dfInput <- data.frame(
    parameter_id = "P1",
    parameter_category_1 = "Cat1",
    parameter_category_2 = "A",
    parameter_category_3 = "numeric",
    stringsAsFactors = FALSE
  )
  lCTAS <- list(
    timeseries = data.frame(
      timeseries_id = "t1", parameter_id = "P1", stringsAsFactors = FALSE
    ),
    site_scores = data.frame(
      timeseries_id = "orphan", stringsAsFactors = FALSE
    )
  )

  expect_error(
    BuildResults(lCTAS, dfInput, strStudyCol = NULL),
    "no match in"
  )
})

test_that("BuildCTASInput fills in country and region defaults when absent", {
  dfInput <- data.frame(
    subject_id = c("s1", "s2"),
    site = c("site1", "site2"),
    parameter_id = "P1",
    parameter_name = "Param",
    parameter_category_1 = "Cat1",
    parameter_category_2 = "P1",
    parameter_category_3 = "numeric",
    timepoint_1_name = c("V1", "V1"),
    timepoint_2_name = NA_character_,
    timepoint_rank = c(1, 1),
    result = c(1.0, 2.0),
    baseline = NA_real_,
    stringsAsFactors = FALSE
  )

  lOut <- BuildCTASInput(
    dfInput,
    strStudyCol = NULL,
    dfCustomTimeseries = NULL,
    dfCustomReferenceGroups = NULL
  )

  expect_equal(unique(lOut$subjects$country), "no")
  expect_equal(unique(lOut$subjects$region), "no")
  expect_equal(nrow(lOut$data), 2)
  expect_true(all(c("parameter_id", "parameter_category_2") %in% names(lOut$parameters)))
})
