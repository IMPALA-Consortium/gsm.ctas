skip_if_not(
  isTRUE(bWorkflowRunnable),
  "Workflow packages (workr / gsm.core / gsm.mapping / pharmaversesdtm) not installed."
)

test_that("mapping publishes the standardised transformation-typed frames", {
  expect_true(all(
    c("Mapped_DM", "Mapped_VS", "Mapped_LB", "Mapped_EG", "Mapped_BMI",
      "Mapped_SITE", "Mapped_STUDY", "Mapped_Subjects", "Mapped_PD") %in%
      names(lMapped)
  ))
})

test_that("Mapped_BMI derives WHO categories from VS HEIGHT and WEIGHT", {
  dfBMI <- lMapped$Mapped_BMI

  expect_true(all(
    c("STUDYID", "USUBJID", "VSTESTCD", "VSTEST", "VSSTRESC",
      "VISIT", "VISITNUM") %in% names(dfBMI)
  ))
  expect_setequal(unique(dfBMI$VSTESTCD), "BMICAT")
  expect_true(all(
    unique(dfBMI$VSSTRESC) %in%
      c("Underweight", "Normal", "Overweight", "Obese")
  ))
  expect_gt(nrow(dfBMI), 0)
  expect_setequal(unique(dfBMI$STUDYID), vStudyIDs)
})

test_that("mapping filters unscheduled visits from VS, LB and EG", {
  expect_false(any(grepl("UNSCH", lMapped$Mapped_VS$VISIT, ignore.case = TRUE)))
  expect_false(any(grepl("UNSCH", lMapped$Mapped_LB$VISIT, ignore.case = TRUE)))
  expect_false(any(grepl("UNSCH", lMapped$Mapped_EG$VISIT, ignore.case = TRUE)))
})

test_that("Mapped_Subjects carries the CTAS column vocabulary and every study", {
  expect_true(all(
    c("studyid", "subject_id", "site", "country") %in% names(lMapped$Mapped_Subjects)
  ))
  expect_setequal(unique(lMapped$Mapped_Subjects$studyid), vStudyIDs)
})

test_that("Mapped_VS, Mapped_LB and Mapped_EG carry STUDYID across every stacked study", {
  expect_setequal(unique(lMapped$Mapped_VS$STUDYID), vStudyIDs)
  expect_setequal(unique(lMapped$Mapped_LB$STUDYID), vStudyIDs)
  expect_setequal(unique(lMapped$Mapped_EG$STUDYID), vStudyIDs)
})

test_that("Mapped_SITE groups by STUDYID and SITEID so cloned sites stay separated", {
  expect_setequal(names(lMapped$Mapped_SITE), c("GroupID", "Param", "Value", "GroupLevel"))
  expect_setequal(unique(lMapped$Mapped_SITE$GroupID), unique(dmSmall$SITEID))
})

test_that("one metric workflow is produced per transformation type", {
  expect_setequal(names(lAnalysis), paste0("Analysis_", vMetricIDs))
})

test_that("every metric workflow emits the ctasapp-shaped list", {
  purrr::iwalk(lAnalysis, function(lResult, strID) {
    expect_true(all(c("ID", "results", "input") %in% names(lResult)))
    expect_true(all(
      c("site", "feature", "fdr_corrected_pvalue_logp",
        "parameter_id", "parameter_category_1", "parameter_category_3",
        "study") %in%
        names(lResult$results)
    ))
    # `input` is the raw `Input_*()` output, so it carries `studyid`;
    # `Write_ctasapp()` renames it to `study` on the way to parquet.
    expect_true(all(
      c("subject_id", "parameter_id", "timepoint_1_name", "result",
        "site", "studyid", "parameter_name",
        "parameter_category_1", "parameter_category_2",
        "parameter_category_3") %in%
        names(lResult$input)
    ))
    expect_setequal(unique(lResult$results$study), vStudyIDs)
    expect_setequal(unique(lResult$input$studyid), vStudyIDs)
  })
})

test_that("every site appears in every metric feature for every study", {
  vExpectedPairs <- unique(paste(dmSmall$STUDYID, dmSmall$SITEID))

  purrr::walk(lAnalysis, function(lResult) {
    dfResults <- lResult$results
    expect_setequal(
      unique(paste(dfResults$study, dfResults$site)),
      vExpectedPairs
    )
  })
})

