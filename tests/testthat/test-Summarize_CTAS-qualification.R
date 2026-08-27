# Qualification test (double programming) for the CTAS -> gsm aggregation.
#
# This test compares `Summarize_CTAS()` against timeseries-level results
# produced by an independent, pre-existing CTAS implementation.
#
# The reference file is confidential and is NOT part of this repository. The
# test is opt-in: set the environment variable below to the path of a
# reference workbook to enable it. Without it, the file skips.
#
#   Sys.setenv(GSM_CTAS_QUALIFICATION_FILE = "<path to reference .xlsx>")
#
# The reference is expected to be timeseries-level: one row per
# (timeseries x feature x group), carrying a `fdr_corrected_pvalue_logp`
# score and the reference implementation's own `trigger` classification.
# That makes it an independent check of both the trigger cut points and the
# group-level collapse.

ReadReference <- function() {
  strPath <- Sys.getenv("GSM_CTAS_QUALIFICATION_FILE", unset = "")

  skip_if(
    strPath == "",
    "Set GSM_CTAS_QUALIFICATION_FILE to run the qualification test."
  )
  skip_if_not_installed("readxl")

  # Deliberately NOT a skip: if a reference is configured but unreadable,
  # that is a failure, not an absence.
  expect_true(file.exists(strPath))

  dfRef <- readxl::read_excel(strPath)
  names(dfRef) <- tolower(names(dfRef))

  # Also not a skip: a configured reference with the wrong shape means the
  # test is not testing what it claims to.
  expect_true(
    all(c("site", "feature", "trigger", "fdr_corrected_pvalue_logp") %in%
      names(dfRef))
  )

  dfRef
}

# Independent re-derivation of the group-level aggregate, written directly
# against the reference's own `trigger` column rather than reusing any
# gsm.ctas code.
SummarizeReference <- function(dfRef, strFeature) {
  dfRef |>
    dplyr::filter(.data$feature == .env$strFeature) |>
    dplyr::mutate(GroupID = as.character(.data$site)) |>
    dplyr::summarise(
      Numerator = sum(.data$trigger == "Further Evaluation", na.rm = TRUE),
      Denominator = dplyr::n(),
      Score = max(.data$fdr_corrected_pvalue_logp, na.rm = TRUE),
      .by = "GroupID"
    ) |>
    dplyr::arrange(.data$GroupID) |>
    dplyr::mutate(
      Numerator = as.numeric(.data$Numerator),
      Denominator = as.numeric(.data$Denominator)
    )
}

test_that("AddCTASTrigger reproduces the reference trigger classification", {
  dfRef <- ReadReference()

  expect_identical(AddCTASTrigger(dfRef)$Trigger, dfRef$trigger)
})

test_that("Summarize_CTAS reproduces the reference group scores", {
  dfRef <- ReadReference()

  for (strFeature in unique(dfRef$feature)) {
    dfActual <- Summarize_CTAS(
      dfRef,
      vFeatures = strFeature,
      strStudyCol = NULL
    )
    dfActual <- dfActual[order(dfActual$GroupID), ]
    dfExpected <- SummarizeReference(dfRef, strFeature)

    expect_identical(dfActual$GroupID, dfExpected$GroupID, info = strFeature)
    expect_equal(
      dfActual$Score, dfExpected$Score,
      tolerance = 1e-8, info = strFeature
    )
    expect_equal(dfActual$Numerator, dfExpected$Numerator, info = strFeature)
    expect_equal(
      dfActual$Denominator, dfExpected$Denominator,
      info = strFeature
    )
    expect_equal(
      dfActual$Metric,
      dfExpected$Numerator / dfExpected$Denominator,
      tolerance = 1e-8, info = strFeature
    )
  }
})

test_that("CountTriggered avoids the reference self-comparison defect", {
  dfRef <- ReadReference()
  dfTrigger <- AddCTASTrigger(dfRef)

  # The reference `filter(trigger == trigger)` was always TRUE, so its
  # per-group counts collapsed to the total timeseries count for the group.
  dfCorrect <- CountTriggered(dfTrigger, strTrigger = "Further Evaluation")
  dfBuggy <- dfTrigger |>
    dplyr::summarise(N = dplyr::n(), .by = "site")

  expect_false(isTRUE(all.equal(dfCorrect$N, dfBuggy$N)))
})
