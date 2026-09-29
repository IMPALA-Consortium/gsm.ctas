# Illustrative Protocol Deviation records simulated against the bundled DM.
#
# Ports ctasapp's `simulate_pd_data()` (IMPALA-Consortium/ctasapp, feature
# branch `19_pd`, now on main) to gsm.ctas so the shipped `pd.rda` matches
# the ctasapp Field Detail Protocol Deviations tab column contract 1:1.
# Regenerated deterministically via `Rscript data-raw/build.R`.

load("data/dm.rda")

vSCAT <- c(
  "INCLUSION CRITERIA NOT MET",
  "PROHIBITED CONMED",
  "STUDY PROCEDURE NOT DONE",
  "VISIT WINDOW DEVIATION",
  "INFORMED CONSENT ISSUE"
)
lTerms <- list(
  "INCLUSION CRITERIA NOT MET" = c(
    "Subject did not meet all inclusion criteria at screening",
    "Baseline hemoglobin below protocol minimum",
    "Age outside eligible window"
  ),
  "PROHIBITED CONMED" = c(
    "Subject took prohibited concomitant medication",
    "Rescue medication administered outside allowed regimen"
  ),
  "STUDY PROCEDURE NOT DONE" = c(
    "Required assessment not performed at visit",
    "Blood sample not collected per schedule",
    "ECG not performed at required timepoint"
  ),
  "VISIT WINDOW DEVIATION" = c(
    "Visit performed outside protocol window",
    "Follow-up visit conducted late"
  ),
  "INFORMED CONSENT ISSUE" = c(
    "Reconsent not obtained after protocol amendment",
    "Consent form version mismatch at visit"
  )
)
vCatBySCAT <- c(
  "INCLUSION CRITERIA NOT MET" = "MAJOR",
  "PROHIBITED CONMED"          = "IMPORTANT",
  "STUDY PROCEDURE NOT DONE"   = "MINOR",
  "VISIT WINDOW DEVIATION"     = "MINOR",
  "INFORMED CONSENT ISSUE"     = "MAJOR"
)

set.seed(321L)
vPDsPerSite <- c(1L, 5L)
d0 <- as.Date("2023-01-01")
d1 <- as.Date("2024-12-31")
nDaySpan <- as.integer(d1 - d0)

dfSubjects <- data.frame(
  study = as.character(dm$STUDYID),
  site = as.character(dm$SITEID),
  subject_id = as.character(dm$USUBJID),
  stringsAsFactors = FALSE
)

vSites <- unique(dfSubjects$site)
vSites <- vSites[!is.na(vSites)]

lRows <- lapply(vSites, function(strSite) {
  vSubjAtSite <- unique(
    dfSubjects$subject_id[dfSubjects$site == strSite]
  )
  strStudy <- unique(dfSubjects$study[dfSubjects$site == strSite])[1]
  nPD <- sample(seq(vPDsPerSite[1], vPDsPerSite[2]), 1L)
  vSCATi <- sample(vSCAT, nPD, replace = TRUE)
  vTermi <- vapply(vSCATi, function(sc) {
    sample(lTerms[[sc]], 1L)
  }, character(1))
  vStartOffset <- sample.int(nDaySpan, nPD, replace = TRUE)
  vStart <- d0 + vStartOffset
  vEnd <- vStart + sample(0:14, nPD, replace = TRUE)
  data.frame(
    study = strStudy,
    site = strSite,
    subject_id = sample(vSubjAtSite, nPD, replace = TRUE),
    dv_seq = seq_len(nPD),
    dv_term = unname(vTermi),
    dv_decod = unname(vTermi),
    dv_cat = unname(vCatBySCAT[vSCATi]),
    dv_scat = vSCATi,
    dv_start_date = vStart,
    dv_end_date = vEnd,
    stringsAsFactors = FALSE
  )
})

pd <- do.call(rbind, lRows)
rownames(pd) <- NULL

usethis::use_data(pd, overwrite = TRUE, compress = "xz")
