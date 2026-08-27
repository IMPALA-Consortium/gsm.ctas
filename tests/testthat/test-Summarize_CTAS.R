MakeSiteScores <- function() {
  dplyr::tibble(
    studyid = "STUDY_A",
    timeseries_id = c("ts1", "ts2", "ts3", "ts1", "ts2", "ts3", "ts1"),
    site = c("001", "001", "001", "002", "002", "002", "003"),
    country = c("USA", "USA", "USA", "USA", "USA", "USA", "DEU"),
    parameter_id = c(
      "NUM_SYSBP", "NUM_SYSBP", "NUM_SYSBP",
      "NUM_DIABP", "NUM_DIABP", "NUM_DIABP", "NUM_SYSBP"
    ),
    feature = c(rep("average", 6), "sd"),
    fdr_corrected_pvalue_logp = c(3.0, 2.5, 0.1, 1.0, 0.5, 0.0, 4.0)
  )
}

MakeTwoStudyScores <- function() {
  dfA <- MakeSiteScores()
  dfB <- MakeSiteScores()
  dfB$studyid <- "STUDY_B"
  dfB$site <- paste0("B_", dfB$site)
  dplyr::bind_rows(dfA, dfB)
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

test_that("Summarize_CTAS returns one row per (study, group, feature)", {
  dfAnalyzed <- Summarize_CTAS(MakeSiteScores())

  expect_named(dfAnalyzed, c(
    "studyid", "GroupID", "GroupLevel", "Feature",
    "Numerator", "Denominator", "Metric", "Score"
  ))
  # 1 study x 3 sites x 2 features = 6 rows.
  expect_equal(nrow(dfAnalyzed), 6)
  expect_setequal(unique(dfAnalyzed$Feature), c("average", "sd"))
})

test_that("Summarize_CTAS aggregates numerator, denominator, metric and score", {
  dfAnalyzed <- Summarize_CTAS(MakeSiteScores(), vFeatures = "average")

  dfAvg <- dplyr::filter(dfAnalyzed, .data$Feature == "average")
  dfAvg <- dfAvg[order(dfAvg$GroupID), ]

  expect_equal(dfAvg$GroupID, c("001", "002", "003"))
  # Site 003 has no "average" timeseries at all; Denominator is 0.
  expect_equal(dfAvg$Numerator, c(2, 0, 0))
  expect_equal(dfAvg$Denominator, c(3, 3, 0))
  expect_equal(dfAvg$Metric, c(2 / 3, 0, NA_real_))
  # No timeseries for 003 means no score; the left-join keeps it as NA.
  expect_equal(dfAvg$Score, c(3.0, 1.0, NA_real_))
})

test_that("Summarize_CTAS filters to the requested features", {
  dfAnalyzed <- Summarize_CTAS(MakeSiteScores(), vFeatures = "sd")

  # Only "sd" is retained; still one row per (site, "sd") in the grid.
  expect_setequal(unique(dfAnalyzed$Feature), "sd")
  dfSD003 <- dplyr::filter(dfAnalyzed, .data$GroupID == "003")
  expect_equal(dfSD003$Denominator, 1)
})

test_that("Summarize_CTAS retains groups with no evaluated timeseries", {
  dfAnalyzed <- Summarize_CTAS(
    MakeSiteScores(),
    vFeatures = "average",
    vGroupIDs = c("001", "002", "003", "004")
  )

  dfAvg <- dfAnalyzed[order(dfAnalyzed$GroupID), ]
  expect_equal(dfAvg$GroupID, c("001", "002", "003", "004"))
  # Neither 003 nor 004 has an "average" timeseries.
  expect_equal(dfAvg$Denominator[3:4], c(0, 0))
  expect_equal(dfAvg$Numerator[3:4], c(0, 0))
  expect_true(all(is.na(dfAvg$Metric[3:4])))
})

test_that("Summarize_CTAS can aggregate at country level", {
  dfAnalyzed <- Summarize_CTAS(
    MakeSiteScores(),
    vFeatures = "average",
    strGroupLevel = "Country"
  )

  dfAvg <- dplyr::filter(dfAnalyzed, .data$Feature == "average")
  # Both USA and DEU appear because Site 003 (DEU) has an "sd" timeseries but
  # no "average" - it is still surfaced with Denominator 0.
  expect_setequal(dfAvg$GroupID, c("USA", "DEU"))
  expect_equal(dfAvg$GroupLevel[1], "Country")
})

test_that("Summarize_CTAS honours custom thresholds", {
  dfAnalyzed <- Summarize_CTAS(
    MakeSiteScores(),
    vFeatures = "average",
    dHigh = 0.9,
    dLow = 0.2
  )

  dfAvg <- dfAnalyzed[order(dfAnalyzed$GroupID), ]
  expect_equal(dfAvg$Numerator[1:2], c(2, 1))
})

test_that("Summarize_CTAS returns an empty frame for an unknown feature", {
  dfAnalyzed <- Summarize_CTAS(MakeSiteScores(), vFeatures = "nonesuch")

  expect_equal(nrow(dfAnalyzed), 0)
})

test_that("Summarize_CTAS validates its inputs", {
  expect_error(Summarize_CTAS("not a frame"), "data.frame")
  expect_error(
    Summarize_CTAS(data.frame(site = "001")),
    "missing required column"
  )
  expect_error(
    Summarize_CTAS(MakeSiteScores(), vFeatures = 1),
    "character"
  )
  expect_error(
    Summarize_CTAS(MakeSiteScores(), strGroupLevel = "Region"),
    "must be one of"
  )
})

# --- Summarize_CTAS: multi-study ---------------------------------------------

test_that("Summarize_CTAS completes the grid per study when studyid is present", {
  dfAnalyzed <- Summarize_CTAS(MakeTwoStudyScores(), vFeatures = "average")

  expect_true("studyid" %in% names(dfAnalyzed))
  # 2 studies x 3 sites x 1 feature = 6 rows.
  expect_equal(nrow(dfAnalyzed), 6)
  expect_setequal(unique(dfAnalyzed$studyid), c("STUDY_A", "STUDY_B"))

  # Study A and B are otherwise identical, so their averages should agree.
  dfA <- dfAnalyzed[dfAnalyzed$studyid == "STUDY_A", ]
  dfB <- dfAnalyzed[dfAnalyzed$studyid == "STUDY_B", ]
  expect_equal(sum(dfA$Numerator), sum(dfB$Numerator))
})

test_that("Summarize_CTAS with strStudyCol = NULL collapses across studies", {
  dfAnalyzed <- Summarize_CTAS(
    MakeTwoStudyScores(),
    vFeatures = "average",
    strStudyCol = NULL
  )

  expect_false("studyid" %in% names(dfAnalyzed))
  # 3 sites x 1 feature - but sites are unique to each study, so 6 rows.
  expect_equal(nrow(dfAnalyzed), 6)
})

test_that("Summarize_CTAS works on the cached CTAS fixture", {
  strFixture <- testthat::test_path("fixtures", "ctas_result.rds")
  skip_if_not(file.exists(strFixture), "CTAS fixture not built")

  lFixture <- readRDS(strFixture)
  dfScores <- lFixture$result$site_scores

  dfAnalyzed <- Summarize_CTAS(dfScores)

  expect_true(all(dfAnalyzed$Numerator <= dfAnalyzed$Denominator))
  expect_true(all(dfAnalyzed$Metric >= 0 & dfAnalyzed$Metric <= 1, na.rm = TRUE))
})

# --- Flag_CTAS ----------------------------------------------------------------

MakeAnalyzed <- function() {
  data.frame(
    GroupID = c("001", "002", "003", "004"),
    GroupLevel = "Site",
    Feature = "average",
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
