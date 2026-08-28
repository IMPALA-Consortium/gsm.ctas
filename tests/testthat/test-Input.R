# Tests for Standardize_Domain, Input_Range and Input_Missing. The
# single-df pattern (ctasval convention) means each function takes a
# long-format frame and returns the same shape with the required CTAS
# columns added. `Standardize_Domain` translates SDTM to the CTAS vocabulary
# and emits the numeric-ready frame directly, so a separate `Input_Numeric`
# step is no longer needed.

# --- helpers -----------------------------------------------------------------

MakeSubjects <- function() {
  data.frame(
    studyid = as.character(pharmaversesdtm::dm$STUDYID),
    subject_id = as.character(pharmaversesdtm::dm$USUBJID),
    site = as.character(pharmaversesdtm::dm$SITEID),
    country = as.character(pharmaversesdtm::dm$COUNTRY),
    stringsAsFactors = FALSE
  )
}

MakeVSLong <- function() {
  Standardize_Domain(
    dfDomain = pharmaversesdtm::vs,
    dfSubjects = MakeSubjects(),
    strTestCDCol = "VSTESTCD", strTestCol = "VSTEST",
    strValueCol = "VSSTRESN",
    strCategory = "Vital Signs",
    strExcludePattern = NULL
  )
}

MakeLBLong <- function() {
  Standardize_Domain(
    dfDomain = pharmaversesdtm::lb,
    dfSubjects = MakeSubjects(),
    strTestCDCol = "LBTESTCD", strTestCol = "LBTEST",
    strValueCol = "LBSTRESN",
    strLowCol = "LBSTNRLO", strHighCol = "LBSTNRHI",
    strCategory = "Labs",
    strExcludePattern = NULL
  )
}

# --- Standardize_Domain ------------------------------------------------------

test_that("Standardize_Domain returns the CTAS long-format vocabulary", {
  dfLong <- MakeVSLong()

  vRequired <- c(
    "studyid", "subject_id", "site", "country",
    "parameter_id", "parameter_name",
    "parameter_category_1", "parameter_category_2", "parameter_category_3",
    "visit", "visitnum", "value",
    "timepoint_1_name", "timepoint_2_name", "timepoint_rank",
    "result", "baseline"
  )
  expect_true(all(vRequired %in% names(dfLong)))
  expect_setequal(unique(dfLong$parameter_category_1), "Vital Signs")
  expect_setequal(unique(dfLong$parameter_category_3), "numeric")
  expect_equal(dfLong$parameter_category_2, dfLong$parameter_id)
  expect_true(is.numeric(dfLong$timepoint_rank))
  expect_true(is.numeric(dfLong$result))
})

test_that("Standardize_Domain applies an optional prefix while keeping cat2 raw", {
  dfSubjects <- data.frame(subject_id = "S1", site = "701")
  dfDomain <- data.frame(
    USUBJID = "S1", VSTESTCD = "SYSBP", VSTEST = "SBP",
    VSSTRESN = 120, VISIT = "WEEK 2", VISITNUM = 3
  )

  dfLong <- Standardize_Domain(
    dfDomain, dfSubjects,
    strTestCDCol = "VSTESTCD", strTestCol = "VSTEST",
    strValueCol = "VSSTRESN",
    strCategory = "Vital Signs",
    strPrefix = "NUM"
  )

  expect_equal(dfLong$parameter_id, "NUM_SYSBP")
  expect_equal(dfLong$parameter_category_2, "SYSBP")
})

test_that("Standardize_Domain joins studyid/site/country from dfSubjects", {
  dfSubjects <- data.frame(
    studyid = "A", subject_id = "S1",
    site = "701", country = "USA",
    stringsAsFactors = FALSE
  )
  dfDomain <- data.frame(
    USUBJID = "S1", VSTESTCD = "SYSBP", VSTEST = "Systolic Blood Pressure",
    VSSTRESN = 120, VISIT = "WEEK 2", VISITNUM = 3
  )

  dfLong <- Standardize_Domain(
    dfDomain, dfSubjects,
    strTestCDCol = "VSTESTCD", strTestCol = "VSTEST",
    strValueCol = "VSSTRESN",
    strCategory = "Vital Signs"
  )

  expect_equal(dfLong$studyid, "A")
  expect_equal(dfLong$site, "701")
  expect_equal(dfLong$country, "USA")
})