test_that("ratio_missing metric drops the autocorr feature", {
  # Autocorrelation of a monotonic running ratio carries no additional signal,
  # so the ratio_missing YAML deliberately omits it.
  expect_false(
    "autocorr" %in% unique(lAnalysis$Analysis_ratio_missing$results$feature)
  )
})

test_that("only range_normalized publishes an untransformed shard", {
  expect_false("untransformed" %in% names(lAnalysis$Analysis_numeric))
  expect_false("untransformed" %in% names(lAnalysis$Analysis_ratio_missing))
  expect_gt(nrow(lAnalysis$Analysis_range_normalized$untransformed), 0)
  expect_true(
    "original_value" %in% names(lAnalysis$Analysis_range_normalized$untransformed)
  )
})

test_that("range_normalized and ratio_missing share cat2 for stitching", {
  # ctasapp groups sidebar entries by parameter_category_2, so LB tests
  # scored by both metrics must publish the same cat2 on both sides.
  vRange <- unique(
    lAnalysis$Analysis_range_normalized$input$parameter_category_2
  )
  vMissing <- unique(
    lAnalysis$Analysis_ratio_missing$input$parameter_category_2
  )
  vShared <- intersect(vRange, vMissing)

  expect_gt(length(vShared), 0)
  # cat2 must be the raw LBTESTCD, not an Input_*-prefixed id.
  expect_false(any(grepl("^(RANGE|MISS|NUM)_", vShared)))
})

test_that("parameter_category_3 identifies the transformation each metric ran", {
  expect_setequal(
    unique(lAnalysis$Analysis_numeric$results$parameter_category_3), "numeric"
  )
  expect_setequal(
    unique(lAnalysis$Analysis_range_normalized$results$parameter_category_3),
    "range_normalized"
  )
  expect_setequal(
    unique(lAnalysis$Analysis_ratio_missing$results$parameter_category_3),
    "ratio_missing"
  )
})

test_that("numeric metric fans VS and EG into one Analysis slot", {
  # `Standardize_Domain` stamps `parameter_category_1` per row, so the
  # single downstream `Analyze_CTAS` call sees a mixed-domain frame.
  expect_setequal(
    unique(lAnalysis$Analysis_numeric$input$parameter_category_1),
    c("Vital Signs", "ECG")
  )
  expect_setequal(
    unique(lAnalysis$Analysis_numeric$results$parameter_category_1),
    c("Vital Signs", "ECG")
  )
})

test_that("categorical metric fans RS and BMI into one Analysis slot", {
  expect_setequal(
    unique(lAnalysis$Analysis_categorical$input$parameter_category_1),
    c("Disease Response", "BMI")
  )
  expect_setequal(
    unique(lAnalysis$Analysis_categorical$results$parameter_category_1),
    c("Disease Response", "BMI")
  )
  # BMI level labels flow through as `original_category` on the OneHot input.
  vBMIOriginal <- unique(
    lAnalysis$Analysis_categorical$input$original_category[
      lAnalysis$Analysis_categorical$input$parameter_category_2 == "BMICAT"
    ]
  )
  expect_true(all(
    vBMIOriginal %in% c("Underweight", "Normal", "Overweight", "Obese")
  ))
  expect_gt(length(vBMIOriginal), 0)
})

test_that("Write_ctasapp binds all metric shards and writes readable files", {
  skip_if_not_installed("arrow")
  skip_if_not(bWorkflowRunnable)

  lReportingWorkflows <- workr::MakeWorkflowList(
    strNames = NULL,
    strPath = system.file("workflow/3_reporting", package = "gsm.ctas"),
    strPackage = NULL
  )
  lReporting <- suppressWarnings(workr::RunWorkflows(
    lWorkflows = lReportingWorkflows["Results"],
    lData = list(lAnalyzed = lAnalysis)
  ))

  strDir <- withr::local_tempdir()
  vPaths <- Write_ctasapp(lReporting, strDir, strFormat = "parquet")

  expect_true(all(file.exists(vPaths)))
  expect_setequal(
    basename(vPaths),
    c("results.parquet", "input.parquet", "untransformed.parquet")
  )

  dfResults <- arrow::read_parquet(file.path(strDir, "results.parquet"))
  expect_gt(nrow(dfResults), 0)
  expect_setequal(
    unique(dfResults$parameter_category_3),
    vMetricIDs
  )
  expect_setequal(unique(dfResults$study), vStudyIDs)

  dfInput <- arrow::read_parquet(file.path(strDir, "input.parquet"))
  expect_gt(nrow(dfInput), 0)
  expect_setequal(unique(dfInput$study), vStudyIDs)

  dfUntransformed <- arrow::read_parquet(file.path(strDir, "untransformed.parquet"))
  vOVRLRESP <- dfUntransformed$original_category[
    dfUntransformed$parameter_category_2 == "OVRLRESP"
  ]
  expect_gt(length(vOVRLRESP), 0)
  expect_false(any(is.na(vOVRLRESP)))
})

