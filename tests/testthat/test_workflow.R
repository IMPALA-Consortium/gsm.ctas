test_that("the mapping layer runs CTAS once and shares its site scores", {
  expect_s3_class(lMapped$Mapped_CTAS_SiteScores, "data.frame")
  expect_true(all(
    c("site", "parameter_id", "feature", "fdr_corrected_pvalue_logp") %in%
      names(lMapped$Mapped_CTAS_SiteScores)
  ))
  expect_gt(nrow(lMapped$Mapped_CTAS_SiteScores), 0)
})

test_that("one CTAS run covers all three parameter families", {
  # VS values, labs normalised by reference range, and lab missingness. The last
  # two come from the same LB domain, mapped twice, because value deviation and
  # completeness deviation are different questions.
  vPrefix <- unique(sub("_[^_]+$", "", lMapped$Mapped_CTAS_SiteScores$parameter_id))

  expect_setequal(vPrefix, c("VS", "LB_NORM", "LB_MISS"))
})

test_that("the mapping layer produces the group metadata the report needs", {
  expect_setequal(names(lMapped$Mapped_SITE), c("GroupID", "Param", "Value", "GroupLevel"))
  expect_setequal(unique(lMapped$Mapped_SITE$GroupLevel), "Site")
  expect_setequal(unique(lMapped$Mapped_STUDY$GroupLevel), "Study")
  expect_setequal(unique(lMapped$Mapped_SITE$GroupID), unique(dmSmall$SITEID))
})

test_that("one metric workflow is produced per domain and feature", {
  # VS and range-normalised labs get all four features; lab missingness gets
  # three, because `autocorr` is not returned for those timeseries.
  expect_setequal(names(lAnalysis), paste0("Analysis_", vMetricIDs))
})

test_that("each metric selects only its own parameter family", {
  lFamily <- list(
    ctas0001 = c("Vital Signs", "numeric"), ctas0002 = c("Vital Signs", "numeric"),
    ctas0003 = c("Vital Signs", "numeric"), ctas0004 = c("Vital Signs", "numeric"),
    ctas0005 = c("Labs", "range_normalized"), ctas0006 = c("Labs", "range_normalized"),
    ctas0007 = c("Labs", "range_normalized"), ctas0008 = c("Labs", "range_normalized"),
    ctas0009 = c("Labs", "ratio_missing"), ctas0010 = c("Labs", "ratio_missing"),
    ctas0011 = c("Labs", "ratio_missing")
  )

  purrr::iwalk(lFamily, function(vFamily, strID) {
    lWorkflow <- lMetricWorkflows[[strID]]
    expect_equal(lWorkflow$meta$Domain, vFamily[1])
    expect_equal(lWorkflow$meta$Transformation, vFamily[2])

    # A denominator equal to the timeseries count of that family alone is what
    # shows the filter took effect: without it every metric would see all 15.
    nExpected <- lMapped$Mapped_CTAS_SiteScores |>
      dplyr::filter(
        .data$parameter_category_1 == vFamily[1],
        .data$parameter_category_3 == vFamily[2],
        .data$feature == lWorkflow$meta$Feature,
        .data$site == lMapped$Mapped_SITE$GroupID[1]
      ) |>
      nrow()

    dfAnalyzed <- lAnalysis[[paste0("Analysis_", strID)]]$Analysis_Analyzed
    expect_equal(
      dfAnalyzed$Denominator[dfAnalyzed$GroupID == lMapped$Mapped_SITE$GroupID[1]],
      nExpected
    )
    expect_gt(nExpected, 0)
  })
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
  # CTAS scores a site as a whole against the rest of the study, so there is no
  # subject-level numerator/denominator and nothing to transform.
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
    strDomain = "Vital Signs",
    strTransformation = "numeric",
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

test_that("the same feature gives different results per parameter family", {
  # If it did not, the parameter filter would be doing nothing and the LB
  # metrics would be duplicates of the VS ones.
  dfVS <- lAnalysis$Analysis_ctas0002$Analysis_Analyzed
  dfLBNorm <- lAnalysis$Analysis_ctas0006$Analysis_Analyzed
  dfLBMiss <- lAnalysis$Analysis_ctas0009$Analysis_Analyzed

  expect_false(isTRUE(all.equal(dfVS$Score, dfLBNorm$Score)))
  expect_false(isTRUE(all.equal(dfVS$Score, dfLBMiss$Score)))
})

test_that("metric metadata is complete enough for gsm.reporting", {
  lMetricWorkflows <- workr::MakeWorkflowList(
    strNames = NULL,
    strPath = system.file("workflow/2_metrics", package = "gsm.ctas"),
    strPackage = NULL
  )

  dfMetrics <- gsm.reporting::MakeMetric(lWorkflows = lMetricWorkflows)

  expect_equal(nrow(dfMetrics), length(vMetricIDs))
  expect_true(all(
    c("MetricID", "GroupLevel", "Metric", "Threshold", "AnalysisType") %in%
      names(dfMetrics)
  ))
  expect_setequal(dfMetrics$GroupLevel, "Site")

  # Each metric needs a distinguishable label, or the report shows eleven rows
  # that a reviewer cannot tell apart.
  expect_length(unique(dfMetrics$Metric), length(vMetricIDs))
  expect_length(unique(dfMetrics$Abbreviation), length(vMetricIDs))
})
