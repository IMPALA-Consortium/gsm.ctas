# Tests for Standardize_Domain, Transform_Range, Transform_Missing and Transform_OneHot.
# The single-df pattern (ctasval convention) means each function takes a
# long-format frame and returns the same shape with the required CTAS
# columns added. `Standardize_Domain` translates SDTM to the CTAS vocabulary
# and emits the numeric-ready frame directly, so no extra numeric transform
# is needed.

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
    strCategory = "Vital Signs"
  )
}

MakeLBLong <- function() {
  Standardize_Domain(
    dfDomain = pharmaversesdtm::lb,
    dfSubjects = MakeSubjects(),
    strTestCDCol = "LBTESTCD", strTestCol = "LBTEST",
    strValueCol = "LBSTRESN",
    strLowCol = "LBSTNRLO", strHighCol = "LBSTNRHI",
    strCategory = "Labs"
  )
}

MakeRSLong <- function() {
  dfRS <- pharmaversesdtm::rs_onco
  dfRS <- dfRS[dfRS$RSTESTCD == "OVRLRESP", ]
  Standardize_Domain(
    dfDomain = dfRS,
    dfSubjects = MakeSubjects(),
    strTestCDCol = "RSTESTCD", strTestCol = "RSTEST",
    strValueCol = "RSSTRESC",
    strCategory = "Disease Response"
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

test_that("Standardize_Domain re-ranks visitnum and timepoint_rank to 1..N", {
  dfSubjects <- data.frame(subject_id = "S1", site = "701")
  dfDomain <- data.frame(
    USUBJID = "S1", VSTESTCD = "SYSBP", VSTEST = "SBP",
    VSSTRESN = c(120, 122, 125),
    VISIT = c("WEEK 2", "WEEK 4", "WEEK 12"),
    VISITNUM = c(3, 7, 12)
  )

  dfLong <- Standardize_Domain(
    dfDomain, dfSubjects,
    strTestCDCol = "VSTESTCD", strTestCol = "VSTEST",
    strValueCol = "VSSTRESN",
    strCategory = "Vital Signs"
  )

  expect_equal(dfLong$timepoint_rank, c(1, 2, 3))
  expect_equal(dfLong$visitnum, c(1, 2, 3))
})

test_that("Standardize_Domain restarts the rank per (subject_id, parameter_id)", {
  dfSubjects <- data.frame(
    subject_id = c("S1", "S2"), site = c("701", "701")
  )
  dfDomain <- data.frame(
    USUBJID = c("S1", "S1", "S2", "S2"),
    VSTESTCD = "SYSBP", VSTEST = "SBP",
    VSSTRESN = c(120, 122, 118, 121),
    VISIT = c("WEEK 4", "WEEK 12", "WEEK 2", "WEEK 8"),
    VISITNUM = c(7, 12, 3, 9)
  )

  dfLong <- Standardize_Domain(
    dfDomain, dfSubjects,
    strTestCDCol = "VSTESTCD", strTestCol = "VSTEST",
    strValueCol = "VSSTRESN",
    strCategory = "Vital Signs"
  )

  dfLong <- dfLong[order(dfLong$subject_id, dfLong$timepoint_rank), ]
  expect_equal(dfLong$timepoint_rank[dfLong$subject_id == "S1"], c(1, 2))
  expect_equal(dfLong$timepoint_rank[dfLong$subject_id == "S2"], c(1, 2))
})

test_that("Standardize_Domain breaks visitnum ties on the VISIT name", {
  dfSubjects <- data.frame(subject_id = "S1", site = "701")
  dfDomain <- data.frame(
    USUBJID = "S1", VSTESTCD = "SYSBP", VSTEST = "SBP",
    VSSTRESN = c(120, 122),
    VISIT = c("WEEK 12", "WEEK 2"),
    VISITNUM = c(5, 5)
  )

  dfLong <- Standardize_Domain(
    dfDomain, dfSubjects,
    strTestCDCol = "VSTESTCD", strTestCol = "VSTEST",
    strValueCol = "VSSTRESN",
    strCategory = "Vital Signs"
  )

  dfLong <- dfLong[order(dfLong$timepoint_rank), ]
  expect_equal(dfLong$visit, c("WEEK 12", "WEEK 2"))
  expect_equal(dfLong$timepoint_rank, c(1, 2))
})

test_that("Standardize_Domain copies a character value into original_category", {
  dfLong <- MakeRSLong()

  expect_equal(
    dfLong$original_category,
    ifelse(nzchar(trimws(dfLong$value)), dfLong$value, NA_character_)
  )
  expect_true(all(is.na(dfLong$original_value)))
})

# --- Transform_Range -------------------------------------------------------------

MakeRangeLong <- function(vValue, vLow, vHigh, strField = "ALT") {
  data.frame(
    studyid = "A", subject_id = "S1", site = "701",
    parameter_id = strField, parameter_name = strField,
    parameter_category_1 = "Labs", parameter_category_2 = strField,
    visit = paste("WEEK", seq_along(vValue)), visitnum = seq_along(vValue),
    value = vValue, low = vLow, high = vHigh
  )
}

test_that("dMaxShareMissingRange decides between RANGE_ and NUM_", {
  dfLong <- MakeRangeLong(c(1, 2, 3), c(NA, 0, 0), c(NA, 4, 4))

  dfRange <- suppressMessages(Transform_Range(dfLong, dMaxShareMissingRange = 0.5))
  expect_setequal(unique(dfRange$parameter_id), "RANGE_ALT")
  expect_equal(dfRange$result, c(NA, 0.5, 0.75))

  dfNum <- suppressMessages(Transform_Range(dfLong, dMaxShareMissingRange = 0.2))
  expect_setequal(unique(dfNum$parameter_id), "NUM_ALT")
  expect_setequal(unique(dfNum$parameter_category_3), "numeric")
  expect_equal(dfNum$result, c(1, 2, 3))
})

# --- Transform_Missing -----------------------------------------------------------

test_that("Transform_Missing keeps an all-NA field and names it in a message (#39)", {
  dfLong <- dplyr::bind_rows(
    MakeRangeLong(c(NA, NA), c(0, 0), c(1, 1), "COLOR"),
    MakeRangeLong(c(10, NA), c(0, 0), c(40, 40), "ALT")
  )

  expect_message(df <- Transform_Missing(dfLong), "COLOR")

  expect_equal(df$result[df$parameter_category_2 == "COLOR"], c(1, 1))
  expect_setequal(unique(df$parameter_id), c("MISS_COLOR", "MISS_ALT"))
})

# --- Transform_OneHot -----------------------------------------------------------

test_that("Transform_OneHot expands to one row per observed level per input row", {
  dfLong <- data.frame(
    studyid = "A", subject_id = c("S1", "S1", "S1", "S1"),
    site = "701",
    parameter_id = "OVRLRESP", parameter_name = "Overall Response",
    parameter_category_1 = "Disease Response",
    parameter_category_2 = "OVRLRESP",
    visit = c("WEEK 2", "WEEK 4", "WEEK 6", "WEEK 8"),
    visitnum = c(3, 4, 5, 6),
    value = c("CR", "PR", "SD", "PD"),
    stringsAsFactors = FALSE
  )

  df <- Transform_OneHot(dfLong)

  expect_equal(nrow(df), 4 * 4)
  expect_setequal(
    unique(df$parameter_id),
    paste0("CAT_OVRLRESP=", c("CR", "PR", "SD", "PD"))
  )
  expect_setequal(unique(df$parameter_category_2), "OVRLRESP")
  expect_setequal(unique(df$parameter_category_3), "categorical")
  expect_true(is.numeric(df$result))
  expect_setequal(unique(df$result), c(0, 1))

  vLevelFromID <- sub("^CAT_OVRLRESP=", "", df$parameter_id)
  expect_equal(df$result, as.numeric(df$original_category == vLevelFromID))
})

test_that("Transform_OneHot supports a custom prefix", {
  dfLong <- data.frame(
    studyid = "A", subject_id = "S1", site = "701",
    parameter_id = "OVRLRESP", parameter_name = "Overall Response",
    parameter_category_1 = "Disease Response",
    parameter_category_2 = "OVRLRESP",
    visit = "WEEK 2", visitnum = 3,
    value = "CR",
    stringsAsFactors = FALSE
  )

  df <- Transform_OneHot(dfLong, strPrefix = "OH")

  expect_equal(df$parameter_id, "OH_OVRLRESP=CR")
})

test_that("Transform_OneHot drops rows with NA or empty value", {
  dfLong <- data.frame(
    studyid = "A", subject_id = c("S1", "S1", "S1"),
    site = "701",
    parameter_id = "OVRLRESP", parameter_name = "Overall Response",
    parameter_category_1 = "Disease Response",
    parameter_category_2 = "OVRLRESP",
    visit = c("WEEK 2", "WEEK 4", "WEEK 6"),
    visitnum = c(3, 4, 5),
    value = c("CR", NA, ""),
    stringsAsFactors = FALSE
  )

  df <- Transform_OneHot(dfLong)

  expect_equal(nrow(df), 1)
  expect_equal(df$parameter_id, "CAT_OVRLRESP=CR")
})

test_that("Transform_OneHot enumerates levels per parameter_category_2", {
  dfLong <- data.frame(
    studyid = "A", subject_id = "S1", site = "701",
    parameter_id = c("OVRLRESP", "OVRLRESP", "TRGRESP", "TRGRESP"),
    parameter_name = c(
      "Overall Response", "Overall Response",
      "Target Response", "Target Response"
    ),
    parameter_category_1 = "Disease Response",
    parameter_category_2 = c("OVRLRESP", "OVRLRESP", "TRGRESP", "TRGRESP"),
    visit = c("WEEK 2", "WEEK 4", "WEEK 2", "WEEK 4"),
    visitnum = c(3, 4, 3, 4),
    value = c("CR", "PR", "CR", "PR"),
    stringsAsFactors = FALSE
  )

  df <- Transform_OneHot(dfLong)

  expect_setequal(
    df$parameter_id[df$parameter_category_2 == "OVRLRESP"],
    c("CAT_OVRLRESP=CR", "CAT_OVRLRESP=PR")
  )
  expect_setequal(
    df$parameter_id[df$parameter_category_2 == "TRGRESP"],
    c("CAT_TRGRESP=CR", "CAT_TRGRESP=PR")
  )
})

test_that("Transform_OneHot returns the empty frame when every value is missing or blank", {
  dfLong <- MakeLBLong()
  dfLong$value <- NA_character_

  dfOut <- Transform_OneHot(dfLong)

  expect_s3_class(dfOut, "data.frame")
  expect_equal(nrow(dfOut), 0)
})