test_that("Write_ctasapp skips empty frames", {
  skip_if_not_installed("arrow")

  lReporting <- list(
    Reporting_Results = list(
      results = data.frame(x = 1),
      input = data.frame(x = 1),
      untransformed = data.frame()
    )
  )
  strDir <- withr::local_tempdir()
  vPaths <- Write_ctasapp(lReporting, strDir, strFormat = "parquet")

  expect_false("untransformed.parquet" %in% basename(vPaths))
  expect_setequal(basename(vPaths), c("results.parquet", "input.parquet"))
})

test_that("Write_ctasapp writes queries alongside the metric shards", {
  skip_if_not_installed("arrow")

  lReporting <- list(
    Reporting_Results = list(
      results = data.frame(x = 1),
      input = data.frame(x = 1),
      untransformed = data.frame()
    ),
    Reporting_Queries = list(
      queries = data.frame(
        study = "STUDY_A", subject_id = "S1", query = "check DBP"
      )
    )
  )
  strDir <- withr::local_tempdir()
  vPaths <- Write_ctasapp(lReporting, strDir, strFormat = "parquet")

  expect_true("queries.parquet" %in% basename(vPaths))
})

test_that("Write_ctasapp errors when there are no writable frames", {
  expect_error(
    Write_ctasapp(list(), tempfile()),
    "no writable data frames"
  )
})

test_that("Reporting workflow binds shards into a common list of frames", {
  skip_if_not(bWorkflowRunnable)

  lReportingWorkflows <- workr::MakeWorkflowList(
    strNames = NULL,
    strPath = system.file("workflow/3_reporting", package = "gsm.ctas"),
    strPackage = NULL
  )

  lReporting <- suppressWarnings(workr::RunWorkflows(
    lWorkflows = lReportingWorkflows["Results"],
    lData = list(lAnalyzed = lAnalysis)
  ))

  lFrames <- lReporting$Reporting_Results
  expect_setequal(names(lFrames), c("results", "input", "untransformed"))
  expect_s3_class(lFrames$results, "data.frame")
  expect_s3_class(lFrames$input, "data.frame")

  expect_setequal(unique(lFrames$results$parameter_category_3), vMetricIDs)
  expect_setequal(unique(lFrames$results$study), vStudyIDs)
  expect_setequal(unique(lFrames$input$study), vStudyIDs)
})

test_that("Reporting workflow standardises queries via the Queries YAML", {
  skip_if_not(bWorkflowRunnable)

  lReportingWorkflows <- workr::MakeWorkflowList(
    strNames = NULL,
    strPath = system.file("workflow/3_reporting", package = "gsm.ctas"),
    strPackage = NULL
  )

  lReporting <- suppressWarnings(workr::RunWorkflows(
    lWorkflows = lReportingWorkflows[c("Results", "Queries")],
    lData = c(lMapped, list(lAnalyzed = lAnalysis))
  ))

  dfQ <- lReporting$Reporting_Queries$queries
  expect_s3_class(dfQ, "data.frame")
  expect_gt(nrow(dfQ), 0)
  expect_true(all(
    c("subject_id",
      "parameter_id", "parameter_category_1", "parameter_category_2",
      "timepoint_1_name") %in% names(dfQ)
  ))
  # `site` must NOT be present -- ctasapp re-joins it from measures.
  expect_false("site" %in% names(dfQ))
  expect_true(all(
    dfQ$parameter_category_1 %in%
      c("Labs", "Vital Signs", "ECG", "Disease Response")
  ))
  # parameter_id must be a transformed CTAS id present in Reporting_Input
  # (fanned out via the parameter_category_2 join). ctasapp joins queries
  # onto measures by parameter_id, so raw field codes wouldn't match.
  dfInput <- lReporting$Reporting_Results$input
  expect_true(all(dfQ$parameter_id %in% dfInput$parameter_id))
  # Standardize_Queries inner-joins subjects, so every query subject_id must
  # trace back to Mapped_Subjects.
  expect_true(all(dfQ$subject_id %in% lMapped$Mapped_Subjects$subject_id))
})

