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

test_that("Transform_OneHot results must match source data (#30)", {

  dfSubjects <- data.frame(
    studyid = gsm.ctas::dm$STUDYID,
    subject_id = gsm.ctas::dm$USUBJID,
    site = gsm.ctas::dm$SITEID,
    country = gsm.ctas::dm$COUNTRY,
    stringsAsFactors = FALSE
  )

  dfRS <- Standardize_Domain(
    dfDomain = gsm.ctas::rs,
    dfSubjects = dfSubjects,
    strTestCDCol = "RSTESTCD",
    strTestCol = "RSTEST",
    strValueCol = "RSSTRESC",
    strCategory = "Disease Response"
  )

  dfOneHot <- Transform_OneHot(dfRS)

  # Each observation is encoded as 1 for its own level only.
  dfRSReverted <- dfOneHot |>
    dplyr::filter(result == 1) |>
    dplyr::transmute(
      STUDYID = studyid,
      USUBJID = subject_id,
      RSTESTCD = parameter_category_2,
      VISIT = visit,
      RSSTRESC = original_category
    ) |>
    dplyr::arrange(dplyr::across(dplyr::everything())) |>
    as.data.frame()

  # Transform_OneHot drops missing and empty results.
  dfRSOriginal <- gsm.ctas::rs |>
    dplyr::filter(!is.na(RSSTRESC), RSSTRESC != "") |>
    dplyr::select(STUDYID, USUBJID, RSTESTCD, VISIT, RSSTRESC) |>
    dplyr::arrange(dplyr::across(dplyr::everything())) |>
    as.data.frame()

  expect_equal(dfRSReverted, dfRSOriginal, ignore_attr = TRUE)
})

test_that("Transform_Missing results must match source data (#31)", {

  dfSubjects <- data.frame(
    studyid = gsm.ctas::dm$STUDYID,
    subject_id = gsm.ctas::dm$USUBJID,
    site = gsm.ctas::dm$SITEID,
    country = gsm.ctas::dm$COUNTRY,
    stringsAsFactors = FALSE
  )

  dfLB <- Standardize_Domain(
    dfDomain = gsm.ctas::lb,
    dfSubjects = dfSubjects,
    strTestCDCol = "LBTESTCD",
    strTestCol = "LBTEST",
    strValueCol = "LBSTRESN",
    strCategory = "Labs"
  )

  dfMissing <- Transform_Missing(dfLB)

  # result is the running ratio of missing values, so ratio x visit count is
  # the cumulative number of missing values; its increments are the flags.
  dfLBReverted <- dfMissing |>
    dplyr::arrange(subject_id, parameter_category_2, timepoint_rank) |>
    dplyr::mutate(
      nMissing = round(dplyr::row_number() * result),
      bMissing = nMissing - dplyr::lag(nMissing, default = 0) == 1,
      .by = c(subject_id, parameter_category_2)
    ) |>
    dplyr::transmute(
      STUDYID = studyid,
      USUBJID = subject_id,
      LBTESTCD = parameter_category_2,
      VISIT = visit,
      LBSTRESN_MISSING = bMissing
    ) |>
    dplyr::arrange(dplyr::across(dplyr::everything())) |>
    as.data.frame()

  dfLBOriginal <- gsm.ctas::lb |>
    dplyr::transmute(
      STUDYID,
      USUBJID,
      LBTESTCD,
      VISIT,
      LBSTRESN_MISSING = is.na(LBSTRESN)
    ) |>
    dplyr::arrange(dplyr::across(dplyr::everything())) |>
    as.data.frame()

  expect_equal(dfLBReverted, dfLBOriginal, ignore_attr = TRUE)
})

