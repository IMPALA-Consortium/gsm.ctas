# End-to-end gsm.ctas pipeline shared by the cookbook and the pkgdown example.
# Runs mapping + metrics + reporting workflows against the bundled SDTM
# datasets and stops at `lReporting$Reporting_Summary`.

library(workr)
library(gsm.mapping)
library(gsm.ctas)

lRaw <- list(
  Raw_DM      = gsm.ctas::dm,
  Raw_LB      = gsm.ctas::lb,
  Raw_VS      = gsm.ctas::vs,
  Raw_EG      = gsm.ctas::eg,
  Raw_RS      = gsm.ctas::rs,
  Raw_Queries = gsm.ctas::queries
)

lMappingWorkflows   <- workr::MakeWorkflowList(strPath = system.file("workflow/1_mappings",  package = "gsm.ctas"))
lMetricWorkflows    <- workr::MakeWorkflowList(strPath = system.file("workflow/2_metrics",   package = "gsm.ctas"))
lReportingWorkflows <- workr::MakeWorkflowList(strPath = system.file("workflow/3_reporting", package = "gsm.ctas"))

lMapped <- suppressWarnings(suppressMessages(workr::RunWorkflows(
  lWorkflows = lMappingWorkflows,
  lData = gsm.mapping::Ingest(lRaw, gsm.mapping::CombineSpecs(lMappingWorkflows))
)))

lAnalysis <- suppressWarnings(suppressMessages(workr::RunWorkflows(
  lWorkflows = lMetricWorkflows,
  lData = lMapped
)))

lReporting <- suppressWarnings(suppressMessages(workr::RunWorkflows(
  lWorkflows = lReportingWorkflows,
  lData = c(lMapped, list(
    lAnalyzed = lAnalysis,
    lMetricWorkflows = lMetricWorkflows
  ))
)))
