# Shared end-to-end workflow run for test_workflow.R.
#
# `ctas::process_a_study()` is expensive, so the run is deliberately restricted
# to a small slice: 6 sites, 3 vital-signs parameters and 3 lab tests. The
# fixture is stacked into two studies (STUDY_A and STUDY_B) so the multi-study
# split in Analyze_CTAS() is exercised end-to-end.

# The workflow layer stacks several packages (workr, gsm.core, gsm.mapping)
# that are Suggests-only. Skip the whole workflow run if any of them - or
# pharmaversesdtm, which supplies the fixture - is missing, rather than making
# the setup file error at load time.
bWorkflowRunnable <- all(vapply(
  c("workr", "gsm.core", "gsm.mapping", "pharmaversesdtm"),
  requireNamespace,
  logical(1),
  quietly = TRUE
))

lMapped <- NULL
lAnalysis <- NULL
vMetricIDs <- c("numeric", "range_normalized", "ratio_missing", "categorical")
vStudyIDs <- c("STUDY_A", "STUDY_B")
lMetricWorkflows <- NULL
dmSmall <- NULL

if (bWorkflowRunnable) {
  vSites <- sort(unique(pharmaversesdtm::dm$SITEID))[1:6]
  dmSmall <- pharmaversesdtm::dm[pharmaversesdtm::dm$SITEID %in% vSites, ]
  vsSmall <- pharmaversesdtm::vs[
    pharmaversesdtm::vs$USUBJID %in% dmSmall$USUBJID &
      pharmaversesdtm::vs$VSTESTCD %in% c("SYSBP", "DIABP", "PULSE"),
  ]
  lbSmall <- pharmaversesdtm::lb[
    pharmaversesdtm::lb$USUBJID %in% dmSmall$USUBJID &
      pharmaversesdtm::lb$LBTESTCD %in% c("ALB", "BILI", "CREAT"),
  ]
  rsSmall <- pharmaversesdtm::rs_onco[
    pharmaversesdtm::rs_onco$USUBJID %in% dmSmall$USUBJID &
      pharmaversesdtm::rs_onco$RSTESTCD == "OVRLRESP",
  ]
  egSmall <- pharmaversesdtm::eg[
    pharmaversesdtm::eg$USUBJID %in% dmSmall$USUBJID &
      pharmaversesdtm::eg$EGTESTCD %in% c("HR", "QT", "RR"),
  ]

  # Stack a two-study fixture by cloning the slice and re-labelling STUDYID
  # plus suffixing SITEID and USUBJID. Cloning is safer than partitioning:
  # each study retains 6 sites and the full three-parameter families, so the
  # CTAS run for either study on its own is well-conditioned.
  StackTwoStudies <- function(df, strSubjectCol = "USUBJID",
                              strSiteCol = "SITEID") {
    dfA <- df
    dfA$STUDYID <- "STUDY_A"

    dfB <- df
    dfB$STUDYID <- "STUDY_B"
    dfB[[strSubjectCol]] <- paste0("B_", dfB[[strSubjectCol]])
    if (length(strSiteCol) > 0 && strSiteCol %in% names(dfB)) {
      dfB[[strSiteCol]] <- paste0("B_", dfB[[strSiteCol]])
    }

    rbind(dfA, dfB)
  }

  dmSmall <- StackTwoStudies(dmSmall)
  vsSmall <- StackTwoStudies(vsSmall, strSiteCol = NULL)
  lbSmall <- StackTwoStudies(lbSmall, strSiteCol = NULL)
  rsSmall <- StackTwoStudies(rsSmall, strSiteCol = NULL)
  egSmall <- StackTwoStudies(egSmall, strSiteCol = NULL)
  vSites <- sort(unique(dmSmall$SITEID))
  vStudyIDs <- sort(unique(dmSmall$STUDYID))

  lMappingWorkflows <- workr::MakeWorkflowList(
    strNames = NULL,
    strPath = system.file("workflow/1_mappings", package = "gsm.ctas"),
    strPackage = NULL
  )

  lMetricWorkflows <- workr::MakeWorkflowList(
    strNames = NULL,
    strPath = system.file("workflow/2_metrics", package = "gsm.ctas"),
    strPackage = NULL
  )

  lRaw <- list(
    Raw_DM = as.data.frame(dmSmall),
    Raw_VS = as.data.frame(vsSmall),
    Raw_LB = as.data.frame(lbSmall),
    Raw_RS = as.data.frame(rsSmall),
    Raw_EG = as.data.frame(egSmall)
  )

  lIngest <- gsm.mapping::Ingest(lRaw, gsm.mapping::CombineSpecs(lMappingWorkflows))

  # CTAS emits `cor()` "standard deviation is zero" warnings for flat series.
  # Expected on real data, so suppressed in tests only.
  lMapped <- suppressWarnings(
    gsm.core::RunWorkflows(lWorkflows = lMappingWorkflows, lData = lIngest)
  )

  lAnalysis <- suppressWarnings(
    gsm.core::RunWorkflows(lWorkflows = lMetricWorkflows, lData = lMapped)
  )
}

