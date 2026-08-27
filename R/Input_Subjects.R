#' Map a subject-level domain to the CTAS `subjects` frame
#'
#' CTAS requires one row per subject carrying the grouping variables it uses as
#' reference groups: `site`, `country` and `region`. `studyid` is added on top
#' so [Analyze_CTAS()] can split a multi-study input by study before scoring.
#'
#' Defaults expect the standardised long-format columns published by the
#' mapping layer (`subject_id`, `site`, `country`, `studyid`); pass explicit
#' SDTM column names to consume raw DM directly.
#'
#' @param dfDM `data.frame` A subject-level domain.
#' @param strSubjectCol `character` Subject identifier column.
#' @param strSiteCol `character` Site identifier column.
#' @param strCountryCol `character` Country column. `NULL` if unavailable, in
#'   which case `country` is derived by `fnCountry`.
#' @param strStudyCol `character` Study identifier column. `NULL` disables the
#'   check and drops `studyid` from the output.
#' @param strRegionCol `character` Region column. `NULL` (default) yields `NA`.
#' @param fnCountry `function` Optional. Takes the site vector and returns a
#'   country vector. Overrides `strCountryCol` when supplied.
#'
#' @return `data.frame` with one distinct row per subject and columns
#'   `studyid` (when `strStudyCol` is set), `subject_id`, `site`, `country`,
#'   `region`.
#'
#' @examples
#' Input_Subjects(data.frame(
#'   studyid = c("A", "A"),
#'   subject_id = c("S1", "S2"),
#'   site = c("701", "702"),
#'   country = c("USA", "USA")
#' ))
#'
#' @export
Input_Subjects <- function(dfDM,
                           strSubjectCol = "subject_id",
                           strSiteCol = "site",
                           strCountryCol = "country",
                           strStudyCol = "studyid",
                           strRegionCol = NULL,
                           fnCountry = NULL) {
  AssertColumns(
    dfDM,
    c(strSubjectCol, strSiteCol,
      if (is.null(fnCountry)) strCountryCol,
      strStudyCol,
      strRegionCol),
    "dfDM"
  )

  vSite <- as.character(dfDM[[strSiteCol]])

  vCountry <- if (!is.null(fnCountry)) {
    as.character(fnCountry(vSite))
  } else if (!is.null(strCountryCol)) {
    as.character(dfDM[[strCountryCol]])
  } else {
    rep(NA_character_, length(vSite))
  }

  vRegion <- if (!is.null(strRegionCol)) {
    as.character(dfDM[[strRegionCol]])
  } else {
    rep(NA_character_, length(vSite))
  }

  dfOut <- data.frame(
    subject_id = as.character(dfDM[[strSubjectCol]]),
    site = vSite,
    country = vCountry,
    region = vRegion,
    stringsAsFactors = FALSE
  )

  if (!is.null(strStudyCol)) {
    dfOut$studyid <- as.character(dfDM[[strStudyCol]])
    dfOut <- dfOut[, c("studyid", "subject_id", "site", "country", "region")]
  }

  dplyr::distinct(dfOut)
}
