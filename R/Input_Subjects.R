#' Map a subject-level domain to the CTAS `subjects` frame
#'
#' CTAS requires one row per subject carrying the grouping variables it uses as
#' reference groups: `site`, `country` and `region`.
#'
#' The country derivation is parameterised rather than hard-coded. PDQRM derives
#' country from characters 11-13 of the site identifier; that is a sponsor
#' convention, not a property of SDTM, so it must be supplied by the caller via
#' `fnCountry` instead of being inherited.
#'
#' @param dfDM `data.frame` SDTM DM (or any subject-level domain).
#' @param strSubjectCol `character` Subject identifier column.
#' @param strSiteCol `character` Site identifier column.
#' @param strCountryCol `character` Country column. `NULL` if unavailable, in
#'   which case `country` is derived by `fnCountry`.
#' @param strRegionCol `character` Region column. `NULL` (default) yields `NA`.
#' @param fnCountry `function` Optional. Takes the site vector and returns a
#'   country vector. Overrides `strCountryCol` when supplied.
#'
#' @return `data.frame` with one distinct row per subject and columns
#'   `subject_id`, `site`, `country`, `region`.
#'
#' @examples
#' Input_Subjects(data.frame(
#'   USUBJID = c("S1", "S2"),
#'   SITEID = c("701", "702"),
#'   COUNTRY = c("USA", "USA")
#' ))
#'
#' @export
Input_Subjects <- function(dfDM,
                           strSubjectCol = "USUBJID",
                           strSiteCol = "SITEID",
                           strCountryCol = "COUNTRY",
                           strRegionCol = NULL,
                           fnCountry = NULL) {
  AssertColumns(
    dfDM,
    c(strSubjectCol, strSiteCol,
      if (is.null(fnCountry)) strCountryCol,
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

  data.frame(
    subject_id = as.character(dfDM[[strSubjectCol]]),
    site = vSite,
    country = vCountry,
    region = vRegion,
    stringsAsFactors = FALSE
  ) |>
    dplyr::distinct()
}
