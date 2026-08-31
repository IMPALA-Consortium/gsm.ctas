# Unit tests for Summarize_CTAS().
#
# Uses a small hand-rolled `dfResults` shaped like the frame emitted by
# `Bind_Analysis()` so we don't pay the CTAS runtime cost. Column vocabulary
# mirrors the workflow-produced Reporting_Results$results contract.

MakeResultsFixture <- function() {
  data.frame(
    study = c("STUDY_A", "STUDY_A", "STUDY_A", "STUDY_A", "STUDY_A"),
    site = c("101", "101", "101", "102", "102"),
    parameter_category_1 = "Labs",
    parameter_category_2 = c("AST", "AST", "ALT", "AST", "ALT"),
    parameter_category_3 = c("numeric", "numeric", "numeric",
                             "ratio_missing", "numeric"),
    parameter_id = c("NUM_AST", "NUM_AST", "NUM_ALT", "MISS_AST", "NUM_ALT"),
    feature = c("average", "sd", "average", "average", "average"),
    fdr_corrected_pvalue_logp = c(0.5, 2.0, 3.0, 1.5, 0.1),
    timeseries_id = c("t1", "t2", "t3", "t4", "t5"),
    parameter_name = "test",
    stringsAsFactors = FALSE
  )
}

MakeSubjectsFixture <- function() {
  data.frame(
    studyid = c("STUDY_A", "STUDY_A", "STUDY_A"),
    subject_id = c("s1", "s2", "s3"),
    site = c("101", "102", "103"),   # site 103 has no scored timeseries
    stringsAsFactors = FALSE
  )
}

test_that("emits gsm-shaped dfResults columns without a Flag", {
  df <- Summarize_CTAS(MakeResultsFixture(), MakeSubjectsFixture())

  vRequired <- c(
    "MetricID", "GroupID", "GroupLevel", "StudyID", "SnapshotDate",
    "Numerator", "Denominator", "Metric", "Score"
  )
  expect_true(all(vRequired %in% names(df)))
  expect_false("Flag" %in% names(df))
  expect_setequal(unique(df$GroupLevel), "Site")
})

test_that("MetricID synthesis: default groups by data field only", {
  df <- Summarize_CTAS(MakeResultsFixture(), MakeSubjectsFixture())

  expect_true(all(startsWith(df$MetricID, "ctas_")))
  expect_setequal(unique(df$MetricID), c("ctas_AST", "ctas_ALT"))
  expect_false("feature" %in% names(df))
})

test_that("bByFeature = TRUE adds feature to MetricID and to the frame", {
  df <- Summarize_CTAS(MakeResultsFixture(), MakeSubjectsFixture(),
                       bByFeature = TRUE)

  expect_true("feature" %in% names(df))
  expect_true("ctas_AST_average" %in% df$MetricID)
  expect_true("ctas_AST_sd" %in% df$MetricID)
})

test_that("Score is the max fdr_corrected_pvalue_logp per group", {
  df <- Summarize_CTAS(MakeResultsFixture(), MakeSubjectsFixture())

  # site 101 x AST has features {average=0.5, sd=2.0} -> Score = 2.0
  dfAST101 <- df[df$GroupID == "101" & df$MetricID == "ctas_AST", ]
  expect_equal(dfAST101$Score, 2.0)
  expect_equal(dfAST101$Numerator, 2)
  expect_equal(dfAST101$Denominator, 2)
  expect_equal(dfAST101$Metric, dfAST101$Score)
})

test_that("bIncludeMissingness = FALSE drops ratio_missing rows", {
  df <- Summarize_CTAS(MakeResultsFixture(), MakeSubjectsFixture(),
                       bIncludeMissingness = FALSE)

  # site 102 x AST (parameter_category_3 = ratio_missing) is dropped
  # from the aggregation, so its row is site-completed with Score = NA.
  dfAST102 <- df[df$GroupID == "102" & df$MetricID == "ctas_AST", ]
  expect_true(is.na(dfAST102$Score))
  expect_equal(dfAST102$Numerator, 0L)
})

test_that("sites in dfSubjects but not scored are kept with NA Score", {
  df <- Summarize_CTAS(MakeResultsFixture(), MakeSubjectsFixture())

  # site 103 has no scored timeseries in the fixture; must still appear
  # for every MetricID with Score = NA, Numerator/Denominator = 0.
  dfSite103 <- df[df$GroupID == "103", ]
  expect_gt(nrow(dfSite103), 0)
  expect_true(all(is.na(dfSite103$Score)))
  expect_true(all(dfSite103$Numerator == 0))
  expect_true(all(dfSite103$Denominator == 0))
})

test_that("strStudyID overrides per-row study", {
  df <- Summarize_CTAS(MakeResultsFixture(), MakeSubjectsFixture(),
                       strStudyID = "STUDY_OVR")

  expect_setequal(unique(df$StudyID), "STUDY_OVR")
})

test_that("dSnapshotDate is stamped verbatim", {
  d <- as.Date("2024-06-01")
  df <- Summarize_CTAS(MakeResultsFixture(), MakeSubjectsFixture(),
                       dSnapshotDate = d)

  expect_setequal(unique(df$SnapshotDate), d)
})

test_that("errors on missing columns", {
  dfBad <- MakeResultsFixture()
  dfBad$fdr_corrected_pvalue_logp <- NULL

  expect_error(
    Summarize_CTAS(dfBad, MakeSubjectsFixture()),
    "fdr_corrected_pvalue_logp"
  )
})
