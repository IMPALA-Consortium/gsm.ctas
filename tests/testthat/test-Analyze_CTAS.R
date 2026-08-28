MakeInput <- function(nSites = 3, nSubjectsPerSite = 4, nVisits = 5,
                      strStudy = "STUDY_A") {
  dfSubjects <- data.frame(
    studyid = character(0),
    subject_id = character(0), site = character(0),
    country = character(0), region = character(0)
  )
  dfData <- EmptyCTASData()

  for (iSite in seq_len(nSites)) {
    for (iSubject in seq_len(nSubjectsPerSite)) {
      strSubject <- paste0(strStudy, "_S", iSite, "_", iSubject)
      dfSubjects <- rbind(dfSubjects, data.frame(
        studyid = strStudy,
        subject_id = strSubject,
        site = paste0(strStudy, "_SITE", iSite),
        country = "USA",
        region = NA_character_
      ))
      dfData <- rbind(dfData, data.frame(
        subject_id = strSubject,
        parameter_id = "NUM_SYSBP",
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
        parameter_id = "NUM_SYSBP",
        parameter_name = "Systolic Blood Pressure",
        parameter_category_1 = "Vital Signs",
        parameter_category_2 = "NUM_SYSBP",
        parameter_category_3 = "numeric"
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

# --- feature toggles ----------------------------------------------------------

test_that("Analyze_CTAS aborts when every feature flag is FALSE", {
  lInput <- MakeInput()

  expect_error(
    Analyze_CTAS(
      lInput,
      bAutocorr = FALSE, bAverage = FALSE, bSD = FALSE, bRange = FALSE,
      bUniqueValueCountRelative = FALSE, bOwnSiteSimilScore = FALSE, bLOF = FALSE
    ),
    "At least one"
  )
})

test_that("Analyze_CTAS restricts scoring to the requested features", {
  lInput <- MakeInput()

  lAnalysis <- suppressWarnings(Analyze_CTAS(
    lInput,
    bAutocorr = FALSE, bAverage = TRUE, bSD = TRUE, bRange = FALSE,
    bUniqueValueCountRelative = FALSE,
    nSeed = 1
  ))

  expect_setequal(unique(lAnalysis$results$feature), c("average", "sd"))
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

test_that("Analyze_CTAS returns the ctasapp-shaped list", {
  lInput <- MakeInput()

  lAnalysis <- suppressWarnings(Analyze_CTAS(lInput, strID = "numeric", nSeed = 1))

  expect_named(lAnalysis, c("ID", "results", "input", "untransformed"))
  expect_equal(lAnalysis$ID, "numeric")
  expect_true(all(
    c("site", "feature", "fdr_corrected_pvalue_logp",
      "parameter_id", "parameter_category_1", "parameter_category_3") %in%
      names(lAnalysis$results)
  ))
  expect_true(all(
    c("subject_id", "parameter_id", "timepoint_1_name", "result", "site",
      "parameter_name", "parameter_category_1") %in%
      names(lAnalysis$input)
  ))
  expect_gt(nrow(lAnalysis$results), 0)
  expect_gt(nrow(lAnalysis$input), 0)
})

test_that("Analyze_CTAS is reproducible when nSeed is supplied", {
  lInput <- MakeInput()

  lFirst <- suppressWarnings(Analyze_CTAS(lInput, nSeed = 42))
  lSecond <- suppressWarnings(Analyze_CTAS(lInput, nSeed = 42))

  expect_equal(lFirst$results, lSecond$results)
})

# --- multi-study --------------------------------------------------------------

test_that("Analyze_CTAS tags every result frame with study on a single-study run", {
  lInput <- MakeInput(strStudy = "STUDY_A")

  lAnalysis <- suppressWarnings(Analyze_CTAS(lInput, nSeed = 1))

  expect_true("study" %in% names(lAnalysis$results))
  expect_true("study" %in% names(lAnalysis$input))
  expect_setequal(unique(lAnalysis$results$study), "STUDY_A")
})

test_that("Analyze_CTAS splits by studyid and stacks the flat frames", {
  lInputA <- MakeInput(strStudy = "STUDY_A")
  lInputB <- MakeInput(strStudy = "STUDY_B")

  lInput <- list(
    data = dplyr::bind_rows(lInputA$data, lInputB$data),
    subjects = dplyr::bind_rows(lInputA$subjects, lInputB$subjects),
    parameters = lInputA$parameters,
    custom_timeseries = lInputA$custom_timeseries,
    custom_reference_groups = lInputA$custom_reference_groups
  )

  lAnalysis <- suppressWarnings(Analyze_CTAS(lInput, nSeed = 1))

  expect_setequal(unique(lAnalysis$results$study), c("STUDY_A", "STUDY_B"))
  expect_setequal(
    unique(lAnalysis$results$site[lAnalysis$results$study == "STUDY_A"]),
    unique(lInputA$subjects$site)
  )
})

test_that("Analyze_CTAS setting strStudyCol NULL runs one call without splitting", {
  lInput <- MakeInput()
  lInput$subjects$studyid <- NULL

  lAnalysis <- suppressWarnings(Analyze_CTAS(lInput, nSeed = 1, strStudyCol = NULL))

  expect_false("study" %in% names(lAnalysis$results))
  expect_false("study" %in% names(lAnalysis$input))
})
