test_that("the reporting layer produces the four stock objects and no Input", {
  expect_setequal(
    names(lReporting),
    c("Reporting_Groups", "Reporting_Metrics", "Reporting_Results", "Reporting_Bounds")
  )

  # `Reporting_Input` is deliberately absent: CTAS scores a site as a whole
  # against the rest of the study, so there is no subject-level
  # numerator/denominator to stack, and the stock gsm.kri report never uses one.
  expect_false("Reporting_Input" %in% names(lReporting))
})

test_that("Reporting_Groups carries site and study metadata", {
  expect_setequal(unique(lReporting$Reporting_Groups$GroupLevel), c("Study", "Site"))
  expect_true(all(
    c("GroupID", "GroupLevel", "Param", "Value") %in% names(lReporting$Reporting_Groups)
  ))

  # The stock `Report_KRI.Rmd` labels sites with `InvestigatorLastName`, which SDTM
  # DM does not carry, so `SITE.yaml` falls back to SITEID.
  expect_true("InvestigatorLastName" %in% lReporting$Reporting_Groups$Param)
})

test_that("Reporting_Results stacks every metric and meets the column contract", {
  dfResults <- lReporting$Reporting_Results

  expect_true(all(
    c(
      "GroupID", "GroupLevel", "Numerator", "Denominator", "Metric", "Score",
      "Flag", "MetricID", "StudyID", "SnapshotDate"
    ) %in% names(dfResults)
  ))

  expect_setequal(unique(dfResults$MetricID), paste0("Analysis_", vMetricIDs))
  expect_setequal(unique(dfResults$GroupLevel), "Site")
  expect_equal(
    nrow(dfResults),
    length(vMetricIDs) * dplyr::n_distinct(dmSmall$SITEID)
  )
  expect_length(unique(dfResults$StudyID), 1)
})

test_that("Reporting_Metrics exposes the metadata the report labels with", {
  dfMetrics <- lReporting$Reporting_Metrics

  expect_equal(nrow(dfMetrics), length(vMetricIDs))
  expect_true(all(
    c("MetricID", "GroupLevel", "Metric", "Threshold", "AnalysisType") %in%
      names(dfMetrics)
  ))
  expect_setequal(dfMetrics$GroupLevel, "Site")
  expect_setequal(tolower(dfMetrics$AnalysisType), "identity")
})

test_that("Reporting_Bounds is empty because every metric is identity-typed", {
  # `MakeBounds()` returns no rows for an identity `AnalysisType`. The step is kept
  # so a study adding rate-type metrics needs no new workflow file.
  expect_equal(nrow(lReporting$Reporting_Bounds), 0)
})

test_that("the report module renders a site-level KRI HTML file without a scatter plot", {
  skip_if_not_installed("gsm.kri")
  skip_if_not_installed("rmarkdown")
  skip_if_not_installed("knitr")

  # Read the workflow from disk rather than reusing a list built at setup time: an
  # in-memory workflow does not pick up edits to the YAML, so a module missing the
  # DropChart step would otherwise still pass here.
  lModules <- workr::MakeWorkflowList(
    strNames = NULL,
    strPath = system.file("workflow/4_modules", package = "gsm.ctas"),
    strPackage = NULL
  )
  nStep <- length(lModules$report_kri_site$steps)

  strDir <- withr::local_tempdir()
  lModules$report_kri_site$steps[[nStep]]$params$strOutputDir <- strDir
  lModules$report_kri_site$steps[[nStep]]$params$strOutputFile <- "report_kri_site.html"

  # `RunWorkflows()` must not warn about `lAnalysis` elements lacking
  # `Analysis_Input`; that omission is intentional and must stay silent.
  # `workr::RunWorkflows()` is called directly here; the `gsm.core` re-export is
  # deprecated and would raise a lifecycle warning of its own.
  expect_no_warning(
    suppressMessages(workr::RunWorkflows(lModules, lReporting))
  )

  strFile <- file.path(strDir, "report_kri_site.html")
  expect_true(file.exists(strFile))

  # Assert on the rendered tab headings. Counting occurrences of "scatterPlot" in
  # the HTML is not a valid check: gsm.kri embeds the Chart.js source and a JSON
  # schema that mention it regardless of which charts were drawn.
  vHtml <- readLines(strFile, warn = FALSE)
  expect_false(any(grepl("Scatter Plot</h5>", vHtml, fixed = TRUE)))
  expect_true(any(grepl("Bar Chart</h5>", vHtml, fixed = TRUE)))
})

test_that("the report module wires DropChart between MakeCharts and Report_KRI", {
  lModules <- workr::MakeWorkflowList(
    strNames = NULL,
    strPath = system.file("workflow/4_modules", package = "gsm.ctas"),
    strPackage = NULL
  )

  vNames <- vapply(
    lModules$report_kri_site$steps, function(lStep) lStep$name, character(1)
  )

  expect_true("gsm.ctas::DropChart" %in% vNames)
  expect_gt(which(vNames == "gsm.ctas::DropChart"), which(vNames == "gsm.kri::MakeCharts"))
  expect_lt(which(vNames == "gsm.ctas::DropChart"), which(vNames == "gsm.kri::Report_KRI"))
})

test_that("Denominator counts evaluated timeseries, not participants", {
  # The scatter plot is dropped from the report module because of this: within a
  # metric the denominator is a coverage count that is identical across sites, so
  # plotting it on x collapses every point onto one position. It varies *between*
  # metrics only because the parameter families have different sizes.
  dfResults <- lReporting$Reporting_Results

  dfPerMetric <- dfResults |>
    dplyr::summarise(N = dplyr::n_distinct(.data$Denominator), .by = "MetricID")
  expect_true(all(dfPerMetric$N == 1))

  # VS contributes one timeseries per parameter. Labs contribute two, because
  # CTAS autogenerates a separate timeseries per timepoint combination and lab
  # visit schedules differ between subjects where vital-signs ones do not. So
  # the denominator is a count of timeseries, not of parameters or of tests.
  expect_equal(
    unique(dfResults$Denominator[dfResults$MetricID == "Analysis_ctas0001"]),
    dplyr::n_distinct(vsSmall$VSTESTCD)
  )
  expect_equal(
    unique(dfResults$Denominator[dfResults$MetricID == "Analysis_ctas0006"]),
    dplyr::n_distinct(
      lMapped$Mapped_CTAS_SiteScores$timeseries_id[
        grepl("^LB_NORM_", lMapped$Mapped_CTAS_SiteScores$parameter_id)
      ]
    )
  )

  # It is a count of timeseries, so it must not track participant count.
  dfParticipants <- dmSmall |>
    dplyr::count(SITEID, name = "Participants")
  expect_gt(dplyr::n_distinct(dfParticipants$Participants), 1)
})

test_that("the stock KRI report template makes no reference to Analysis_Input", {
  skip_if_not_installed("gsm.kri")

  strRmd <- system.file("report", "Report_KRI.Rmd", package = "gsm.kri")
  skip_if(strRmd == "")

  vLines <- readLines(strRmd, warn = FALSE)
  expect_false(any(grepl("Reporting_Input|Analysis_Input", vLines)))
})
