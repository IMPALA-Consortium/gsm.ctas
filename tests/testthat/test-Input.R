vs <- pharmaversesdtm::vs
dm <- pharmaversesdtm::dm

# --- Input_Subjects -----------------------------------------------------------

test_that("Input_Subjects returns one row per subject with the CTAS columns", {
  dfSubjects <- Input_Subjects(dm)

  expect_named(dfSubjects, c("subject_id", "site", "country", "region"))
  expect_equal(nrow(dfSubjects), dplyr::n_distinct(dm$USUBJID))
  expect_true(all(vapply(dfSubjects, is.character, logical(1))))
})

test_that("Input_Subjects derives country from a supplied function", {
  dfSubjects <- Input_Subjects(
    data.frame(USUBJID = "S1", SITEID = "STUDY-001-DEU-01"),
    strCountryCol = NULL,
    fnCountry = function(vSite) substr(vSite, 11, 13)
  )

  expect_equal(dfSubjects$country, "DEU")
})

test_that("Input_Subjects errors informatively on missing columns", {
  expect_error(
    Input_Subjects(data.frame(USUBJID = "S1")),
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
    paste0("VS_", sort(unique(vs$VSTESTCD)))
  )
  expect_setequal(lInput$parameters$parameter_id, unique(lInput$data$parameter_id))
})

test_that("Input_Numeric drops unscheduled visits by default", {
  expect_true(any(grepl("UNSCHEDULED", vs$VISIT)))

  lInput <- Input_Numeric(vs)

  expect_false(any(grepl("unsch", lInput$data$timepoint_1_name, ignore.case = TRUE)))
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
    SUBJ = "S1", CODE = "QT", NAME = "QT Interval",
    VIS = "WEEK 2", VISNUM = 3, RES = 400
  )

  lInput <- Input_Numeric(
    dfECG,
    strSubjectCol = "SUBJ", strTestCDCol = "CODE", strTestCol = "NAME",
    strValueCol = "RES", strVisitCol = "VIS", strVisitNumCol = "VISNUM",
    strCategory = "ECG", strPrefix = "EG"
  )

  expect_equal(lInput$data$parameter_id, "EG_QT")
  expect_equal(lInput$parameters$parameter_category_1, "ECG")
})

test_that("Input_Numeric returns empty typed frames when nothing survives", {
  lInput <- Input_Numeric(vs[vs$VSSTRESN < 0 & !is.na(vs$VSSTRESN), ])

  expect_equal(nrow(lInput$data), 0)
  expect_equal(nrow(lInput$parameters), 0)
  expect_true(is.character(lInput$data$subject_id))
})

# --- Input_Range --------------------------------------------------------------

test_that("Input_Range normalises values by their reference range", {
  dfLB <- data.frame(
    USUBJID = c("S1", "S1"),
    LBTESTCD = "ALT", LBTEST = "Alanine Aminotransferase",
    VISIT = c("WEEK 2", "WEEK 4"), VISITNUM = c(3, 4),
    LBSTRESN = c(10, 40), LBSTNRLO = c(10, 10), LBSTNRHI = c(40, 40)
  )

  lInput <- Input_Range(dfLB)

  expect_equal(lInput$data$result, c(0, 1))
  expect_equal(lInput$parameters$parameter_category_3, "range_normalized")
  expect_equal(lInput$untransformed$original_value, c(10, 40))
})

test_that("Input_Range drops rows with an unusable reference range", {
  dfLB <- data.frame(
    USUBJID = "S1", LBTESTCD = "ALT", LBTEST = "ALT",
    VISIT = c("WEEK 2", "WEEK 4"), VISITNUM = c(3, 4),
    LBSTRESN = c(10, 40), LBSTNRLO = c(10, NA), LBSTNRHI = c(40, 40)
  )

  lInput <- Input_Range(dfLB)

  expect_equal(nrow(lInput$data), 1)
})

# --- Input_OneHot -------------------------------------------------------------

test_that("Input_OneHot creates one binary parameter per observed level", {
  dfRS <- data.frame(
    USUBJID = c("S1", "S1", "S2", "S2"),
    RSTESTCD = "OVRLRESP", RSTEST = "Overall Response",
    VISIT = c("WEEK 2", "WEEK 4", "WEEK 2", "WEEK 4"),
    VISITNUM = c(3, 4, 3, 4),
    RSORRES = c("CR", "PR", "PR", "PR")
  )

  lInput <- Input_OneHot(dfRS)

  expect_setequal(
    lInput$parameters$parameter_id,
    c("RS_OVRLRESP=CR", "RS_OVRLRESP=PR")
  )
  expect_setequal(lInput$data$result, c(0, 1))
  expect_equal(nrow(lInput$data), nrow(dfRS) * 2)
  expect_true(all(lInput$parameters$parameter_category_2 == "RS_OVRLRESP"))
})

test_that("Input_OneHot returns empty frames when no categories are present", {
  dfRS <- data.frame(
    USUBJID = "S1", RSTESTCD = "OVRLRESP", RSTEST = "Overall Response",
    VISIT = "WEEK 2", VISITNUM = 3, RSORRES = NA_character_
  )

  lInput <- Input_OneHot(dfRS)

  expect_equal(nrow(lInput$data), 0)
  expect_equal(nrow(lInput$parameters), 0)
})

# --- Input_Missing ------------------------------------------------------------

test_that("Input_Missing retains missing rows and encodes the running ratio", {
  dfLB <- data.frame(
    USUBJID = "S1", LBTESTCD = "ALT", LBTEST = "ALT",
    VISIT = c("WEEK 2", "WEEK 4"), VISITNUM = c(3, 4),
    LBSTRESN = c(10, NA)
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
    USUBJID = "01-701-1015", LBTESTCD = "ALT", LBTEST = "ALT",
    VISIT = c("WEEK 2", "WEEK 4"), VISITNUM = c(3, 4),
    LBSTRESN = c(10, 40), LBSTNRLO = 10, LBSTNRHI = 40
  )

  lCombined <- Combine_CTAS_Input(
    Input_Numeric(vs),
    Input_Range(dfLB),
    dfSubjects = Input_Subjects(dm)
  )

  expect_true("LB_NORM_ALT" %in% lCombined$parameters$parameter_id)
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

  # Only subjects with data are required, but extra subjects must not break the
  # checks; run the ctas validator directly rather than the full study.
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
