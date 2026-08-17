MakeDetailInput <- function() {
  Combine_CTAS_Input(
    Input_Numeric(data.frame(
      USUBJID = c("S1", "S1", "S2", "S2"),
      VSTESTCD = "SYSBP",
      VSTEST = "Systolic Blood Pressure",
      VISIT = c("WEEK 2", "WEEK 4", "WEEK 2", "WEEK 4"),
      VISITNUM = c(3, 4, 3, 4),
      VSSTRESN = c(120, 122, 130, 128)
    )),
    Input_Range(data.frame(
      USUBJID = c("S1", "S2"),
      LBTESTCD = "ALT",
      LBTEST = "Alanine Aminotransferase",
      VISIT = "WEEK 2",
      VISITNUM = 3,
      LBSTRESN = c(20, 35),
      LBSTNRLO = 10,
      LBSTNRHI = 40
    )),
    dfSubjects = Input_Subjects(data.frame(
      USUBJID = c("S1", "S2"),
      SITEID = c("701", "702"),
      COUNTRY = "USA"
    ))
  )
}

MakeDetailScores <- function() {
  data.frame(
    timeseries_id = c("ts1", "ts2"),
    site = c("701", "702"),
    feature = "average",
    parameter_id = c("VS_SYSBP", "LB_NORM_ALT"),
    fdr_corrected_pvalue_logp = c(3.0, 0.5),
    stringsAsFactors = FALSE
  )
}

# --- input validation ---------------------------------------------------------

test_that("Combine_CTAS_Detail requires the ctasapp results contract", {
  lInput <- MakeDetailInput()
  dfScores <- MakeDetailScores()

  expect_error(
    Combine_CTAS_Detail(dfScores[, c("site", "feature")], lInput),
    "missing required column"
  )
})

test_that("Combine_CTAS_Detail rejects a malformed lInput", {
  dfScores <- MakeDetailScores()

  expect_error(Combine_CTAS_Detail(dfScores, data.frame(a = 1)), "must be a list")
  expect_error(
    Combine_CTAS_Detail(dfScores, list(data = data.frame())),
    "missing required element"
  )
})

test_that("Combine_CTAS_Detail rejects a non-scalar strStudyID", {
  expect_error(
    Combine_CTAS_Detail(MakeDetailScores(), MakeDetailInput(), c("A", "B")),
    "single string"
  )
})

test_that("Combine_CTAS_Detail aborts on a measurement with no subject", {
  lInput <- MakeDetailInput()
  lInput$subjects <- lInput$subjects[lInput$subjects$subject_id != "S2", ]

  expect_error(
    Combine_CTAS_Detail(MakeDetailScores(), lInput),
    "has no match"
  )
})

# --- structure ----------------------------------------------------------------

test_that("Combine_CTAS_Detail returns the three ctasapp frames", {
  lDetail <- Combine_CTAS_Detail(MakeDetailScores(), MakeDetailInput())

  expect_named(lDetail, c("Results", "Input", "Untransformed"))
  expect_true(all(vapply(lDetail, is.data.frame, logical(1))))
})

test_that("Results satisfies the ctasapp mandatory contract", {
  lDetail <- Combine_CTAS_Detail(MakeDetailScores(), MakeDetailInput())

  expect_true(all(
    c("site", "timeseries_id", "parameter_id", "feature",
      "fdr_corrected_pvalue_logp") %in% names(lDetail$Results)
  ))
})

test_that("Input carries the join keys and labels ctasapp needs", {
  lDetail <- Combine_CTAS_Detail(MakeDetailScores(), MakeDetailInput())

  expect_true(all(
    c("subject_id", "site", "parameter_id", "parameter_name",
      "parameter_category_3", "timepoint_1_name", "timepoint_rank",
      "result") %in% names(lDetail$Input)
  ))
})

test_that("Input keeps every measurement, one row per subject/param/timepoint", {
  lInput <- MakeDetailInput()
  lDetail <- Combine_CTAS_Detail(MakeDetailScores(), lInput)

  expect_equal(nrow(lDetail$Input), nrow(lInput$data))
  expect_false(anyNA(lDetail$Input$site))
  expect_false(anyNA(lDetail$Input$parameter_name))
})

test_that("Untransformed carries the pre-transformation values", {
  lDetail <- Combine_CTAS_Detail(MakeDetailScores(), MakeDetailInput())

  # Every mapped row appears, but only Input_Range() fills the bounds - which
  # is the point of the frame: the dashboard shows the lab result in its
  # original units next to the range-normalised value actually analysed.
  expect_equal(nrow(lDetail$Untransformed), 6)
  expect_true(all(c(20, 35) %in% lDetail$Untransformed$original_value))
  expect_equal(sum(!is.na(lDetail$Untransformed$lower)), 2)
})

