#' SDTM DM (Demographics) domain
#'
#' Verbatim copy of [pharmaversesdtm::dm] shipped with the package so the
#' mapping workflow (`Raw_DM`) can run without `pharmaversesdtm` at runtime.
#'
#' @format A `data.frame` with one row per subject and the standard SDTM DM
#'   columns (`STUDYID`, `USUBJID`, `SITEID`, `COUNTRY`, ...).
#' @source [pharmaversesdtm::dm]
#' @examples
#' data(dm)
#' head(dm)
"dm"

#' SDTM LB (Laboratory) domain
#'
#' Verbatim copy of [pharmaversesdtm::lb].
#'
#' @format A `data.frame` with one row per lab measurement and the standard
#'   SDTM LB columns (`STUDYID`, `USUBJID`, `LBTESTCD`, `LBTEST`, `LBSTRESN`,
#'   `VISIT`, `VISITNUM`, `LBSTNRLO`, `LBSTNRHI`, ...).
#' @source [pharmaversesdtm::lb]
#' @examples
#' data(lb)
#' head(lb)
"lb"

#' SDTM VS (Vital Signs) domain
#'
#' Verbatim copy of [pharmaversesdtm::vs].
#'
#' @format A `data.frame` with one row per vital-signs measurement and the
#'   standard SDTM VS columns (`STUDYID`, `USUBJID`, `VSTESTCD`, `VSTEST`,
#'   `VSSTRESN`, `VISIT`, `VISITNUM`, ...).
#' @source [pharmaversesdtm::vs]
#' @examples
#' data(vs)
#' head(vs)
"vs"

#' SDTM EG (ECG) domain
#'
#' Verbatim copy of [pharmaversesdtm::eg].
#'
#' @format A `data.frame` with one row per ECG measurement and the standard
#'   SDTM EG columns (`STUDYID`, `USUBJID`, `EGTESTCD`, `EGTEST`, `EGSTRESN`,
#'   `VISIT`, `VISITNUM`, ...).
#' @source [pharmaversesdtm::eg]
#' @examples
#' data(eg)
#' head(eg)
"eg"

#' SDTM RS (Disease Response) domain
#'
#' Verbatim copy of [pharmaversesdtm::rs_onco] renamed to `rs` for consistency
#' with the two-letter SDTM domain convention used by every other bundled
#' dataset.
#'
#' @format A `data.frame` with one row per response assessment and the
#'   standard SDTM RS columns (`STUDYID`, `USUBJID`, `RSTESTCD`, `RSTEST`,
#'   `RSORRES`, `VISIT`, `VISITNUM`, ...).
#' @source [pharmaversesdtm::rs_onco]
#' @examples
#' data(rs)
#' head(rs)
"rs"

#' Illustrative EDC query records
#'
#' Synthetic clinical-query records generated deterministically from the
#' bundled SDTM domains (`dm`, `lb`, `vs`, `eg`, `rs`).
#'
#' @format A `data.frame` with 15 columns: `study`, `domain`, `field`,
#'   `subject_id`, `visit`, `parameter_id`, `query_text`, `query_answer`,
#'   `query_status`, `query_type`, `data_change` (logical),
#'   `value_first_entry`, `value_at_query_open`, `value_at_query_close`,
#'   `value_now`.
#' @source `data-raw/queries.R`
#' @examples
#' data(queries)
#' head(queries)
"queries"