test_that("PD reporting workflow emits ctasapp-shape Protocol Deviation records", {
  skip_if_not(bWorkflowRunnable)

  lReportingWorkflows <- workr::MakeWorkflowList(
    strNames = NULL,
    strPath = system.file("workflow/3_reporting", package = "gsm.ctas"),
    strPackage = NULL
  )

  lReporting <- suppressWarnings(workr::RunWorkflows(
    lWorkflows = lReportingWorkflows["PD"],
    lData = lMapped
  ))

  dfPD <- lReporting$Reporting_PD$pd
  expect_s3_class(dfPD, "data.frame")
  expect_gt(nrow(dfPD), 0)
  expect_setequal(
    names(dfPD),
    c("study", "site", "subject_id", "dv_seq", "dv_term", "dv_decod",
      "dv_cat", "dv_scat", "dv_start_date", "dv_end_date")
  )
  expect_setequal(unique(dfPD$study), vStudyIDs)
  expect_true(all(dfPD$dv_cat %in% c("MAJOR", "IMPORTANT", "MINOR")))
})

test_that("Write_ctasapp emits pd alongside queries and metric frames", {
  skip_if_not_installed("arrow")
  skip_if_not(bWorkflowRunnable)

  lReportingWorkflows <- workr::MakeWorkflowList(
    strNames = NULL,
    strPath = system.file("workflow/3_reporting", package = "gsm.ctas"),
    strPackage = NULL
  )
  lReporting <- suppressWarnings(workr::RunWorkflows(
    lWorkflows = lReportingWorkflows[c("Results", "Queries", "PD")],
    lData = c(lMapped, list(lAnalyzed = lAnalysis))
  ))

  strDir <- withr::local_tempdir()
  vPaths <- Write_ctasapp(lReporting, strDir, strFormat = "parquet")

  expect_true("pd.parquet" %in% basename(vPaths))
  dfPD <- arrow::read_parquet(file.path(strDir, "pd.parquet"))
  expect_setequal(unique(dfPD$study), vStudyIDs)
})