test_that("Transform_Range results must match source data (#32)", {

  dfSubjects <- data.frame(
    studyid = gsm.ctas::dm$STUDYID,
    subject_id = gsm.ctas::dm$USUBJID,
    site = gsm.ctas::dm$SITEID,
    country = gsm.ctas::dm$COUNTRY,
    stringsAsFactors = FALSE
  )

  dfLB <- Standardize_Domain(
    dfDomain = gsm.ctas::lb,
    dfSubjects = dfSubjects,
    strTestCDCol = "LBTESTCD",
    strTestCol = "LBTEST",
    strValueCol = "LBSTRESN",
    strLowCol = "LBSTNRLO",
    strHighCol = "LBSTNRHI",
    strCategory = "Labs"
  )

  # Warns about rows it drops; those rows are excluded from the source below.
  dfRange <- suppressWarnings(Transform_Range(dfLB))

  dfLBReverted <- dfRange |>
    dplyr::transmute(
      STUDYID = studyid,
      USUBJID = subject_id,
      LBTESTCD = parameter_category_2,
      VISIT = visit,
      LBSTNRLO = lower,
      LBSTNRHI = upper,
      LBSTRESN = result * (upper - lower) + lower
    ) |>
    dplyr::arrange(dplyr::across(dplyr::everything())) |>
    as.data.frame()

  # Transform_Range drops missing results and unusable reference ranges.
  dfLBOriginal <- gsm.ctas::lb |>
    dplyr::filter(
      !is.na(LBSTRESN),
      !is.na(LBSTNRLO),
      !is.na(LBSTNRHI),
      LBSTNRHI > LBSTNRLO
    ) |>
    dplyr::select(
      STUDYID, USUBJID, LBTESTCD, VISIT, LBSTNRLO, LBSTNRHI, LBSTRESN
    ) |>
    dplyr::arrange(dplyr::across(dplyr::everything())) |>
    as.data.frame()

  expect_equal(dfLBReverted, dfLBOriginal, ignore_attr = TRUE)
})

test_that("Write_ctasapp files meet ctasapp file requirements (#33)", {
  skip_if_not_installed("workr")
  skip_if_not_installed("gsm.mapping")
  skip_if_not_installed("arrow")

  lRaw <- list(
    Raw_DM = gsm.ctas::dm,
    Raw_LB = gsm.ctas::lb,
    Raw_VS = gsm.ctas::vs,
    Raw_EG = gsm.ctas::eg,
    Raw_RS = gsm.ctas::rs,
    Raw_Queries = gsm.ctas::queries,
    Raw_PD = gsm.ctas::pd
  )

  lMappingWorkflows <- workr::MakeWorkflowList(
    strPath = system.file("workflow/1_mappings", package = "gsm.ctas")
  )

  lMetricWorkflows <- workr::MakeWorkflowList(
    strPath = system.file("workflow/2_metrics", package = "gsm.ctas")
  )

  lReportingWorkflows <- workr::MakeWorkflowList(
    strPath = system.file("workflow/3_reporting", package = "gsm.ctas")
  )

  lMapped <- suppressWarnings(suppressMessages(workr::RunWorkflows(
    lWorkflows = lMappingWorkflows,
    lData = gsm.mapping::Ingest(lRaw, gsm.mapping::CombineSpecs(lMappingWorkflows))
  )))

  lAnalysis <- suppressWarnings(suppressMessages(workr::RunWorkflows(
    lWorkflows = lMetricWorkflows,
    lData = lMapped
  )))

  lReporting <- suppressWarnings(suppressMessages(workr::RunWorkflows(
    lWorkflows = lReportingWorkflows[c("Results", "Queries", "PD")],
    lData = c(lMapped, list(lAnalyzed = lAnalysis))
  )))

  strDir <- withr::local_tempdir()

  Write_ctasapp(lReporting, strDir, strFormat = "parquet")

  # ctasapp reads files as plain data frames.
  dfResults <- as.data.frame(arrow::read_parquet(file.path(strDir, "results.parquet")))
  dfInput <- as.data.frame(arrow::read_parquet(file.path(strDir, "input.parquet")))
  dfUntransformed <- as.data.frame(arrow::read_parquet(file.path(strDir, "untransformed.parquet")))
  dfQueries <- as.data.frame(arrow::read_parquet(file.path(strDir, "queries.parquet")))
  dfPD <- as.data.frame(arrow::read_parquet(file.path(strDir, "pd.parquet")))

  # Requirements hardcoded from ctasapp validate_upload_*() and validate_upload_crossfile().

  # results

  expect_contains(
    names(dfResults),
    c("site", "timeseries_id", "parameter_id", "feature", "fdr_corrected_pvalue_logp")
  )
  expect_true(is.numeric(dfResults$fdr_corrected_pvalue_logp))

  # input

  expect_contains(
    names(dfInput),
    c(
      "subject_id", "site", "parameter_id", "parameter_name",
      "parameter_category_3", "timepoint_1_name", "timepoint_rank", "result"
    )
  )
  expect_true(is.numeric(dfInput$result))
  expect_true(is.numeric(dfInput$timepoint_rank))
  expect_in(
    unique(dfInput$parameter_category_3),
    c("numeric", "range_normalized", "ratio_missing", "categorical", "bar")
  )

  # untransformed

  expect_contains(
    names(dfUntransformed),
    c("subject_id", "parameter_category_2", "timepoint_1_name")
  )

  # queries

  expect_contains(
    names(dfQueries),
    c("subject_id", "parameter_id", "visit", "data_change")
  )
  expect_true(is.logical(dfQueries$data_change))

  # pd

  expect_gt(nrow(dfPD), 0)
  expect_contains(names(dfPD), "site")

  # cross-file

  expect_in(unique(dfResults$parameter_id), unique(dfInput$parameter_id))
  expect_in(unique(dfResults$site), unique(dfInput$site))
})