test_that("Untransformed is an empty frame when no domain records originals", {
  lInput <- MakeDetailInput()
  lInput$untransformed <- NULL

  lDetail <- Combine_CTAS_Detail(MakeDetailScores(), lInput)

  expect_equal(nrow(lDetail$Untransformed), 0)
  expect_true("original_value" %in% names(lDetail$Untransformed))
})

test_that("strStudyID labels Results and Input but not Untransformed", {
  lDetail <- Combine_CTAS_Detail(
    MakeDetailScores(), MakeDetailInput(),
    strStudyID = "STUDY-001"
  )

  expect_true(all(lDetail$Results$study == "STUDY-001"))
  expect_true(all(lDetail$Input$study == "STUDY-001"))
  expect_false("study" %in% names(lDetail$Untransformed))
})

test_that("no study column is added by default", {
  lDetail <- Combine_CTAS_Detail(MakeDetailScores(), MakeDetailInput())

  expect_false("study" %in% names(lDetail$Results))
  expect_false("study" %in% names(lDetail$Input))
})

# --- drill-down path ----------------------------------------------------------

test_that("a flagged group can be traced to its timeseries and parameters", {
  lInput <- MakeDetailInput()
  dfScores <- MakeDetailScores()
  lDetail <- Combine_CTAS_Detail(dfScores, lInput)

  # This is the whole point of WP8: Summarize_CTAS() reports site 701 as
  # flagged, and the detail object must say which parameter caused it.
  dfAnalyzed <- Summarize_CTAS(dfScores, strFeature = "average")
  strGroup <- dfAnalyzed$GroupID[which.max(dfAnalyzed$Score)]

  dfHits <- lDetail$Results[lDetail$Results$site == strGroup, ]

  expect_equal(strGroup, "701")
  expect_equal(dfHits$parameter_id, "VS_SYSBP")
  expect_true(all(dfHits$parameter_id %in% lDetail$Input$parameter_id))
})

# --- Write_CTAS_Detail --------------------------------------------------------

test_that("Write_CTAS_Detail writes the files ctasapp reads", {
  lDetail <- Combine_CTAS_Detail(MakeDetailScores(), MakeDetailInput())
  strPath <- withr::local_tempdir()

  vPaths <- Write_CTAS_Detail(lDetail, strPath)

  expect_setequal(
    basename(vPaths),
    c("results.csv", "input.csv", "untransformed.csv")
  )
  expect_true(all(file.exists(vPaths)))
})

test_that("Write_CTAS_Detail round-trips the results contract", {
  lDetail <- Combine_CTAS_Detail(MakeDetailScores(), MakeDetailInput())
  strPath <- withr::local_tempdir()

  Write_CTAS_Detail(lDetail, strPath)
  dfResults <- utils::read.csv(file.path(strPath, "results.csv"))

  expect_true(all(
    c("site", "timeseries_id", "parameter_id", "feature",
      "fdr_corrected_pvalue_logp") %in% names(dfResults)
  ))
  expect_equal(nrow(dfResults), nrow(lDetail$Results))
})

test_that("Write_CTAS_Detail omits an empty untransformed file", {
  lInput <- MakeDetailInput()
  lInput$untransformed <- NULL
  lDetail <- Combine_CTAS_Detail(MakeDetailScores(), lInput)
  strPath <- withr::local_tempdir()

  vPaths <- Write_CTAS_Detail(lDetail, strPath)

  expect_setequal(basename(vPaths), c("results.csv", "input.csv"))
})

test_that("Write_CTAS_Detail creates the directory when absent", {
  lDetail <- Combine_CTAS_Detail(MakeDetailScores(), MakeDetailInput())
  strPath <- file.path(withr::local_tempdir(), "detail")

  Write_CTAS_Detail(lDetail, strPath)

  expect_true(dir.exists(strPath))
})

test_that("Write_CTAS_Detail validates its arguments", {
  lDetail <- Combine_CTAS_Detail(MakeDetailScores(), MakeDetailInput())
  strPath <- withr::local_tempdir()

  expect_error(Write_CTAS_Detail(list(Results = 1), strPath), "must be a list")
  expect_error(Write_CTAS_Detail(lDetail, c(strPath, strPath)), "single directory")
  expect_error(Write_CTAS_Detail(lDetail, strPath, "xlsx"), "must be one of")
})