test_that("Summary workflow packages a gsm-shaped summary + metrics + groups", {
  skip_if_not(bWorkflowRunnable)

  lReportingWorkflows <- workr::MakeWorkflowList(
    strNames = NULL,
    strPath = system.file("workflow/3_reporting", package = "gsm.ctas"),
    strPackage = NULL
  )

  lReporting <- suppressWarnings(workr::RunWorkflows(
    lWorkflows = lReportingWorkflows[c("Results", "Groups", "Metrics", "Summary")],
    lData = c(lMapped, list(
      lAnalyzed = lAnalysis,
      lMetricWorkflows = lMetricWorkflows
    ))
  ))

  lSummary <- lReporting$Reporting_Summary
  expect_setequal(names(lSummary), c("summary", "metrics", "groups"))

  dfSummary <- lSummary$summary
  vRequired <- c("MetricID", "GroupID", "GroupLevel", "StudyID",
                 "SnapshotDate", "Score", "Flag")
  expect_true(all(vRequired %in% names(dfSummary)))
  expect_false(any(c("Numerator", "Denominator", "Metric") %in% names(dfSummary)))
  expect_setequal(unique(dfSummary$GroupLevel), "Site")
  # Every fixture site must appear at least once across the summary
  expect_true(all(vSites %in% unique(dfSummary$GroupID)))

  dfMetrics <- lSummary$metrics
  # Metrics table is the full audit — every field the pipeline scored
  # appears, including any the summary SQL filter drops.
  expect_identical(dfMetrics, lReporting$Reporting_Metrics)
  expect_true(all(startsWith(dfMetrics$MetricID, "ctas_")))
  expect_setequal(unique(dfMetrics$AnalysisType), "CTAS")
  # Audit MetricID scheme is family-granular; the CTAS summary keeps its
  # field-level scheme (`ctas_<field>`) so downstream `gsm.kri` output
  # collapses families with `max(Score)`.
  expect_equal(anyDuplicated(dfMetrics$MetricID), 0L)
  dfExpected <- unique(paste0(
    "ctas_",
    lReporting$Reporting_Results$results$parameter_category_3, "_",
    lReporting$Reporting_Results$results$parameter_category_2
  ))
  expect_setequal(dfExpected, unique(dfMetrics$MetricID))
  expect_true(all(
    paste0("ctas_", unique(dfMetrics$parameter_category_2)) %in%
      c(unique(dfSummary$MetricID),
        # audit may include fields the summary filter dropped
        setdiff(paste0("ctas_", unique(dfMetrics$parameter_category_2)),
                unique(dfSummary$MetricID)))
  ))
  vIdCols <- c("parameter_id", "parameter_name",
               "parameter_category_1", "parameter_category_2",
               "parameter_category_3")
  expect_true(all(vIdCols %in% names(dfMetrics)))
  expect_false(any(c("Numerator", "Denominator", "MetricType") %in% names(dfMetrics)))
  # parameter_name is looked up from Reporting_Results$input; at least
  # one row must resolve.
  expect_false(all(is.na(dfMetrics$parameter_name)))
  # CTAS parameters harvested from the metric YAMLs land as columns.
  vParamCols <- c(
    "FeatureAutocorr", "FeatureAverage", "FeatureSD",
    "MinTimepoints", "MinSubjects", "ScoringMethod", "Seed"
  )
  expect_true(all(vParamCols %in% names(dfMetrics)))
  # Every audit row must resolve to a metric YAML (no NA parameter columns).
  expect_false(any(is.na(dfMetrics$FeatureAverage)))

  dfGroups <- lSummary$groups
  expect_setequal(names(dfGroups),
                  c("GroupID", "GroupLevel", "Param", "Value"))
  # Groups comes from the mapping layer (Mapped_STUDY + Mapped_SITE), so
  # both group levels must be present and every stacked-fixture site must
  # have a ParticipantCount row from Mapped_SITE.
  expect_setequal(unique(dfGroups$GroupLevel), c("Site", "Study"))
  expect_true("ParticipantCount" %in% dfGroups$Param)
  vSiteRows <- dfGroups$GroupID[
    dfGroups$GroupLevel == "Site" & dfGroups$Param == "ParticipantCount"
  ]
  expect_true(all(vSites %in% vSiteRows))
  expect_setequal(
    unique(dfGroups$GroupID[dfGroups$GroupLevel == "Study"]),
    vStudyIDs
  )
})

test_that("report_ctas_site module renders a CTAS HTML report", {
  skip_if_not(bWorkflowRunnable)
  skip_if_not_installed("gsm.kri")
  skip_if_not_installed("rmarkdown")

  lReportingWorkflows <- workr::MakeWorkflowList(
    strNames = NULL,
    strPath = system.file("workflow/3_reporting", package = "gsm.ctas"),
    strPackage = NULL
  )
  lModuleWorkflows <- workr::MakeWorkflowList(
    strNames = NULL,
    strPath = system.file("workflow/4_modules", package = "gsm.ctas"),
    strPackage = NULL
  )

  # gsm.kri::Report_KRI is single-study; drop the second study block from
  # the summary before rendering.
  lReporting <- suppressWarnings(workr::RunWorkflows(
    lWorkflows = lReportingWorkflows[c("Results", "Groups", "Metrics", "Summary")],
    lData = c(lMapped, list(
      lAnalyzed = lAnalysis,
      lMetricWorkflows = lMetricWorkflows
    ))
  ))
  strStudyID <- vStudyIDs[1]
  lSummary <- lReporting$Reporting_Summary
  lSummary$summary <- lSummary$summary[lSummary$summary$StudyID == strStudyID, , drop = FALSE]
  lSummary$groups <- lSummary$groups[
    lSummary$groups$GroupLevel != "Study" |
      lSummary$groups$GroupID == strStudyID, ,
    drop = FALSE
  ]
  lReporting$Reporting_Summary <- lSummary

  strDir <- withr::local_tempdir()
  lModuleWorkflows$report_ctas_site$meta$strOutputDir <- strDir
  suppressWarnings(suppressMessages(workr::RunWorkflows(
    lWorkflows = lModuleWorkflows,
    lData = lReporting
  )))

  vHtml <- list.files(strDir, pattern = "\\.html$", full.names = TRUE)
  expect_gt(length(vHtml), 0)
})


