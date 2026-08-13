MakeSiteScores <- function() {
  dplyr::tibble(
    timeseries_id = c("ts1", "ts2", "ts3", "ts1", "ts2", "ts3", "ts1"),
    site = c("001", "001", "001", "002", "002", "002", "003"),
    country = c("USA", "USA", "USA", "USA", "USA", "USA", "DEU"),
    feature = c(rep("average", 6), "sd"),
    fdr_corrected_pvalue_logp = c(3.0, 2.5, 0.1, 1.0, 0.5, 0.0, 4.0)
  )
}

# --- AddCTASTrigger -----------------------------------------------------------

test_that("AddCTASTrigger classifies against both thresholds", {
  dfTrigger <- AddCTASTrigger(MakeSiteScores())

  expect_equal(
    dfTrigger$Trigger,
    c(
      "Further Evaluation", "Further Evaluation", "No Action",
      "Watch List", "No Action", "No Action", "Further Evaluation"
    )
  )
})

test_that("AddCTASTrigger treats thresholds as inclusive lower bounds", {
  dfScores <- data.frame(fdr_corrected_pvalue_logp = c(2.326, 0.842))

  expect_equal(
    AddCTASTrigger(dfScores)$Trigger,
    c("Further Evaluation", "Watch List")
  )
})

test_that("AddCTASTrigger propagates NA scores", {
  dfScores <- data.frame(fdr_corrected_pvalue_logp = NA_real_)

  expect_true(is.na(AddCTASTrigger(dfScores)$Trigger))
})

test_that("AddCTASTrigger honours custom thresholds", {
  dfScores <- data.frame(fdr_corrected_pvalue_logp = c(3.0, 1.0))

  expect_equal(
    AddCTASTrigger(dfScores, dHigh = 5, dLow = 2)$Trigger,
    c("Watch List", "No Action")
  )
})

test_that("AddCTASTrigger rejects invalid thresholds", {
  dfScores <- data.frame(fdr_corrected_pvalue_logp = 1)

  expect_error(AddCTASTrigger(dfScores, dHigh = "a"), "single number")
  expect_error(AddCTASTrigger(dfScores, dHigh = c(1, 2)), "single number")
  expect_error(AddCTASTrigger(dfScores, dHigh = 1, dLow = 2), "must not be below")
})

# --- CountTriggered -----------------------------------------------------------

test_that("CountTriggered counts only the requested trigger", {
  dfCount <- MakeSiteScores() |>
    AddCTASTrigger() |>
    CountTriggered()

  # Regression guard for the `filter(trigger == trigger)` self-comparison
  # defect, which counts every timeseries instead of the triggered ones.
  expect_lt(sum(dfCount$N), nrow(MakeSiteScores()))
  expect_equal(dfCount$N[dfCount$site == "001"], 2L)
  expect_false("002" %in% dfCount$site)
})

test_that("CountTriggered can count other categories and group columns", {
  dfTrigger <- AddCTASTrigger(MakeSiteScores())

  expect_equal(
    CountTriggered(dfTrigger, strTrigger = "Watch List")$N,
    1L
  )
  expect_true(
    "country" %in% names(CountTriggered(dfTrigger, strGroupCol = "country"))
  )
})

# --- Summarize_CTAS -----------------------------------------------------------

test_that("Summarize_CTAS returns the Analysis_Analyzed contract", {
  dfAnalyzed <- Summarize_CTAS(MakeSiteScores(), strFeature = "average")

  expect_named(
    dfAnalyzed,
    c("GroupID", "GroupLevel", "Numerator", "Denominator", "Metric", "Score")
  )
  expect_equal(dfAnalyzed$GroupID, c("001", "002"))
  expect_true(all(dfAnalyzed$GroupLevel == "Site"))
})

test_that("Summarize_CTAS aggregates numerator, denominator, metric and score", {
  dfAnalyzed <- Summarize_CTAS(MakeSiteScores(), strFeature = "average")

  expect_equal(dfAnalyzed$Numerator, c(2, 0))
  expect_equal(dfAnalyzed$Denominator, c(3, 3))
  expect_equal(dfAnalyzed$Metric, c(2 / 3, 0))
  expect_equal(dfAnalyzed$Score, c(3.0, 1.0))
})

test_that("Summarize_CTAS filters to a single feature", {
  dfAnalyzed <- Summarize_CTAS(MakeSiteScores(), strFeature = "sd")

  expect_equal(dfAnalyzed$GroupID, "003")
  expect_equal(dfAnalyzed$Denominator, 1)
})

test_that("Summarize_CTAS retains groups with no evaluated timeseries", {
  dfAnalyzed <- Summarize_CTAS(
    MakeSiteScores(),
    strFeature = "average",
    vGroupIDs = c("001", "002", "003", "004")
  )

  expect_equal(dfAnalyzed$GroupID, c("001", "002", "003", "004"))
  expect_equal(dfAnalyzed$Denominator[3:4], c(0, 0))
  expect_equal(dfAnalyzed$Numerator[3:4], c(0, 0))
  expect_true(all(is.na(dfAnalyzed$Metric[3:4])))
  expect_true(all(is.na(dfAnalyzed$Score[3:4])))
})

