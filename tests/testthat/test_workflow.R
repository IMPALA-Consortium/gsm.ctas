skip_if_not(
  isTRUE(bWorkflowRunnable),
  "Workflow packages (workr / gsm.core / gsm.mapping / pharmaversesdtm) not installed."
)

test_that("mapping publishes the standardised transformation-typed frames", {
  expect_true(all(
    c("Mapped_DM", "Mapped_VS", "Mapped_LB", "Mapped_EG", "Mapped_BMI",
      "Mapped_SITE", "Mapped_STUDY", "Mapped_Subjects") %in% names(lMapped)
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
    # `Write_Results()` renames it to `study` on the way to parquet.
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

test_that("Write_Results binds all metric shards and writes readable files", {
  skip_if_not_installed("arrow")

  strDir <- withr::local_tempdir()
  vPaths <- Write_Results(lAnalysis, strDir, strFormat = "parquet")

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

test_that("Write_Results skips untransformed when no metric produced any", {
  skip_if_not_installed("arrow")

  lNumericOnly <- lAnalysis["Analysis_numeric"]

  strDir <- withr::local_tempdir()
  vPaths <- Write_Results(lNumericOnly, strDir, strFormat = "parquet")

  expect_false("untransformed.parquet" %in% basename(vPaths))
})

test_that("Write_Results writes a queries file when supplied", {
  skip_if_not_installed("arrow")

  dfQueries <- data.frame(
    study = "STUDY_A", subject_id = "S1", query = "check DBP"
  )
  strDir <- withr::local_tempdir()
  vPaths <- Write_Results(
    lAnalysis, strDir, strFormat = "parquet", dfQueries = dfQueries
  )

  expect_true("queries.parquet" %in% basename(vPaths))
})

test_that("Reporting workflow binds shards into a common list of frames", {
  skip_if_not(bWorkflowRunnable)

  lReportingWorkflows <- workr::MakeWorkflowList(
    strNames = NULL,
    strPath = system.file("workflow/3_reporting", package = "gsm.ctas"),
    strPackage = NULL
  )

  lReporting <- suppressWarnings(gsm.core::RunWorkflows(
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
