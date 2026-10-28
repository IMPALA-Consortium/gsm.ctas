# Illustrative EDC-style queries against the bundled SDTM domains.
#
# Regenerated deterministically from `data/dm.rda` etc. via
# `Rscript data-raw/build.R`. Not exposed as a runtime helper -- the shipped
# `.rda` is the artefact.

load("data/dm.rda")
load("data/lb.rda")
load("data/vs.rda")
load("data/eg.rda")
load("data/rs.rda")

BuildRows <- function(df, strTestCDCol, strValueCol, strDomain) {
  data.frame(
    study = df$STUDYID,
    domain = strDomain,
    field = df[[strTestCDCol]],
    subject_id = df$USUBJID,
    visit = df$VISIT,
    parameter_id = df[[strTestCDCol]],
    is_numeric = is.numeric(df[[strValueCol]]),
    value = as.character(df[[strValueCol]]),
    stringsAsFactors = FALSE
  )
}

vPool <- rbind(
  BuildRows(lb, "LBTESTCD", "LBSTRESN", "LB"),
  BuildRows(vs, "VSTESTCD", "VSSTRESN", "VS"),
  BuildRows(eg, "EGTESTCD", "EGSTRESN", "EG"),
  BuildRows(rs, "RSTESTCD", "RSORRES", "RS")
)
vPool <- vPool[!is.na(vPool$visit) & vPool$visit != "", ]

set.seed(123L)
dQueryFrac <- 0.04
dChangeFrac <- 0.20

nRows <- nrow(vPool)
nQueries <- round(nRows * dQueryFrac)
vIdx <- sample.int(nRows, nQueries)
sampled <- vPool[vIdx, , drop = FALSE]

vTexts <- c(
  "Please verify this value against the source document.",
  "Value appears outside expected range, please confirm.",
  "Missing data point requires clarification.",
  "Inconsistency with prior visit data detected.",
  "Value deviates from protocol-specified range.",
  "Please confirm the unit of measurement.",
  "Transcription error suspected, please review.",
  "Duplicate entry flagged for review.",
  "This value conflicts with a related field.",
  "Please provide supporting documentation."
)
vAnswers <- c(
  "Confirmed correct per source.",
  "Value corrected as per source document.",
  "Data entry error, value updated.",
  "Confirmed, no change needed.",
  "Corrected, was a transcription error.",
  "Verified with site, value is accurate.",
  "Updated after reviewing patient chart.",
  "Original value confirmed by investigator."
)
vStatuses <- c("Open", "Answered", "Closed")
vTypes <- c("Monitor", "Data Management")

data_change <- sample(
  c(TRUE, FALSE), nQueries,
  replace = TRUE,
  prob = c(dChangeFrac, 1 - dChangeFrac)
)
query_status <- sample(vStatuses, nQueries, replace = TRUE)
# A resolved change cannot still be "Open".
query_status[data_change & query_status == "Open"] <- "Closed"

query_answer <- sample(vAnswers, nQueries, replace = TRUE)
query_answer[query_status == "Open"] <- NA_character_

value_now <- sampled$value
value_first_entry <- value_now

vChangedNum <- data_change & sampled$is_numeric
if (any(vChangedNum)) {
  vOrig <- suppressWarnings(as.numeric(sampled$value[vChangedNum]))
  vOk <- !is.na(vOrig)
  if (any(vOk)) {
    vNoise <- stats::rnorm(sum(vOk),
      mean = 0,
      sd = pmax(abs(vOrig[vOk]) * 0.3, 0.1)
    )
    vTargets <- which(vChangedNum)[vOk]
    value_first_entry[vTargets] <- as.character(round(vOrig[vOk] + vNoise, 4))
  }
}
vChangedCat <- data_change & !sampled$is_numeric
if (any(vChangedCat)) {
  value_first_entry[vChangedCat] <- NA_character_
}

value_at_query_open <- value_first_entry
value_at_query_close <- ifelse(
  query_status == "Closed", value_now, value_first_entry
)

queries <- data.frame(
  study = sampled$study,
  domain = sampled$domain,
  field = sampled$field,
  subject_id = sampled$subject_id,
  visit = sampled$visit,
  parameter_id = sampled$parameter_id,
  query_text = sample(vTexts, nQueries, replace = TRUE),
  query_answer = query_answer,
  query_status = query_status,
  query_type = sample(vTypes, nQueries, replace = TRUE),
  data_change = data_change,
  value_first_entry = value_first_entry,
  value_at_query_open = value_at_query_open,
  value_at_query_close = value_at_query_close,
  value_now = value_now,
  stringsAsFactors = FALSE,
  row.names = NULL
)

usethis::use_data(queries, overwrite = TRUE, compress = "xz")
