# Tests use the standardised long-format schema published by the mapping layer.
# Helpers below rename the SDTM columns of pharmaverse fixtures so the Input_*
# functions can be exercised with their new defaults.

StdDM <- function(df) {
  data.frame(
    studyid = if ("STUDYID" %in% names(df)) as.character(df$STUDYID) else "STUDY_A",
    subject_id = as.character(df$USUBJID),
    site = as.character(df$SITEID),
    country = if ("COUNTRY" %in% names(df)) as.character(df$COUNTRY) else NA_character_,
    stringsAsFactors = FALSE
  )
}

StdVS <- function(df) {
  data.frame(
    studyid = if ("STUDYID" %in% names(df)) as.character(df$STUDYID) else "STUDY_A",
    subject_id = as.character(df$USUBJID),
    parameter_id = as.character(df$VSTESTCD),
    parameter_name = as.character(df$VSTEST),
    parameter_category_1 = "Vital Signs",
    visit = as.character(df$VISIT),
    visitnum = as.numeric(df$VISITNUM),
    value = as.numeric(df$VSSTRESN),
    stringsAsFactors = FALSE
  )
}

StdLB <- function(df) {
  data.frame(
    studyid = if ("STUDYID" %in% names(df)) as.character(df$STUDYID) else "STUDY_A",
    subject_id = as.character(df$USUBJID),
    parameter_id = as.character(df$LBTESTCD),
    parameter_name = as.character(df$LBTEST),
    parameter_category_1 = "Labs",
    visit = as.character(df$VISIT),
    visitnum = as.numeric(df$VISITNUM),
    value = as.numeric(df$LBSTRESN),
    low = as.numeric(df$LBSTNRLO),
    high = as.numeric(df$LBSTNRHI),
    stringsAsFactors = FALSE
  )
}

vs <- StdVS(pharmaversesdtm::vs)
dm <- StdDM(pharmaversesdtm::dm)

# --- Input_Subjects -----------------------------------------------------------

test_that("Input_Subjects returns one row per subject with the CTAS columns", {
  dfSubjects <- Input_Subjects(dm)

  expect_named(dfSubjects, c("studyid", "subject_id", "site", "country", "region"))
  expect_equal(nrow(dfSubjects), dplyr::n_distinct(dm$subject_id))
  expect_true(all(vapply(dfSubjects, is.character, logical(1))))
})

test_that("Input_Subjects derives country from a supplied function", {
  dfSubjects <- Input_Subjects(
    data.frame(studyid = "A", subject_id = "S1", site = "STUDY-001-DEU-01"),
    strCountryCol = NULL,
    fnCountry = function(vSite) substr(vSite, 11, 13)
  )

  expect_equal(dfSubjects$country, "DEU")
})

test_that("Input_Subjects can opt out of the study contract", {
  dfSubjects <- Input_Subjects(
    data.frame(subject_id = "S1", site = "701", country = "USA"),
    strStudyCol = NULL
  )

  expect_false("studyid" %in% names(dfSubjects))
})

test_that("Input_Subjects errors informatively on missing columns", {
  expect_error(
    Input_Subjects(data.frame(subject_id = "S1")),
    "missing required column"
  )
})

# --- Input_Numeric ------------------------------------------------------------

test_that("Input_Numeric produces the CTAS data and parameters schema", {
  lInput <- Input_Numeric(vs)

  expect_named(lInput, c("data", "parameters", "untransformed"))
  expect_named(lInput$data, c(
    "subject_id", "parameter_id", "timepoint_1_name", "timepoint_2_name",
    "timepoint_rank", "result", "baseline"
  ))
  expect_named(lInput$parameters, c(
    "parameter_id", "parameter_name", "parameter_category_1",
    "parameter_category_2", "parameter_category_3"
  ))
  expect_true(is.numeric(lInput$data$timepoint_rank))
  expect_true(is.numeric(lInput$data$result))
  expect_false(any(is.na(lInput$data$result)))
})

test_that("Input_Numeric derives one parameter per test code", {
  lInput <- Input_Numeric(vs)

  expect_setequal(
    lInput$parameters$parameter_id,
    paste0("NUM_", sort(unique(vs$parameter_id)))
  )
  expect_setequal(lInput$parameters$parameter_id, unique(lInput$data$parameter_id))
})

test_that("Input_Numeric reads parameter_category_1 from the input frame", {
  lInput <- Input_Numeric(vs)

  expect_setequal(lInput$parameters$parameter_category_1, "Vital Signs")
})