test_that("Standardize_Domain filters unscheduled visits by default", {
  dfSubjects <- data.frame(subject_id = "S1", site = "701")
  dfDomain <- data.frame(
    USUBJID = c("S1", "S1"),
    VSTESTCD = "SYSBP", VSTEST = "Systolic Blood Pressure",
    VSSTRESN = c(120, 122),
    VISIT = c("WEEK 2", "UNSCHEDULED 1"),
    VISITNUM = c(3, 3.5)
  )

  dfLong <- Standardize_Domain(
    dfDomain, dfSubjects,
    strTestCDCol = "VSTESTCD", strTestCol = "VSTEST",
    strValueCol = "VSSTRESN",
    strCategory = "Vital Signs"
  )

  expect_setequal(dfLong$visit, "WEEK 2")
})

test_that("Standardize_Domain carries low/high when the columns are supplied", {
  dfLong <- MakeLBLong()

  expect_true(all(c("low", "high") %in% names(dfLong)))
})

test_that("Standardize_Domain errors informatively on missing columns", {
  expect_error(
    Standardize_Domain(
      data.frame(USUBJID = "S1"),
      dfSubjects = data.frame(subject_id = "S1", site = "701"),
      strTestCDCol = "VSTESTCD", strTestCol = "VSTEST",
      strValueCol = "VSSTRESN",
      strCategory = "Vital Signs"
    ),
    "missing required column"
  )
})

# --- Input_Range -------------------------------------------------------------

test_that("Input_Range normalises values by their reference range", {
  dfLong <- data.frame(
    studyid = "A", subject_id = "S1", site = "701",
    parameter_id = "ALT", parameter_name = "Alanine Aminotransferase",
    parameter_category_1 = "Labs", parameter_category_2 = "ALT",
    visit = c("WEEK 2", "WEEK 4"), visitnum = c(3, 4),
    value = c(10, 40), low = c(10, 10), high = c(40, 40)
  )

  df <- Input_Range(dfLong)

  expect_equal(df$result, c(0, 1))
  expect_setequal(df$parameter_category_3, "range_normalized")
  expect_equal(df$original_value, c(10, 40))
})

test_that("Input_Range drops rows with an unusable reference range", {
  dfLong <- data.frame(
    studyid = "A", subject_id = "S1", site = "701",
    parameter_id = "ALT", parameter_name = "ALT",
    parameter_category_1 = "Labs", parameter_category_2 = "ALT",
    visit = c("WEEK 2", "WEEK 4"), visitnum = c(3, 4),
    value = c(10, 40), low = c(10, NA), high = c(40, 40)
  )

  df <- Input_Range(dfLong)

  expect_equal(nrow(df), 1)
})

test_that("Input_Range carries the untransformed detail columns", {
  dfLong <- MakeLBLong()

  df <- Input_Range(dfLong)

  expect_true(all(c("original_value", "lower", "upper", "original_category") %in% names(df)))
})

# --- Input_Missing -----------------------------------------------------------

test_that("Input_Missing retains missing rows and encodes the running ratio", {
  dfLong <- data.frame(
    studyid = "A", subject_id = "S1", site = "701",
    parameter_id = "ALT", parameter_name = "ALT",
    parameter_category_1 = "Labs", parameter_category_2 = "ALT",
    visit = c("WEEK 2", "WEEK 4"), visitnum = c(3, 4),
    value = c(10, NA)
  )

  df <- Input_Missing(dfLong)

  expect_equal(nrow(df), 2)
  expect_equal(df$result, c(0, 0.5))
  expect_setequal(df$parameter_category_3, "ratio_missing")
})

# --- cross-metric stitching --------------------------------------------------

test_that("Input_Range and Input_Missing share parameter_category_2 on the same field", {
  dfLong <- MakeLBLong()

  dfRange <- Input_Range(dfLong)
  dfMissing <- Input_Missing(dfLong)

  vShared <- intersect(unique(dfRange$parameter_category_2),
                       unique(dfMissing$parameter_category_2))

  expect_gt(length(vShared), 0)
  expect_true(all(vShared %in% unique(dfLong$parameter_id)))
})
