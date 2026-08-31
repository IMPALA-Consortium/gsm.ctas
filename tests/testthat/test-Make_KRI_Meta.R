# Unit tests for Make_KRI_Metrics() and Make_KRI_Groups().

MakeSummaryFixture <- function(bByFeature = FALSE) {
  df <- data.frame(
    MetricID = c("ctas_AST", "ctas_ALT"),
    GroupID = c("101", "101"),
    Score = c(1.0, 2.0),
    parameter_category_2 = c("AST", "ALT"),
    stringsAsFactors = FALSE
  )
  if (bByFeature) {
    df$MetricID <- c("ctas_AST_average", "ctas_ALT_sd")
    df$feature <- c("average", "sd")
  }
  df
}

test_that("Make_KRI_Metrics: one row per unique MetricID", {
  dfMetrics <- Make_KRI_Metrics(MakeSummaryFixture())

  expect_setequal(dfMetrics$MetricID, c("ctas_AST", "ctas_ALT"))
  expect_equal(nrow(dfMetrics), 2)
})

test_that("Make_KRI_Metrics: emits required gsm KRI columns", {
  dfMetrics <- Make_KRI_Metrics(MakeSummaryFixture())

  vRequired <- c("MetricID", "Metric", "Numerator", "Denominator",
                 "Threshold", "GroupLevel", "AnalysisType", "Model")
  expect_true(all(vRequired %in% names(dfMetrics)))
  expect_setequal(unique(dfMetrics$GroupLevel), "Site")
  expect_setequal(unique(dfMetrics$AnalysisType), "CTAS")
})

test_that("Make_KRI_Metrics: Threshold serialises verbatim as comma-sep", {
  dfMetrics <- Make_KRI_Metrics(MakeSummaryFixture(),
                                vThreshold = c(0.842, 2.326))
  expect_setequal(unique(dfMetrics$Threshold), "0.842,2.326")
})

test_that("Make_KRI_Metrics: labels include feature when present", {
  dfMetrics <- Make_KRI_Metrics(MakeSummaryFixture(bByFeature = TRUE))
  expect_true(any(grepl("\\(average\\)", dfMetrics$Metric)))
})

test_that("Make_KRI_Groups: emits long-format meta with Enrolled + Investigator + Study block", {
  dfSubjects <- data.frame(
    studyid = c("STUDY_A", "STUDY_A", "STUDY_A", "STUDY_A"),
    subject_id = c("s1", "s2", "s3", "s4"),
    site = c("101", "101", "102", "103"),
    stringsAsFactors = FALSE
  )
  dfGroups <- Make_KRI_Groups(dfSubjects)

  expect_setequal(names(dfGroups),
                  c("GroupID", "GroupLevel", "Param", "Value"))
  expect_setequal(unique(dfGroups$Param),
                  c("Enrolled", "InvestigatorLastName",
                    "SiteCount", "ParticipantCount", "Status"))

  vEnrolled <- dfGroups[dfGroups$Param == "Enrolled", ]
  expect_setequal(vEnrolled$GroupID, c("101", "102", "103"))
  expect_equal(
    vEnrolled$Value[vEnrolled$GroupID == "101"],
    "2"
  )

  vStudy <- dfGroups[dfGroups$GroupLevel == "Study", ]
  expect_setequal(unique(vStudy$GroupID), "STUDY_A")
  expect_equal(
    vStudy$Value[vStudy$Param == "SiteCount"],
    "3"
  )
  expect_equal(
    vStudy$Value[vStudy$Param == "ParticipantCount"],
    "4"
  )
})