test_that("Pipeline renders the html report (#34)", {
  skip_if_not_installed("workr")
  skip_if_not_installed("gsm.mapping")
  skip_if_not_installed("gsm.kri")
  skip_if_not(rmarkdown::pandoc_available())

  lRaw <- list(
    Raw_DM = gsm.ctas::dm,
    Raw_LB = gsm.ctas::lb,
    Raw_VS = gsm.ctas::vs,
    Raw_EG = gsm.ctas::eg,
    Raw_RS = gsm.ctas::rs,
    Raw_Queries = gsm.ctas::queries,
    Raw_PD = gsm.ctas::pd
  )

  lMappingWorkflows <- workr::MakeWorkflowList(
    strPath = system.file("workflow/1_mappings", package = "gsm.ctas")
  )

  lMetricWorkflows <- workr::MakeWorkflowList(
    strPath = system.file("workflow/2_metrics", package = "gsm.ctas")
  )

  lReportingWorkflows <- workr::MakeWorkflowList(
    strPath = system.file("workflow/3_reporting", package = "gsm.ctas")
  )

  lModuleWorkflows <- workr::MakeWorkflowList(
    strPath = system.file("workflow/4_modules", package = "gsm.ctas")
  )

  lMapped <- suppressWarnings(suppressMessages(workr::RunWorkflows(
    lWorkflows = lMappingWorkflows,
    lData = gsm.mapping::Ingest(lRaw, gsm.mapping::CombineSpecs(lMappingWorkflows))
  )))

  lAnalysis <- suppressWarnings(suppressMessages(workr::RunWorkflows(
    lWorkflows = lMetricWorkflows,
    lData = lMapped
  )))

  lReporting <- suppressWarnings(suppressMessages(workr::RunWorkflows(
    lWorkflows = lReportingWorkflows,
    lData = c(lMapped, list(
      lAnalyzed = lAnalysis,
      lMetricWorkflows = lMetricWorkflows
    ))
  )))

  # The module workflow writes the report into the working directory.
  strDir <- withr::local_tempdir()
  withr::local_dir(strDir)

  suppressWarnings(suppressMessages(workr::RunWorkflows(
    lWorkflows = lModuleWorkflows,
    lData = lReporting
  )))

  vReports <- list.files(strDir, pattern = "\\.html$", full.names = TRUE)

  expect_length(vReports, 1)
  expect_gt(file.size(vReports), 0)
})