test_that("Input_Numeric passes visits unfiltered when strExcludePattern is NULL", {
  # Mapping now filters unscheduled visits, so Input_Numeric's default is a
  # no-op. Confirm it can still filter when asked.
  vsWithUnsch <- vs
  vsWithUnsch$visit[1] <- "UNSCHEDULED 1"

  lInputKept <- Input_Numeric(vsWithUnsch)
  lInputFiltered <- Input_Numeric(vsWithUnsch, strExcludePattern = "unsch")

  expect_true(any(grepl("UNSCHEDULED", lInputKept$data$timepoint_1_name)))
  expect_false(any(grepl("unsch", lInputFiltered$data$timepoint_1_name, ignore.case = TRUE)))
})

test_that("Input_Numeric honours a positive visit pattern", {
  lInput <- Input_Numeric(vs, strVisitPattern = "^WEEK")

  expect_true(all(grepl("^WEEK", lInput$data$timepoint_1_name)))
})

test_that("Input_Numeric returns contiguous ranks within subject and parameter", {
  lInput <- Input_Numeric(vs)

  dfCheck <- lInput$data |>
    dplyr::summarise(
      Contiguous = identical(sort(.data$timepoint_rank), as.numeric(seq_len(dplyr::n()))),
      .by = c("subject_id", "parameter_id")
    )

  expect_true(all(dfCheck$Contiguous))
})

test_that("Input_Numeric supports alternate column names", {
  dfECG <- data.frame(
    STUDY = "A", SUBJ = "S1", CODE = "QT", NAME = "QT Interval",
    VIS = "WEEK 2", VISNUM = 3, RES = 400
  )

  lInput <- Input_Numeric(
    dfECG,
    strSubjectCol = "SUBJ", strTestCDCol = "CODE", strTestCol = "NAME",
    strValueCol = "RES", strVisitCol = "VIS", strVisitNumCol = "VISNUM",
    strStudyCol = "STUDY", strCategoryCol = NULL,
    strCategory = "ECG", strPrefix = "EG"
  )

  expect_equal(lInput$data$parameter_id, "EG_QT")
  expect_equal(lInput$parameters$parameter_category_1, "ECG")
})

test_that("Input_Numeric returns empty typed frames when nothing survives", {
  lInput <- Input_Numeric(vs[vs$value < 0 & !is.na(vs$value), ])

  expect_equal(nrow(lInput$data), 0)
  expect_equal(nrow(lInput$parameters), 0)
  expect_true(is.character(lInput$data$subject_id))
})

# --- Input_Range --------------------------------------------------------------

test_that("Input_Range normalises values by their reference range", {
  dfLB <- data.frame(
    studyid = "A", subject_id = c("S1", "S1"),
    parameter_id = "ALT", parameter_name = "Alanine Aminotransferase",
    parameter_category_1 = "Labs",
    visit = c("WEEK 2", "WEEK 4"), visitnum = c(3, 4),
    value = c(10, 40), low = c(10, 10), high = c(40, 40)
  )

  lInput <- Input_Range(dfLB)

  expect_equal(lInput$data$result, c(0, 1))
  expect_equal(lInput$parameters$parameter_category_3, "range_normalized")
  expect_equal(lInput$parameters$parameter_category_1, "Labs")
  expect_equal(lInput$untransformed$original_value, c(10, 40))
})

test_that("Input_Range drops rows with an unusable reference range", {
  dfLB <- data.frame(
    studyid = "A", subject_id = "S1",
    parameter_id = "ALT", parameter_name = "ALT",
    parameter_category_1 = "Labs",
    visit = c("WEEK 2", "WEEK 4"), visitnum = c(3, 4),
    value = c(10, 40), low = c(10, NA), high = c(40, 40)
  )

  lInput <- Input_Range(dfLB)

  expect_equal(nrow(lInput$data), 1)
})

# --- Input_OneHot -------------------------------------------------------------

test_that("Input_OneHot creates one binary parameter per observed level", {
  dfRS <- data.frame(
    studyid = "A",
    subject_id = c("S1", "S1", "S2", "S2"),
    parameter_id = "OVRLRESP", parameter_name = "Overall Response",
    parameter_category_1 = "Response",
    visit = c("WEEK 2", "WEEK 4", "WEEK 2", "WEEK 4"),
    visitnum = c(3, 4, 3, 4),
    value = c("CR", "PR", "PR", "PR")
  )

  lInput <- Input_OneHot(dfRS)

  expect_setequal(
    lInput$parameters$parameter_id,
    c("CAT_OVRLRESP=CR", "CAT_OVRLRESP=PR")
  )
  expect_setequal(lInput$data$result, c(0, 1))
  expect_equal(nrow(lInput$data), nrow(dfRS) * 2)
  expect_true(all(lInput$parameters$parameter_category_2 == "CAT_OVRLRESP"))
})

