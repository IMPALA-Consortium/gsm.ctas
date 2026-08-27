#' Map a categorical findings frame to CTAS input via one-hot encoding
#'
#' CTAS operates on numeric timeseries, so a categorical result is expanded by
#' [Prepare_Categorical()] into one binary timeseries per observed level. Each
#' level becomes its own `parameter_id`, while all levels share a
#' `parameter_category_2` so they stay grouped for review.
#'
#' @inheritParams Input_Numeric
#' @param strValueCol `character` Categorical result column.
#'
#' @return `list` with elements `data`, `parameters` and `untransformed`.
#'
#' @examples
#' Input_OneHot(data.frame(
#'   studyid = "A",
#'   subject_id = c("S1", "S1"),
#'   parameter_id = c("OVRLRESP", "OVRLRESP"),
#'   parameter_name = c("Overall Response", "Overall Response"),
#'   parameter_category_1 = "Response",
#'   visit = c("WEEK 2", "WEEK 4"),
#'   visitnum = c(3, 4),
#'   value = c("CR", "PR")
#' ))
#'
#' @export
Input_OneHot <- function(dfDomain,
                         strSubjectCol = "subject_id",
                         strTestCDCol = "parameter_id",
                         strTestCol = "parameter_name",
                         strValueCol = "value",
                         strVisitCol = "visit",
                         strVisitNumCol = "visitnum",
                         strStudyCol = "studyid",
                         strCategoryCol = "parameter_category_1",
                         strVisitPattern = NULL,
                         strExcludePattern = NULL,
                         strCategory = NA_character_,
                         strPrefix = "CAT") {
  dfWork <- StandardizeDomain(
    dfDomain,
    strSubjectCol = strSubjectCol,
    strTestCDCol = strTestCDCol,
    strTestCol = strTestCol,
    strValueCol = strValueCol,
    strVisitCol = strVisitCol,
    strVisitNumCol = strVisitNumCol,
    strStudyCol = strStudyCol,
    strCategoryCol = strCategoryCol,
    strVisitPattern = strVisitPattern,
    strExcludePattern = strExcludePattern
  ) |>
    dplyr::mutate(Value = as.character(.data$Value)) |>
    dplyr::filter(!is.na(.data$Value), .data$Value != "") |>
    dplyr::mutate(TestGroup = paste0(.env$strPrefix, "_", .data$TestCD))

  if (nrow(dfWork) == 0) {
    return(list(
      data = EmptyCTASData(),
      parameters = EmptyCTASParameters(),
      untransformed = EmptyCTASUntransformed()
    ))
  }

  # One-hot encode within each test code so that levels of different tests do
  # not bleed into one another.
  lEncoded <- lapply(split(seq_len(nrow(dfWork)), dfWork$TestGroup), function(vRows) {
    dfEncoded <- Prepare_Categorical(
      dfWork$Value[vRows],
      strPrefix = dfWork$TestGroup[vRows][1]
    )
    dfEncoded$SourceRow <- vRows[dfEncoded$RowIndex]
    dfEncoded
  })

  dfEncoded <- do.call(rbind, lEncoded)

  bHasCategory <- "Category" %in% names(dfWork)
  vCategoryLong <- if (bHasCategory) {
    dplyr::coalesce(dfWork$Category[dfEncoded$SourceRow], strCategory)
  } else {
    rep(strCategory, nrow(dfEncoded))
  }

  dfLong <- dplyr::tibble(
    subject_id = dfWork$subject_id[dfEncoded$SourceRow],
    parameter_id = dfEncoded$Level,
    timepoint_1_name = dfWork$timepoint_1_name[dfEncoded$SourceRow],
    timepoint_rank = dfWork$timepoint_rank[dfEncoded$SourceRow],
    result = as.numeric(dfEncoded$Encoded),
    TestGroup = dfWork$TestGroup[dfEncoded$SourceRow],
    TestName = dfWork$TestName[dfEncoded$SourceRow],
    Category = vCategoryLong
  )

  dfParameters <- dfLong |>
    dplyr::distinct(.data$parameter_id, .data$TestGroup, .data$TestName, .data$Category) |>
    dplyr::transmute(
      parameter_id = .data$parameter_id,
      parameter_name = paste0(
        .data$TestName, " = ",
        sub("^.*=", "", .data$parameter_id)
      ),
      parameter_category_1 = .data$Category,
      parameter_category_2 = .data$TestGroup,
      parameter_category_3 = "categorical"
    ) |>
    dplyr::arrange(.data$parameter_id) |>
    as.data.frame()

  dfUntransformed <- dfWork |>
    dplyr::transmute(
      subject_id = .data$subject_id,
      parameter_category_2 = .data$TestGroup,
      timepoint_1_name = .data$timepoint_1_name,
      original_value = NA_real_,
      lower = NA_real_,
      upper = NA_real_,
      original_category = .data$Value
    ) |>
    as.data.frame()

  list(
    data = BuildCTASData(dfLong),
    parameters = dfParameters,
    untransformed = dfUntransformed
  )
}
