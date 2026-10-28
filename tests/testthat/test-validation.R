test_that("ctas and gsm.ctas results match on vitals and labs sample data (#25)", {
  dfSubjects <- data.frame(
    studyid = gsm.ctas::dm$STUDYID,
    subject_id = gsm.ctas::dm$USUBJID,
    site = gsm.ctas::dm$SITEID,
    country = gsm.ctas::dm$COUNTRY,
    stringsAsFactors = FALSE
  )

  dfInput <- Standardize_Domain(
    dfDomain = gsm.ctas::vs,
    dfSubjects = dfSubjects,
    strTestCDCol = "VSTESTCD",
    strTestCol = "VSTEST",
    strValueCol = "VSSTRESN",
    strCategory = "Vital Signs"
  )
  dfLB <- Standardize_Domain(
    dfDomain = gsm.ctas::lb,
    dfSubjects = dfSubjects,
    strTestCDCol = "LBTESTCD",
    strTestCol = "LBTEST",
    strValueCol = "LBSTRESN",
    strCategory = "Labs"
  )
  dfInput <- dplyr::bind_rows(dfInput, dfLB)

  lCTASInput <- BuildCTASInput(
    dfInput,
    strStudyCol = "studyid",
    dfCustomTimeseries = ctas::ctas_data$custom_timeseries,
    dfCustomReferenceGroups = ctas::ctas_data$custom_reference_groups
  )

  lDirectCTAS <- suppressWarnings(withr::with_seed(42, ctas::process_a_study(
    subjects = lCTASInput$subjects,
    parameters = lCTASInput$parameters,
    data = lCTASInput$data,
    custom_timeseries = lCTASInput$custom_timeseries,
    custom_reference_groups = lCTASInput$custom_reference_groups,
    default_timeseries_features_to_calculate =
      "autocorr;average;sd;unique_value_count_relative",
    default_minimum_timepoints_per_series = 1,
    default_minimum_subjects_per_series = 3,
    default_max_share_missing_timepoints_per_series = 0.5,
    default_generate_change_from_baseline = FALSE,
    autogenerate_timeseries = TRUE,
    site_scoring_method = "ks",
    padjust_method = "fdr"
  )))

  strStudy <- unique(dfInput$studyid)
  
  expect_length(strStudy, 1)

  dfDirectScores <- lDirectCTAS$site_scores

  dfDirectScores$studyid <- strStudy

  dfTimeseries <- lDirectCTAS$timeseries |>
    dplyr::select(timeseries_id, parameter_id)

  expect_equal(anyDuplicated(dfTimeseries$timeseries_id), 0L)

  dfParameters <- lCTASInput$parameters |>
    dplyr::select(
      parameter_id,
      parameter_category_1,
      parameter_category_2,
      parameter_category_3
    )
  expect_equal(anyDuplicated(dfParameters$parameter_id), 0L)

  dfDirectResults <- dfDirectScores |>
    dplyr::left_join(dfTimeseries, by = "timeseries_id") |>
    dplyr::left_join(dfParameters, by = "parameter_id") |>
    dplyr::rename(study = studyid)

  dfGsmResults <- suppressWarnings(Analyze_CTAS(dfInput, nSeed = 42))

  dfDirectResults <- dplyr::arrange(
    dfDirectResults, study, site, timeseries_id, feature
  )
  dfGsmResults <- dplyr::arrange(
    dfGsmResults, study, site, timeseries_id, feature
  )
  expect_equal(dfGsmResults, dfDirectResults)

})

test_that("Standardize_Domain results must match source data (#29)", {

  dfSubjects <- data.frame(
    studyid = gsm.ctas::dm$STUDYID,
    subject_id = gsm.ctas::dm$USUBJID,
    site = gsm.ctas::dm$SITEID,
    country = gsm.ctas::dm$COUNTRY,
    stringsAsFactors = FALSE
  )

  # Vital Signs

  dfVS <- Standardize_Domain(
    dfDomain = gsm.ctas::vs,
    dfSubjects = dfSubjects,
    strTestCDCol = "VSTESTCD",
    strTestCol = "VSTEST",
    strValueCol = "VSSTRESN",
    strCategory = "Vital Signs"
  )

  dfVSReverted <- dfVS |>
    dplyr::transmute(
      STUDYID = studyid,
      USUBJID = subject_id,
      VSTESTCD = parameter_id,
      VSTEST = parameter_name,
      VISIT = visit,
      VSSTRESN = value
    ) |>
    dplyr::arrange(dplyr::across(dplyr::everything())) |>
    as.data.frame()

  dfVSOriginal <- gsm.ctas::vs |>
    dplyr::select(STUDYID, USUBJID, VSTESTCD, VSTEST, VISIT, VSSTRESN) |>
    dplyr::arrange(dplyr::across(dplyr::everything())) |>
    as.data.frame()

  expect_equal(dfVSReverted, dfVSOriginal, ignore_attr = TRUE)

  # Labs

  dfLB <- Standardize_Domain(
    dfDomain = gsm.ctas::lb,
    dfSubjects = dfSubjects,
    strTestCDCol = "LBTESTCD",
    strTestCol = "LBTEST",
    strValueCol = "LBSTRESN",
    strCategory = "Labs"
  )

  dfLBReverted <- dfLB |>
    dplyr::transmute(
      STUDYID = studyid,
      USUBJID = subject_id,
      LBTESTCD = parameter_id,
      LBTEST = parameter_name,
      VISIT = visit,
      LBSTRESN = value
    ) |>
    dplyr::arrange(dplyr::across(dplyr::everything())) |>
    as.data.frame()

  dfLBOriginal <- gsm.ctas::lb |>
    dplyr::select(STUDYID, USUBJID, LBTESTCD, LBTEST, VISIT, LBSTRESN) |>
    dplyr::arrange(dplyr::across(dplyr::everything())) |>
    as.data.frame()

  expect_equal(dfLBReverted, dfLBOriginal, ignore_attr = TRUE)
})
