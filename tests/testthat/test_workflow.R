test_that("the mapping layer runs CTAS once and shares its site scores", {
  expect_s3_class(lMapped$Mapped_CTAS_SiteScores, "data.frame")
  expect_true(all(
    c("site", "feature", "fdr_corrected_pvalue_logp") %in%
      names(lMapped$Mapped_CTAS_SiteScores)
  ))
  expect_gt(nrow(lMapped$Mapped_CTAS_SiteScores), 0)
})

test_that("the mapping layer produces the group metadata the report needs", {
  expect_setequal(names(lMapped$Mapped_SITE), c("GroupID", "Param", "Value", "GroupLevel"))
  expect_setequal(unique(lMapped$Mapped_SITE$GroupLevel), "Site")
  expect_setequal(unique(lMapped$Mapped_STUDY$GroupLevel), "Study")
  expect_setequal(unique(lMapped$Mapped_SITE$GroupID), unique(dmSmall$SITEID))
})

test_that("one metric workflow is produced per VS feature", {
  expect_setequal(
    names(lAnalysis),
    paste0("Analysis_ctas", c("0001", "0002", "0003", "0004"))
  )
})

test_that("each metric workflow returns the gsm lAnalysis contract", {
  purrr::walk(lAnalysis, function(lResult) {
    expect_setequal(
      names(lResult),
      c("ID", "Analysis_Analyzed", "Analysis_Flagged", "Analysis_Summary")
    )
    expect_true(all(
      c("GroupID", "GroupLevel", "Numerator", "Denominator", "Metric", "Score") %in%
        names(lResult$Analysis_Analyzed)
    ))
    expect_true("Flag" %in% names(lResult$Analysis_Flagged))
    expect_setequal(unique(lResult$Analysis_Analyzed$GroupLevel), "Site")
  })
})

test_that("Analysis_Input and Analysis_Transformed are deliberately absent", {
  # CTAS has no subject-level numerator/denominator; see PLAN.md 5a.
  purrr::walk(lAnalysis, function(lResult) {
    expect_false("Analysis_Input" %in% names(lResult))
    expect_false("Analysis_Transformed" %in% names(lResult))
  })
})

test_that("every site appears in every metric, evaluated or not", {
  vSiteIDs <- sort(unique(as.character(dmSmall$SITEID)))

  purrr::walk(lAnalysis, function(lResult) {
    expect_setequal(lResult$Analysis_Analyzed$GroupID, vSiteIDs)
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

test_that("workflow output matches a direct call to the R functions", {
  dfDirect <- Summarize_CTAS(
    lMapped$Mapped_CTAS_SiteScores,
    strFeature = "average",
    strGroupLevel = "Site",
    vGroupIDs = unique(lMapped$Mapped_SITE$GroupID)
  )

  expect_equal(
    dfDirect,
    dplyr::as_tibble(lAnalysis$Analysis_ctas0002$Analysis_Analyzed)
  )

  expect_equal(
    Flag_CTAS(dfDirect),
    lAnalysis$Analysis_ctas0002$Analysis_Flagged
  )
})

test_that("metric metadata is complete enough for gsm.reporting", {
  lMetricWorkflows <- workr::MakeWorkflowList(
    strNames = NULL,
    strPath = system.file("workflow/2_metrics", package = "gsm.ctas"),
    strPackage = NULL
  )

  dfMetrics <- gsm.reporting::MakeMetric(lWorkflows = lMetricWorkflows)

  expect_equal(nrow(dfMetrics), 4)
  expect_true(all(
    c("MetricID", "GroupLevel", "Metric", "Threshold", "AnalysisType") %in%
      names(dfMetrics)
  ))
  expect_setequal(dfMetrics$GroupLevel, "Site")
})
