skip_if_not(
  isTRUE(bWorkflowRunnable),
  "Workflow packages (workr / gsm.core / gsm.mapping / pharmaversesdtm) not installed."
)

test_that("mapping publishes the standardised transformation-typed frames", {
  expect_true(all(
    c("Mapped_DM", "Mapped_VS", "Mapped_LB", "Mapped_SITE", "Mapped_STUDY",
      "Mapped_Subjects", "Mapped_Numeric", "Mapped_Range") %in% names(lMapped)
  ))
})

test_that("mapping filters unscheduled visits from VS and LB", {
  expect_false(any(grepl("UNSCH", lMapped$Mapped_VS$VISIT, ignore.case = TRUE)))
  expect_false(any(grepl("UNSCH", lMapped$Mapped_LB$VISIT, ignore.case = TRUE)))
})

test_that("Mapped_Subjects carries the CTAS column vocabulary and every study", {
  expect_true(all(
    c("studyid", "subject_id", "site", "country") %in% names(lMapped$Mapped_Subjects)
  ))
  expect_setequal(unique(lMapped$Mapped_Subjects$studyid), vStudyIDs)
})

test_that("Mapped_Numeric and Mapped_Range carry studyid + parameter_category_1", {
  expect_true(all(
    c("studyid", "subject_id", "parameter_id", "parameter_name",
      "parameter_category_1", "visit", "visitnum", "value") %in%
      names(lMapped$Mapped_Numeric)
  ))
  expect_true(all(
    c("low", "high") %in% names(lMapped$Mapped_Range)
  ))
  expect_setequal(unique(lMapped$Mapped_Numeric$studyid), vStudyIDs)
  expect_setequal(unique(lMapped$Mapped_Range$studyid), vStudyIDs)
  expect_setequal(unique(lMapped$Mapped_Numeric$parameter_category_1), "Vital Signs")
  expect_setequal(unique(lMapped$Mapped_Range$parameter_category_1), "Labs")
})

test_that("Mapped_SITE groups by STUDYID and SITEID so cloned sites stay separated", {
  expect_setequal(names(lMapped$Mapped_SITE), c("GroupID", "Param", "Value", "GroupLevel"))
  expect_setequal(unique(lMapped$Mapped_SITE$GroupID), unique(dmSmall$SITEID))
})

test_that("one metric workflow is produced per transformation type", {
  expect_setequal(names(lAnalysis), paste0("Analysis_", vMetricIDs))
})

test_that("each metric emits Analysis_Analyzed with a Feature column per feature", {
  purrr::iwalk(lAnalysis, function(lResult, strID) {
    dfAnalyzed <- lResult$Analysis_Analyzed
    expect_true(all(
      c("studyid", "GroupID", "GroupLevel", "Feature",
        "Numerator", "Denominator", "Metric", "Score") %in%
        names(dfAnalyzed)
    ))
    expect_gt(length(unique(dfAnalyzed$Feature)), 0)
    expect_setequal(unique(dfAnalyzed$studyid), vStudyIDs)
    expect_setequal(unique(dfAnalyzed$GroupLevel), "Site")
  })
})

test_that("each metric workflow returns the gsm lAnalysis contract", {
  purrr::walk(lAnalysis, function(lResult) {
    expect_setequal(
      names(lResult),
      c("ID", "Analysis_Analyzed", "Analysis_Flagged", "Analysis_Summary")
    )
    expect_true("Flag" %in% names(lResult$Analysis_Flagged))
  })
})

test_that("Analysis_Input and Analysis_Transformed are deliberately absent", {
  purrr::walk(lAnalysis, function(lResult) {
    expect_false("Analysis_Input" %in% names(lResult))
    expect_false("Analysis_Transformed" %in% names(lResult))
  })
})

test_that("every site appears in every metric feature for every study", {
  vSiteIDs <- sort(unique(as.character(dmSmall$SITEID)))

  purrr::walk(lAnalysis, function(lResult) {
    dfAnalyzed <- lResult$Analysis_Analyzed
    vFeatures <- unique(dfAnalyzed$Feature)
    expect_setequal(
      unique(paste(dfAnalyzed$studyid, dfAnalyzed$GroupID)),
      as.vector(outer(vStudyIDs, vSiteIDs, paste))
    )
    # Every (study, site) is present for every feature.
    expect_equal(
      nrow(dfAnalyzed),
      length(vFeatures) * length(vSiteIDs) * length(vStudyIDs)
    )
  })
})

test_that("flagging is one-sided and unevaluated groups stay NA", {
  purrr::walk(lAnalysis, function(lResult) {
    vFlag <- lResult$Analysis_Flagged$Flag
    expect_true(all(vFlag %in% c(0, 1, 2, NA)))
    expect_equal(
      is.na(vFlag),
      is.na(lResult$Analysis_Flagged$Score)
    )
  })
})

test_that("ratio_missing metric drops the autocorr feature", {
  # Autocorrelation of a monotonic running ratio carries no additional signal,
  # so the ratio_missing YAML deliberately omits it.
  expect_false(
    "autocorr" %in% unique(lAnalysis$Analysis_ratio_missing$Analysis_Analyzed$Feature)
  )
})

test_that("metric metadata is complete enough for gsm.reporting", {
  skip_if_not_installed("gsm.reporting")

  dfMetrics <- gsm.reporting::MakeMetric(lWorkflows = lMetricWorkflows)

  expect_equal(nrow(dfMetrics), length(vMetricIDs))
  expect_true(all(
    c("MetricID", "GroupLevel", "Metric", "Threshold", "AnalysisType") %in%
      names(dfMetrics)
  ))
  expect_setequal(dfMetrics$GroupLevel, "Site")
  expect_length(unique(dfMetrics$Metric), length(vMetricIDs))
  expect_length(unique(dfMetrics$Abbreviation), length(vMetricIDs))
})