test_that("Input_OneHot returns empty frames when no categories are present", {
  dfRS <- data.frame(
    studyid = "A", subject_id = "S1",
    parameter_id = "OVRLRESP", parameter_name = "Overall Response",
    parameter_category_1 = "Response",
    visit = "WEEK 2", visitnum = 3, value = NA_character_
  )

  lInput <- Input_OneHot(dfRS)

  expect_equal(nrow(lInput$data), 0)
  expect_equal(nrow(lInput$parameters), 0)
})

# --- Input_Missing ------------------------------------------------------------

test_that("Input_Missing retains missing rows and encodes the running ratio", {
  dfLB <- data.frame(
    studyid = "A", subject_id = "S1",
    parameter_id = "ALT", parameter_name = "ALT",
    parameter_category_1 = "Labs",
    visit = c("WEEK 2", "WEEK 4"), visitnum = c(3, 4),
    value = c(10, NA)
  )

  lInput <- Input_Missing(dfLB)

  expect_equal(nrow(lInput$data), 2)
  expect_equal(lInput$data$result, c(0, 0.5))
  expect_equal(lInput$parameters$parameter_category_3, "ratio_missing")
})

# --- Combine_CTAS_Input -------------------------------------------------------

test_that("Combine_CTAS_Input emits the five CTAS input frames", {
  lCombined <- Combine_CTAS_Input(
    Input_Numeric(vs),
    dfSubjects = Input_Subjects(dm)
  )

  expect_named(lCombined, c(
    "data", "subjects", "parameters", "custom_timeseries",
    "custom_reference_groups", "untransformed"
  ))
  expect_true("studyid" %in% names(lCombined$subjects))
  expect_equal(nrow(lCombined$custom_timeseries), 0)
  expect_equal(nrow(lCombined$custom_reference_groups), 0)
})

test_that("Combine_CTAS_Input adds the per-parameter tuning columns as NA", {
  lCombined <- Combine_CTAS_Input(
    Input_Numeric(vs),
    dfSubjects = Input_Subjects(dm)
  )

  vTuning <- c(
    "time_point_count_min", "subject_count_min", "max_share_missing",
    "generate_change_from_baseline", "timeseries_features_to_calculate",
    "use_only_custom_timeseries"
  )

  expect_true(all(vTuning %in% names(lCombined$parameters)))
  expect_true(all(is.na(lCombined$parameters[vTuning])))
})

test_that("Combine_CTAS_Input binds several domains and deduplicates parameters", {
  dfLB <- data.frame(
    studyid = "STUDY_A", subject_id = "01-701-1015",
    parameter_id = "ALT", parameter_name = "ALT",
    parameter_category_1 = "Labs",
    visit = c("WEEK 2", "WEEK 4"), visitnum = c(3, 4),
    value = c(10, 40), low = 10, high = 40
  )

  lCombined <- Combine_CTAS_Input(
    Input_Numeric(vs),
    Input_Range(dfLB),
    dfSubjects = Input_Subjects(dm)
  )

  expect_true("RANGE_ALT" %in% lCombined$parameters$parameter_id)
  expect_false(any(duplicated(lCombined$parameters$parameter_id)))
})

test_that("Combine_CTAS_Input validates its arguments", {
  expect_error(
    Combine_CTAS_Input(dfSubjects = Input_Subjects(dm)),
    "At least one"
  )
  expect_error(
    Combine_CTAS_Input(list(data = data.frame()), dfSubjects = Input_Subjects(dm)),
    "must be a list"
  )
  expect_error(
    Combine_CTAS_Input(Input_Numeric(vs), dfSubjects = data.frame(subject_id = "S1")),
    "missing required column"
  )
})

test_that("Combine_CTAS_Input output satisfies ctas::process_a_study input checks", {
  skip_if_not_installed("ctas")

  lCombined <- Combine_CTAS_Input(
    Input_Numeric(vs),
    dfSubjects = Input_Subjects(dm)
  )

  expect_no_error(
    getFromNamespace("check_input_data", "ctas")(
      subjects = lCombined$subjects,
      parameters = lCombined$parameters,
      data = lCombined$data,
      custom_timeseries = lCombined$custom_timeseries,
      custom_reference_groups = lCombined$custom_reference_groups,
      default_timeseries_features_to_calculate = "autocorr;average;sd;unique_value_count_relative",
      default_minimum_timepoints_per_series = 3,
      default_minimum_subjects_per_series = 3,
      default_max_share_missing_timepoints_per_series = 0.5,
      default_generate_change_from_baseline = FALSE,
      autogenerate_timeseries = TRUE
    )
  )
})
