# Tests for Standardize_Domain, Input_Numeric, Input_Range and Input_Missing.
# The single-df pattern (ctasval convention) means each function takes a
# long-format frame and returns the same shape with the required CTAS columns
# added. Standardize_Domain does the SDTM -> CTAS vocabulary translation.

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

  expect_true(all(
    c("studyid", "subject_id", "site", "country",
      "parameter_id", "parameter_name", "parameter_category_1",
      "visit", "visitnum", "value") %in% names(dfLong)
  ))
  expect_setequal(unique(dfLong$parameter_category_1), "Vital Signs")
  expect_true(is.numeric(dfLong$visitnum))
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

# --- Input_Numeric -----------------------------------------------------------

test_that("Input_Numeric produces the CTAS long-format columns", {
  dfLong <- MakeVSLong()

  df <- Input_Numeric(dfLong)

  vRequired <- c(
    "subject_id", "site", "parameter_id", "parameter_name",
    "parameter_category_1", "parameter_category_2", "parameter_category_3",
    "timepoint_1_name", "timepoint_2_name", "timepoint_rank",
    "result", "baseline"
  )
  expect_true(all(vRequired %in% names(df)))
  expect_setequal(unique(df$parameter_category_3), "numeric")
  expect_true(is.numeric(df$result))
  expect_false(any(is.na(df$result)))
})

test_that("Input_Numeric prefixes parameter_id and preserves it in parameter_category_2", {
  dfLong <- MakeVSLong()

  df <- Input_Numeric(dfLong)

  expect_true(all(grepl("^NUM_", df$parameter_id)))
  expect_equal(df$parameter_id, df$parameter_category_2)
})

test_that("Input_Numeric supports a custom prefix", {
  dfLong <- MakeVSLong()

  df <- Input_Numeric(dfLong, strPrefix = "EG")

  expect_true(all(grepl("^EG_", df$parameter_id)))
})

test_that("Input_Numeric drops rows with NA value", {
  dfLong <- data.frame(
    studyid = "A", subject_id = "S1", site = "701",
    parameter_id = "SYSBP", parameter_name = "SBP",
    parameter_category_1 = "Vital Signs",
    visit = c("WEEK 2", "WEEK 4"), visitnum = c(3, 4),
    value = c(120, NA_real_)
  )

  df <- Input_Numeric(dfLong)

  expect_equal(nrow(df), 1)
})

# --- Input_Range -------------------------------------------------------------

test_that("Input_Range normalises values by their reference range", {
  dfLong <- data.frame(
    studyid = "A", subject_id = "S1", site = "701",
    parameter_id = "ALT", parameter_name = "Alanine Aminotransferase",
    parameter_category_1 = "Labs",
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
    parameter_category_1 = "Labs",
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
    parameter_category_1 = "Labs",
    visit = c("WEEK 2", "WEEK 4"), visitnum = c(3, 4),
    value = c(10, NA)
  )

  df <- Input_Missing(dfLong)

  expect_equal(nrow(df), 2)
  expect_equal(df$result, c(0, 0.5))
  expect_setequal(df$parameter_category_3, "ratio_missing")
})
