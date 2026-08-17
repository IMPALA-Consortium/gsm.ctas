# Shared end-to-end workflow run for test_workflow.R.
#
# `ctas::process_a_study()` is expensive, so the run is deliberately restricted
# to the same small slice used to build `fixtures/ctas_result.rds`: 6 sites and
# 3 vital-signs parameters.

vSites <- sort(unique(pharmaversesdtm::dm$SITEID))[1:6]
dmSmall <- pharmaversesdtm::dm[pharmaversesdtm::dm$SITEID %in% vSites, ]
vsSmall <- pharmaversesdtm::vs[
  pharmaversesdtm::vs$USUBJID %in% dmSmall$USUBJID &
    pharmaversesdtm::vs$VSTESTCD %in% c("SYSBP", "DIABP", "PULSE"),
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

lRaw <- list(
  Raw_DM = as.data.frame(dmSmall),
  Raw_VS = as.data.frame(vsSmall)
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
