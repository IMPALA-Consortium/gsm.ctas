#' Combine domain inputs into the five CTAS input frames
#'
#' Binds any number of `Input_*()` results together with a subjects frame and
#' emits exactly the five objects [ctas::process_a_study()] consumes: `data`,
#' `subjects`, `parameters`, `custom_timeseries` and `custom_reference_groups`.
#'
#' The per-parameter tuning columns CTAS expects (`time_point_count_min`,
#' `subject_count_min`, ...) are added as `NA`, which instructs CTAS to fall
#' back on the study-level defaults passed to `process_a_study()`. Setting them
#' per parameter is a deliberate later decision, not something the mapping layer
#' should guess.
#'
#' `subjects` carries `studyid` when `strStudyCol` is set (the default), which
#' [Analyze_CTAS()] uses to split a multi-study input by study before scoring.
#' Set `strStudyCol = NULL` to opt out of the multi-study contract.
#'
#' The combined `untransformed` frame is retained but is *not* CTAS input; it is
#' the detail object used for drill-down.
#'
#' @param ... `list` One or more `Input_*()` results, each with `data`,
#'   `parameters` and optionally `untransformed`.
#' @param dfSubjects `data.frame` Result of [Input_Subjects()].
#' @param strStudyCol `character` Study identifier column expected on
#'   `dfSubjects`. `NULL` disables the check.
#'
#' @return `list` with elements `data`, `subjects`, `parameters`,
#'   `custom_timeseries`, `custom_reference_groups` and `untransformed`.
#'
#' @examples
#' Combine_CTAS_Input(
#'   Input_Numeric(data.frame(
#'     studyid = "A", subject_id = "S1", parameter_id = "SYSBP",
#'     parameter_name = "Systolic Blood Pressure",
#'     parameter_category_1 = "Vital Signs",
#'     visit = "WEEK 2", visitnum = 3, value = 120
#'   )),
#'   dfSubjects = Input_Subjects(data.frame(
#'     studyid = "A", subject_id = "S1", site = "701", country = "USA"
#'   ))
#' )
#'
#' @export
Combine_CTAS_Input <- function(..., dfSubjects, strStudyCol = "studyid") {
  lInputs <- list(...)

  if (length(lInputs) == 0) {
    cli::cli_abort("At least one {.cls Input_*} result must be supplied to {.arg ...}.")
  }

  bValid <- vapply(
    lInputs,
    function(lInput) is.list(lInput) && all(c("data", "parameters") %in% names(lInput)),
    logical(1)
  )

  if (!all(bValid)) {
    cli::cli_abort(
      "Every argument in {.arg ...} must be a list with {.field data} and {.field parameters} elements."
    )
  }

  vRequiredSubjects <- c("subject_id", "site", "country", "region")
  if (!is.null(strStudyCol)) {
    vRequiredSubjects <- c(strStudyCol, vRequiredSubjects)
  }
  AssertColumns(dfSubjects, vRequiredSubjects, "dfSubjects")

  dfData <- dplyr::bind_rows(lapply(lInputs, `[[`, "data")) |>
    as.data.frame()

  dfParameters <- dplyr::bind_rows(lapply(lInputs, `[[`, "parameters")) |>
    dplyr::distinct(.data$parameter_id, .keep_all = TRUE) |>
    dplyr::mutate(
      time_point_count_min = NA_real_,
      subject_count_min = NA_real_,
      max_share_missing = NA_real_,
      generate_change_from_baseline = NA,
      timeseries_features_to_calculate = NA_character_,
      use_only_custom_timeseries = NA
    ) |>
    as.data.frame()

  lUntransformed <- lapply(lInputs, `[[`, "untransformed")
  bHasUntransformed <- !vapply(lUntransformed, is.null, logical(1))

  dfUntransformed <- if (any(bHasUntransformed)) {
    as.data.frame(dplyr::bind_rows(lUntransformed[bHasUntransformed]))
  } else {
    EmptyCTASUntransformed()
  }

  list(
    data = dfData,
    subjects = as.data.frame(dfSubjects),
    parameters = dfParameters,
    custom_timeseries = data.frame(
      timeseries_id = character(0),
      parameter_id = character(0),
      timepoint_combo = character(0),
      stringsAsFactors = FALSE
    ),
    custom_reference_groups = data.frame(
      parameter_id = character(0),
      feature = character(0),
      ref_group = character(0),
      stringsAsFactors = FALSE
    ),
    untransformed = dfUntransformed
  )
}
