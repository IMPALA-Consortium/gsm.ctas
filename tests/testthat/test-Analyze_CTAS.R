# Tests for Analyze_CTAS. The single-df API takes a long-format CTAS input
# frame and returns the flat `results` data frame directly. The metric YAML
# bundles that with `input` and `untransformed` via a `base::list` step.

MakeInput <- function(nSites = 3, nSubjectsPerSite = 4, nVisits = 5,
                      strStudy = "STUDY_A") {
  dfRows <- data.frame(
    studyid = character(0),
    subject_id = character(0),
    site = character(0),
    country = character(0),
    parameter_id = character(0),
    parameter_name = character(0),
    parameter_category_1 = character(0),
    parameter_category_2 = character(0),
    parameter_category_3 = character(0),
    timepoint_1_name = character(0),
    timepoint_2_name = character(0),
    timepoint_rank = numeric(0),
    result = numeric(0),
    baseline = numeric(0),
    stringsAsFactors = FALSE
  )

  for (iSite in seq_len(nSites)) {
    for (iSubject in seq_len(nSubjectsPerSite)) {
      strSubject <- paste0(strStudy, "_S", iSite, "_", iSubject)
      dfRows <- rbind(dfRows, data.frame(
        studyid = strStudy,
        subject_id = strSubject,
        site = paste0(strStudy, "_SITE", iSite),
        country = "USA",
        parameter_id = "SYSBP",
        parameter_name = "Systolic Blood Pressure",
        parameter_category_1 = "Vital Signs",
        parameter_category_2 = "SYSBP",
        parameter_category_3 = "numeric",
        timepoint_1_name = paste("VISIT", seq_len(nVisits)),
        timepoint_2_name = NA_character_,
        timepoint_rank = as.numeric(seq_len(nVisits)),
        result = 120 + iSite + stats::rnorm(nVisits),
        baseline = NA_real_,
        stringsAsFactors = FALSE
      ))
    }
  }

  dfRows
}

# --- input validation --------------------------------------------------------

test_that("Analyze_CTAS rejects objects that are not a data.frame", {
  expect_error(Analyze_CTAS(list(a = 1)), "must be a")
})

test_that("Analyze_CTAS errors informatively on missing columns", {
  expect_error(Analyze_CTAS(data.frame(a = 1)), "missing required column")
})

test_that("Analyze_CTAS errors on empty data", {
  df <- MakeInput()[0, ]
  expect_error(Analyze_CTAS(df), "no rows")
})

test_that("Analyze_CTAS errors when fewer than two sites are present", {
  df <- MakeInput(nSites = 1)

  expect_error(Analyze_CTAS(df), "at least 2 sites")
})

test_that("Analyze_CTAS validates the scoring method", {
  df <- MakeInput()

  expect_error(Analyze_CTAS(df, strScoringMethod = "nonsense"), "must be one of")
})

# --- feature toggles ---------------------------------------------------------

test_that("Analyze_CTAS aborts when every feature flag is FALSE", {
  df <- MakeInput()

  expect_error(
    Analyze_CTAS(
      df,
      bAutocorr = FALSE, bAverage = FALSE, bSD = FALSE, bRange = FALSE,
      bUniqueValueCountRelative = FALSE, bOwnSiteSimilScore = FALSE, bLOF = FALSE
    ),
    "At least one"
  )
})

test_that("Analyze_CTAS restricts scoring to the requested features", {
  df <- MakeInput()

  dfResults <- suppressWarnings(Analyze_CTAS(
    df,
    bAutocorr = FALSE, bAverage = TRUE, bSD = TRUE, bRange = FALSE,
    bUniqueValueCountRelative = FALSE,
    nSeed = 1
  ))

  expect_setequal(unique(dfResults$feature), c("average", "sd"))
})

# --- degenerate results ------------------------------------------------------

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
  df <- MakeInput(nVisits = 5)

  expect_error(
    Analyze_CTAS(df, nMinTimepoints = 99),
    "no timeseries features|no site scores"
  )
})

# --- successful run ----------------------------------------------------------

test_that("Analyze_CTAS returns the flat results data.frame", {
  df <- MakeInput()

  dfResults <- suppressWarnings(Analyze_CTAS(df, nSeed = 1))

  expect_s3_class(dfResults, "data.frame")
  expect_true(all(
    c("site", "feature", "fdr_corrected_pvalue_logp",
      "parameter_id", "parameter_category_1", "parameter_category_3") %in%
      names(dfResults)
  ))
  expect_gt(nrow(dfResults), 0)
})

test_that("Analyze_CTAS is reproducible when nSeed is supplied", {
  df <- MakeInput()

  dfFirst <- suppressWarnings(Analyze_CTAS(df, nSeed = 42))
  dfSecond <- suppressWarnings(Analyze_CTAS(df, nSeed = 42))

  expect_equal(dfFirst, dfSecond)
})

# --- multi-study -------------------------------------------------------------

test_that("Analyze_CTAS tags results with study on a single-study run", {
  df <- MakeInput(strStudy = "STUDY_A")

  dfResults <- suppressWarnings(Analyze_CTAS(df, nSeed = 1))

  expect_true("study" %in% names(dfResults))
  expect_setequal(unique(dfResults$study), "STUDY_A")
})

test_that("Analyze_CTAS splits by studyid and stacks the flat frames", {
  dfA <- MakeInput(strStudy = "STUDY_A")
  dfB <- MakeInput(strStudy = "STUDY_B")
  df <- rbind(dfA, dfB)

  dfResults <- suppressWarnings(Analyze_CTAS(df, nSeed = 1))

  expect_setequal(unique(dfResults$study), c("STUDY_A", "STUDY_B"))
  expect_setequal(
    unique(dfResults$site[dfResults$study == "STUDY_A"]),
    unique(dfA$site)
  )
})

test_that("Analyze_CTAS setting strStudyCol NULL runs one call without splitting", {
  df <- MakeInput()
  df$studyid <- NULL

  dfResults <- suppressWarnings(Analyze_CTAS(df, nSeed = 1, strStudyCol = NULL))

  expect_false("study" %in% names(dfResults))
})