test_that("Summarize_CTAS can aggregate at country level", {
  dfAnalyzed <- Summarize_CTAS(
    MakeSiteScores(),
    strFeature = "average",
    strGroupLevel = "Country"
  )

  expect_equal(dfAnalyzed$GroupID, "USA")
  expect_equal(dfAnalyzed$GroupLevel, "Country")
  expect_equal(dfAnalyzed$Denominator, 6)
  expect_equal(dfAnalyzed$Numerator, 2)
})

test_that("Summarize_CTAS honours custom thresholds", {
  dfAnalyzed <- Summarize_CTAS(
    MakeSiteScores(),
    strFeature = "average",
    dHigh = 0.9,
    dLow = 0.2
  )

  expect_equal(dfAnalyzed$Numerator, c(2, 1))
})

test_that("Summarize_CTAS returns an empty frame for an unknown feature", {
  dfAnalyzed <- Summarize_CTAS(MakeSiteScores(), strFeature = "nonesuch")

  expect_equal(nrow(dfAnalyzed), 0)
})

test_that("Summarize_CTAS validates its inputs", {
  expect_error(Summarize_CTAS("not a frame", "average"), "data.frame")
  expect_error(
    Summarize_CTAS(data.frame(site = "001"), "average"),
    "missing required column"
  )
  expect_error(
    Summarize_CTAS(MakeSiteScores(), strFeature = c("average", "sd")),
    "single string"
  )
  expect_error(
    Summarize_CTAS(MakeSiteScores(), "average", strGroupLevel = "Region"),
    "must be one of"
  )
})

test_that("Summarize_CTAS works on the cached CTAS fixture", {
  strFixture <- testthat::test_path("fixtures", "ctas_result.rds")
  skip_if_not(file.exists(strFixture), "CTAS fixture not built")

  lFixture <- readRDS(strFixture)
  dfScores <- lFixture$result$site_scores
  strFeature <- dfScores$feature[[1]]

  dfAnalyzed <- Summarize_CTAS(dfScores, strFeature = strFeature)

  expect_setequal(
    dfAnalyzed$GroupID,
    unique(as.character(dfScores$site[dfScores$feature == strFeature]))
  )
  expect_true(all(dfAnalyzed$Numerator <= dfAnalyzed$Denominator))
  expect_true(all(dfAnalyzed$Metric >= 0 & dfAnalyzed$Metric <= 1, na.rm = TRUE))
})

# --- Flag_CTAS ----------------------------------------------------------------

MakeAnalyzed <- function() {
  data.frame(
    GroupID = c("001", "002", "003", "004"),
    GroupLevel = "Site",
    Numerator = c(2, 1, 0, 0),
    Denominator = c(3, 3, 3, 0),
    Metric = c(2 / 3, 1 / 3, 0, NA),
    Score = c(3.0, 1.0, 0.1, NA)
  )
}

test_that("Flag_CTAS flags one-sided with no negative flags", {
  skip_if_not_installed("gsm.core")

  dfFlagged <- Flag_CTAS(MakeAnalyzed())

  expect_true(all(dfFlagged$Flag %in% c(0, 1, 2, NA)))
  expect_equal(dfFlagged$Flag[dfFlagged$GroupID == "001"], 2)
  expect_equal(dfFlagged$Flag[dfFlagged$GroupID == "002"], 1)
  expect_equal(dfFlagged$Flag[dfFlagged$GroupID == "003"], 0)
})

test_that("Flag_CTAS leaves unevaluated groups unflagged", {
  skip_if_not_installed("gsm.core")

  dfFlagged <- Flag_CTAS(MakeAnalyzed())

  expect_true(is.na(dfFlagged$Flag[dfFlagged$GroupID == "004"]))
})

test_that("Flag_CTAS preserves the Analysis_Analyzed columns and adds Flag", {
  skip_if_not_installed("gsm.core")

  dfFlagged <- Flag_CTAS(MakeAnalyzed())

  expect_true(all(names(MakeAnalyzed()) %in% names(dfFlagged)))
  expect_true("Flag" %in% names(dfFlagged))
  expect_equal(nrow(dfFlagged), 4)
})

test_that("Flag_CTAS sorts by flag severity", {
  skip_if_not_installed("gsm.core")

  dfFlagged <- Flag_CTAS(MakeAnalyzed())

  expect_equal(dfFlagged$Flag[1], 2)
})

test_that("Flag_CTAS honours custom thresholds", {
  skip_if_not_installed("gsm.core")

  dfFlagged <- Flag_CTAS(MakeAnalyzed(), vThreshold = c(0.05, 0.5))

  expect_equal(dfFlagged$Flag[dfFlagged$GroupID == "003"], 1)
})

test_that("Flag_CTAS validates its inputs", {
  expect_error(Flag_CTAS("not a frame"), "data.frame")
  expect_error(Flag_CTAS(MakeAnalyzed(), vThreshold = 1), "two numbers")
  expect_error(Flag_CTAS(MakeAnalyzed(), vThreshold = c(2, 1)), "ascending")
  expect_error(Flag_CTAS(MakeAnalyzed(), strColumn = "Nope"), "not found")
})
