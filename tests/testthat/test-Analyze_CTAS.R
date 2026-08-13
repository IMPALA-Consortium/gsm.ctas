MakeInput <- function(nSites = 3, nSubjectsPerSite = 4, nVisits = 5) {
  dfSubjects <- data.frame(
    subject_id = character(0), site = character(0),
    country = character(0), region = character(0)
  )
  dfData <- EmptyCTASData()

  for (iSite in seq_len(nSites)) {
    for (iSubject in seq_len(nSubjectsPerSite)) {
      strSubject <- paste0("S", iSite, "_", iSubject)
      dfSubjects <- rbind(dfSubjects, data.frame(
        subject_id = strSubject,
        site = paste0("SITE", iSite),
        country = "USA",
        region = NA_character_
      ))
      dfData <- rbind(dfData, data.frame(
        subject_id = strSubject,
        parameter_id = "VS_SYSBP",
        timepoint_1_name = paste("VISIT", seq_len(nVisits)),
        timepoint_2_name = NA_character_,
        timepoint_rank = as.numeric(seq_len(nVisits)),
        result = 120 + iSite + stats::rnorm(nVisits),
        baseline = NA_real_
      ))
    }
  }

  lInput <- Combine_CTAS_Input(
    list(
      data = dfData,
      parameters = data.frame(
        parameter_id = "VS_SYSBP",
        parameter_name = "Systolic Blood Pressure",
        parameter_category_1 = "VS",
        parameter_category_2 = "SYSBP",
        parameter_category_3 = NA_character_
      )
    ),
    dfSubjects = dfSubjects
  )

  lInput
}

# --- input validation ---------------------------------------------------------

test_that("Analyze_CTAS rejects objects that are not a Combine_CTAS_Input list", {
  expect_error(Analyze_CTAS(data.frame(a = 1)), "must be a list")
  expect_error(Analyze_CTAS(list(data = data.frame())), "missing required element")
})

test_that("Analyze_CTAS rejects non-data.frame elements", {
  lInput <- MakeInput()
  lInput$parameters <- "not a data frame"

  expect_error(Analyze_CTAS(lInput), "must be")
})

test_that("Analyze_CTAS errors on empty data or parameters", {
  lInput <- MakeInput()

  lEmptyData <- lInput
  lEmptyData$data <- EmptyCTASData()
  expect_error(Analyze_CTAS(lEmptyData), "no rows")

  lEmptyParams <- lInput
  lEmptyParams$parameters <- lInput$parameters[0, ]
  expect_error(Analyze_CTAS(lEmptyParams), "no rows")
})

test_that("Analyze_CTAS errors when fewer than two sites are present", {
  lInput <- MakeInput(nSites = 1)

  expect_error(Analyze_CTAS(lInput), "at least 2 sites")
})

test_that("Analyze_CTAS validates the scoring method", {
  lInput <- MakeInput()

  expect_error(Analyze_CTAS(lInput, strScoringMethod = "nonsense"), "must be one of")
})

# --- degenerate results -------------------------------------------------------

test_that("AssertCTASResult turns NULL CTAS output into an informative error", {
  expect_error(
    AssertCTASResult(list(
      timeseries = NULL, timeseries_features = NULL,
      PCA_coordinates = NULL, site_scores = NULL
    )),
    "no timeseries features"
  )

  expect_error(
    AssertCTASResult(list(
      timeseries_features = data.frame(a = 1),
      site_scores = NULL
    )),
    "no site scores"
  )
})

test_that("Analyze_CTAS errors informatively when no timeseries can be built", {
  lInput <- MakeInput(nVisits = 5)

  expect_error(
    Analyze_CTAS(lInput, nMinTimepoints = 99),
    "no timeseries features|no site scores"
  )
})

# --- successful run -----------------------------------------------------------

test_that("Analyze_CTAS returns the four CTAS result frames", {
  lInput <- MakeInput()

  lCTAS <- suppressWarnings(Analyze_CTAS(lInput, nSeed = 1))

  expect_named(
    lCTAS,
    c("timeseries", "timeseries_features", "PCA_coordinates", "site_scores")
  )
  expect_true(all(
    c("timeseries_id", "site", "feature", "fdr_corrected_pvalue_logp") %in%
      names(lCTAS$site_scores)
  ))
  expect_gt(nrow(lCTAS$site_scores), 0)
})

test_that("Analyze_CTAS is reproducible when nSeed is supplied", {
  lInput <- MakeInput()

  lFirst <- suppressWarnings(Analyze_CTAS(lInput, nSeed = 42))
  lSecond <- suppressWarnings(Analyze_CTAS(lInput, nSeed = 42))

  expect_equal(lFirst$site_scores, lSecond$site_scores)
})

test_that("Analyze_CTAS restricts scoring to the requested features", {
  lInput <- MakeInput()

  lCTAS <- suppressWarnings(Analyze_CTAS(lInput, strFeatures = "average;sd", nSeed = 1))

  expect_setequal(unique(lCTAS$timeseries_features$feature), c("average", "sd"))
})

# --- cached fixture -----------------------------------------------------------

test_that("the cached CTAS fixture is available for downstream work packages", {
  strFixture <- testthat::test_path("fixtures", "ctas_result.rds")
  skip_if_not(file.exists(strFixture), "CTAS fixture not built")

  lFixture <- readRDS(strFixture)

  expect_named(lFixture, c("input", "result"))
  expect_true(all(
    c("timeseries_id", "site", "feature", "fdr_corrected_pvalue_logp") %in%
      names(lFixture$result$site_scores)
  ))
  expect_gt(dplyr::n_distinct(lFixture$result$site_scores$site), 1)
})
