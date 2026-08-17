# Shared end-to-end workflow run for test_workflow.R.
#
# `ctas::process_a_study()` is expensive, so the run is deliberately restricted
# to a small slice: 6 sites, 3 vital-signs parameters and 3 lab tests. The lab
# domain is mapped twice, as range-normalised values and as missingness, so the
# slice exercises all three parameter families.

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

# 4 VS features + 4 range-normalised lab features + 3 lab missingness features.
# Missingness gets three rather than four because CTAS returns no `autocorr` for
# those timeseries.
vMetricIDs <- sprintf("ctas%04d", 1:11)

lRaw <- list(
  Raw_DM = as.data.frame(dmSmall),
  Raw_VS = as.data.frame(vsSmall),
  Raw_LB = as.data.frame(lbSmall)
)

lIngest <- gsm.mapping::Ingest(lRaw, gsm.mapping::CombineSpecs(lMappingWorkflows))

# CTAS emits `cor()` "standard deviation is zero" warnings for flat series.
# Expected on real data, so suppressed in tests only.
lMapped <- suppressWarnings(
  gsm.core::RunWorkflows(lWorkflows = lMappingWorkflows, lData = lIngest)
)

lAnalysis <- gsm.core::RunWorkflows(lWorkflows = lMetricWorkflows, lData = lMapped)

lReportingWorkflows <- workr::MakeWorkflowList(
  strNames = NULL,
  strPath = system.file("workflow/3_reporting", package = "gsm.ctas"),
  strPackage = NULL
)

lReporting <- gsm.core::RunWorkflows(
  lWorkflows = lReportingWorkflows,
  lData = c(
    lMapped,
    list(
      lAnalyzed = lAnalysis,
      lWorkflows = lMetricWorkflows
    )
  )
)

lModuleWorkflows <- workr::MakeWorkflowList(
  strNames = NULL,
  strPath = system.file("workflow/4_modules", package = "gsm.ctas"),
  strPackage = NULL
)
