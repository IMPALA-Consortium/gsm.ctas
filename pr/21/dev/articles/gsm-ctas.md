# gsm.ctas end to end

`gsm.ctas` runs the [ctas](https://github.com/IMPALA-Consortium/ctas)
anomaly detection engine inside the
[gsm](https://github.com/Gilead-BioStats/gsm.core) workflow framework,
so that CTAS site scores appear alongside the usual KRIs in a standard
gsm site report.

This vignette walks the whole path – SDTM domains in, rendered KRI
report out – and then covers the two things most users will want to
change: the thresholds, and the set of metrics.

## Installation

``` r

install.packages("pak")
pak::pak("IMPALA-Consortium/ctas")
pak::pak("Gilead-BioStats/gsm.core")
pak::pak("Gilead-BioStats/gsm.mapping")
pak::pak("Gilead-BioStats/gsm.kri")
pak::pak("Gilead-BioStats/gsm.reporting")
pak::pak("IMPALA-Consortium/gsm.ctas")
```

``` r

library(gsm.ctas)
```

## The shape of the pipeline

gsm is a YAML-driven engine: each layer is a directory of workflow
files, and `RunWorkflows()` executes them in order.

    lRaw --Ingest--> lIngest --1_mappings--> lMapped --2_metrics--> lAnalysis
         --3_reporting--> Reporting_* --4_modules--> HTML report

`gsm.ctas` ships all four layers in `inst/workflow/`:

| Layer | Contents |
|----|----|
| `1_mappings` | `DM`, `VS`, `LB`, `SITE`, `STUDY`, plus `CTAS_Input` -\> `CTAS_SiteScores` -\> `CTAS_Detail` |
| `2_metrics` | `ctas0001`-`ctas0011`, one per parameter family x CTAS feature |
| `3_reporting` | `Groups`, `Metrics`, `Results`, `Bounds` |
| `4_modules` | `report_kri_site` |

The important structural point: CTAS is an *all-metrics-at-once* engine.
One
[`ctas::process_a_study()`](https://rdrr.io/pkg/ctas/man/process_a_study.html)
call scores every timeseries x feature x site, so it runs **once**, in
`1_mappings/CTAS_SiteScores.yaml`, and each metric workflow merely
filters the shared `Mapped_CTAS_SiteScores` object down to one parameter
family and one feature.

## Input data

`pharmaversesdtm` provides the SDTM domains. The example is cut down to
six sites and a handful of tests to keep the engine fast.

``` r

vSites <- sort(unique(pharmaversesdtm::dm$SITEID))[1:6]

dfDM <- pharmaversesdtm::dm[pharmaversesdtm::dm$SITEID %in% vSites, ]
dfVS <- pharmaversesdtm::vs[
  pharmaversesdtm::vs$USUBJID %in% dfDM$USUBJID &
    pharmaversesdtm::vs$VSTESTCD %in% c("SYSBP", "DIABP", "PULSE"),
]
dfLB <- pharmaversesdtm::lb[
  pharmaversesdtm::lb$USUBJID %in% dfDM$USUBJID &
    pharmaversesdtm::lb$LBTESTCD %in% c("ALB", "BILI", "CREAT"),
]

lRaw <- list(
  Raw_DM = as.data.frame(dfDM),
  Raw_VS = as.data.frame(dfVS),
  Raw_LB = as.data.frame(dfLB)
)
```

## 1. Mapping and the CTAS run

``` r

lMappingWorkflows <- workr::MakeWorkflowList(
  strNames = NULL,
  strPath = system.file("workflow/1_mappings", package = "gsm.ctas"),
  strPackage = NULL
)

lIngest <- gsm.mapping::Ingest(
  lRaw,
  gsm.mapping::CombineSpecs(lMappingWorkflows)
)
#> ℹ Ingesting data for DM.
#> [INFO] Creating a new temporary DuckDB connection.
#> duckdb keeps downloaded extensions and secrets in a temporary directory:
#> ℹ /tmp/RtmpQqZ56W/duckdb
#> This is removed when the R session ends.
#> • Extensions are re-downloaded each session.
#> • Secrets are lost.
#> ℹ Run duckdb(shared_home = TRUE) (or create ~/.duckdb) to keep them (suitable for most users).
#> ℹ Run duckdb(shared_home = FALSE) to accept the temporary directory (and silence this message).
#> ℹ See ?duckdb_storage for details and alternatives.
#> [INFO] SQL Query complete: 120 rows returned.
#> 
#> [INFO] Disconnected from temporary DuckDB connection.
#> 
#> ℹ Ingesting data for LB.
#> 
#> [INFO] Creating a new temporary DuckDB connection.
#> 
#> duckdb keeps downloaded extensions and secrets in a temporary directory:
#> ℹ /tmp/RtmpQqZ56W/duckdb
#> This is removed when the R session ends.
#> • Extensions are re-downloaded each session.
#> • Secrets are lost.
#> ℹ Run duckdb(shared_home = TRUE) (or create ~/.duckdb) to keep them (suitable for most users).
#> ℹ Run duckdb(shared_home = FALSE) to accept the temporary directory (and silence this message).
#> ℹ See ?duckdb_storage for details and alternatives.
#> [INFO] SQL Query complete: 2158 rows returned.
#> 
#> [INFO] Disconnected from temporary DuckDB connection.
#> 
#> ℹ Ingesting data for VS.
#> 
#> [INFO] Creating a new temporary DuckDB connection.
#> 
#> duckdb keeps downloaded extensions and secrets in a temporary directory:
#> ℹ /tmp/RtmpQqZ56W/duckdb
#> This is removed when the R session ends.
#> • Extensions are re-downloaded each session.
#> • Secrets are lost.
#> ℹ Run duckdb(shared_home = TRUE) (or create ~/.duckdb) to keep them (suitable for most users).
#> ℹ Run duckdb(shared_home = FALSE) to accept the temporary directory (and silence this message).
#> ℹ See ?duckdb_storage for details and alternatives.
#> [INFO] SQL Query complete: 9897 rows returned.
#> 
#> [INFO] Disconnected from temporary DuckDB connection.
#> 
#> ℹ Ingesting data for DM.
#> 
#> [INFO] Creating a new temporary DuckDB connection.
#> 
#> duckdb keeps downloaded extensions and secrets in a temporary directory:
#> ℹ /tmp/RtmpQqZ56W/duckdb
#> This is removed when the R session ends.
#> • Extensions are re-downloaded each session.
#> • Secrets are lost.
#> ℹ Run duckdb(shared_home = TRUE) (or create ~/.duckdb) to keep them (suitable for most users).
#> ℹ Run duckdb(shared_home = FALSE) to accept the temporary directory (and silence this message).
#> ℹ See ?duckdb_storage for details and alternatives.
#> [INFO] SQL Query complete: 120 rows returned.
#> 
#> [INFO] Disconnected from temporary DuckDB connection.
#> 
#> ℹ Ingesting data for VS.
#> 
#> [INFO] Creating a new temporary DuckDB connection.
#> 
#> duckdb keeps downloaded extensions and secrets in a temporary directory:
#> ℹ /tmp/RtmpQqZ56W/duckdb
#> This is removed when the R session ends.
#> • Extensions are re-downloaded each session.
#> • Secrets are lost.
#> ℹ Run duckdb(shared_home = TRUE) (or create ~/.duckdb) to keep them (suitable for most users).
#> ℹ Run duckdb(shared_home = FALSE) to accept the temporary directory (and silence this message).
#> ℹ See ?duckdb_storage for details and alternatives.
#> [INFO] SQL Query complete: 9897 rows returned.
#> 
#> [INFO] Disconnected from temporary DuckDB connection.
#> 
#> ℹ Ingesting data for LB.
#> 
#> [INFO] Creating a new temporary DuckDB connection.
#> 
#> duckdb keeps downloaded extensions and secrets in a temporary directory:
#> ℹ /tmp/RtmpQqZ56W/duckdb
#> This is removed when the R session ends.
#> • Extensions are re-downloaded each session.
#> • Secrets are lost.
#> ℹ Run duckdb(shared_home = TRUE) (or create ~/.duckdb) to keep them (suitable for most users).
#> ℹ Run duckdb(shared_home = FALSE) to accept the temporary directory (and silence this message).
#> ℹ See ?duckdb_storage for details and alternatives.
#> [INFO] SQL Query complete: 2158 rows returned.
#> 
#> [INFO] Disconnected from temporary DuckDB connection.

# CTAS emits `cor()` "standard deviation is zero" warnings for flat series.
# They are genuine data-quality signal, so the package does not suppress them;
# only this vignette does.
lMapped <- suppressWarnings(
  gsm.core::RunWorkflows(lWorkflows = lMappingWorkflows, lData = lIngest)
)
#> [INFO] Running 8 Workflows
#> [INFO] Initializing `Mapped_DM` Workflow
#> [INFO] Checking data against spec
#> [INFO] Workflow Step 1 of 1: `workr::RunQuery`
#> [INFO] Evaluating 2 parameter(s) for `workr::RunQuery`
#> [INFO] df = Raw_DM: Passing lData$Raw_DM.
#> [INFO] strQuery = SELECT * FROM df: No matching data found. Passing 'SELECT * FROM df' as a string.
#> [INFO] Calling `workr::RunQuery`
#> [INFO] Creating a new temporary DuckDB connection.
#> duckdb keeps downloaded extensions and secrets in a temporary directory:
#> ℹ /tmp/RtmpQqZ56W/duckdb
#> This is removed when the R session ends.
#> • Extensions are re-downloaded each session.
#> • Secrets are lost.
#> ℹ Run duckdb(shared_home = TRUE) (or create ~/.duckdb) to keep them (suitable for most users).
#> ℹ Run duckdb(shared_home = FALSE) to accept the temporary directory (and silence this message).
#> ℹ See ?duckdb_storage for details and alternatives.[INFO] SQL Query complete: 120 rows returned.
#> [INFO] Disconnected from temporary DuckDB connection.
#> [INFO] 120x4 data.frame saved as `lData$Mapped_DM`.
#> [INFO] Returning results from final step: 120x4 data.frame`.
#> [INFO] Completed `Mapped_DM` Workflow
#> [INFO] Initializing `Mapped_LB` Workflow
#> [INFO] Checking data against spec
#> [INFO] Workflow Step 1 of 1: `workr::RunQuery`
#> [INFO] Evaluating 2 parameter(s) for `workr::RunQuery`
#> [INFO] df = Raw_LB: Passing lData$Raw_LB.
#> [INFO] strQuery = SELECT * FROM df: No matching data found. Passing 'SELECT * FROM df' as a string.
#> [INFO] Calling `workr::RunQuery`
#> [INFO] Creating a new temporary DuckDB connection.
#> duckdb keeps downloaded extensions and secrets in a temporary directory:
#> ℹ /tmp/RtmpQqZ56W/duckdb
#> This is removed when the R session ends.
#> • Extensions are re-downloaded each session.
#> • Secrets are lost.
#> ℹ Run duckdb(shared_home = TRUE) (or create ~/.duckdb) to keep them (suitable for most users).
#> ℹ Run duckdb(shared_home = FALSE) to accept the temporary directory (and silence this message).
#> ℹ See ?duckdb_storage for details and alternatives.[INFO] SQL Query complete: 2158 rows returned.
#> [INFO] Disconnected from temporary DuckDB connection.
#> [INFO] 2158x8 data.frame saved as `lData$Mapped_LB`.
#> [INFO] Returning results from final step: 2158x8 data.frame`.
#> [INFO] Completed `Mapped_LB` Workflow
#> [INFO] Initializing `Mapped_VS` Workflow
#> [INFO] Checking data against spec
#> [INFO] Workflow Step 1 of 1: `workr::RunQuery`
#> [INFO] Evaluating 2 parameter(s) for `workr::RunQuery`
#> [INFO] df = Raw_VS: Passing lData$Raw_VS.
#> [INFO] strQuery = SELECT * FROM df: No matching data found. Passing 'SELECT * FROM df' as a string.
#> [INFO] Calling `workr::RunQuery`
#> [INFO] Creating a new temporary DuckDB connection.
#> duckdb keeps downloaded extensions and secrets in a temporary directory:
#> ℹ /tmp/RtmpQqZ56W/duckdb
#> This is removed when the R session ends.
#> • Extensions are re-downloaded each session.
#> • Secrets are lost.
#> ℹ Run duckdb(shared_home = TRUE) (or create ~/.duckdb) to keep them (suitable for most users).
#> ℹ Run duckdb(shared_home = FALSE) to accept the temporary directory (and silence this message).
#> ℹ See ?duckdb_storage for details and alternatives.[INFO] SQL Query complete: 9897 rows returned.
#> [INFO] Disconnected from temporary DuckDB connection.
#> [INFO] 9897x6 data.frame saved as `lData$Mapped_VS`.
#> [INFO] Returning results from final step: 9897x6 data.frame`.
#> [INFO] Completed `Mapped_VS` Workflow
#> [INFO] Initializing `Mapped_SITE` Workflow
#> [INFO] Checking data against spec
#> [INFO] Workflow Step 1 of 2: `workr::RunQuery`
#> [INFO] Evaluating 2 parameter(s) for `workr::RunQuery`
#> [INFO] df = Mapped_DM: Passing lData$Mapped_DM.
#> [INFO] strQuery = SELECT
#>   SITEID as GroupID,
#>   MAX(STUDYID) as StudyID,
#>   MAX(COUNTRY) as Country,
#>   SITEID as InvestigatorLastName,
#>   COUNT(DISTINCT USUBJID) as ParticipantCount
#> FROM df
#> GROUP BY SITEID
#> : No matching data found. Passing 'SELECT
#>   SITEID as GroupID,
#>   MAX(STUDYID) as StudyID,
#>   MAX(COUNTRY) as Country,
#>   SITEID as InvestigatorLastName,
#>   COUNT(DISTINCT USUBJID) as ParticipantCount
#> FROM df
#> GROUP BY SITEID
#> ' as a string.
#> [INFO] Calling `workr::RunQuery`
#> [INFO] Creating a new temporary DuckDB connection.
#> duckdb keeps downloaded extensions and secrets in a temporary directory:
#> ℹ /tmp/RtmpQqZ56W/duckdb
#> This is removed when the R session ends.
#> • Extensions are re-downloaded each session.
#> • Secrets are lost.
#> ℹ Run duckdb(shared_home = TRUE) (or create ~/.duckdb) to keep them (suitable for most users).
#> ℹ Run duckdb(shared_home = FALSE) to accept the temporary directory (and silence this message).
#> ℹ See ?duckdb_storage for details and alternatives.[INFO] SQL Query complete: 6 rows returned.
#> [INFO] Disconnected from temporary DuckDB connection.
#> [INFO] 6x5 data.frame saved as `lData$Temp_SiteWide`.
#> [INFO] Workflow Step 2 of 2: `gsm.mapping::MakeLongMeta`
#> [INFO] Evaluating 2 parameter(s) for `gsm.mapping::MakeLongMeta`
#> [INFO] data = Temp_SiteWide: Passing lData$Temp_SiteWide.
#> [INFO] strGroupLevel = Site: No matching data found. Passing 'Site' as a string.
#> [INFO] Calling `gsm.mapping::MakeLongMeta`
#> [INFO] 24x4 data.frame saved as `lData$Mapped_SITE`.
#> [INFO] Returning results from final step: 24x4 data.frame`.
#> [INFO] Completed `Mapped_SITE` Workflow
#> [INFO] Initializing `Mapped_STUDY` Workflow
#> [INFO] Checking data against spec
#> [INFO] Workflow Step 1 of 2: `workr::RunQuery`
#> [INFO] Evaluating 2 parameter(s) for `workr::RunQuery`
#> [INFO] df = Mapped_DM: Passing lData$Mapped_DM.
#> [INFO] strQuery = SELECT
#>   STUDYID as GroupID,
#>   COUNT(DISTINCT USUBJID) as ParticipantCount,
#>   COUNT(DISTINCT SITEID) as SiteCount
#> FROM df
#> GROUP BY STUDYID
#> : No matching data found. Passing 'SELECT
#>   STUDYID as GroupID,
#>   COUNT(DISTINCT USUBJID) as ParticipantCount,
#>   COUNT(DISTINCT SITEID) as SiteCount
#> FROM df
#> GROUP BY STUDYID
#> ' as a string.
#> [INFO] Calling `workr::RunQuery`
#> [INFO] Creating a new temporary DuckDB connection.
#> duckdb keeps downloaded extensions and secrets in a temporary directory:
#> ℹ /tmp/RtmpQqZ56W/duckdb
#> This is removed when the R session ends.
#> • Extensions are re-downloaded each session.
#> • Secrets are lost.
#> ℹ Run duckdb(shared_home = TRUE) (or create ~/.duckdb) to keep them (suitable for most users).
#> ℹ Run duckdb(shared_home = FALSE) to accept the temporary directory (and silence this message).
#> ℹ See ?duckdb_storage for details and alternatives.[INFO] SQL Query complete: 1 rows returned.
#> [INFO] Disconnected from temporary DuckDB connection.
#> [INFO] 1x3 data.frame saved as `lData$Temp_StudyWide`.
#> [INFO] Workflow Step 2 of 2: `gsm.mapping::MakeLongMeta`
#> [INFO] Evaluating 2 parameter(s) for `gsm.mapping::MakeLongMeta`
#> [INFO] data = Temp_StudyWide: Passing lData$Temp_StudyWide.
#> [INFO] strGroupLevel = Study: No matching data found. Passing 'Study' as a string.
#> [INFO] Calling `gsm.mapping::MakeLongMeta`
#> [INFO] 2x4 data.frame saved as `lData$Mapped_STUDY`.
#> [INFO] Returning results from final step: 2x4 data.frame`.
#> [INFO] Completed `Mapped_STUDY` Workflow
#> [INFO] Initializing `Mapped_CTAS_Input` Workflow
#> [INFO] Checking data against spec
#> [INFO] Workflow Step 1 of 5: `gsm.ctas::Input_Subjects`
#> [INFO] Evaluating 4 parameter(s) for `gsm.ctas::Input_Subjects`
#> [INFO] dfDM = Mapped_DM: Passing lData$Mapped_DM.
#> [INFO] strSubjectCol = USUBJID: No matching data found. Passing 'USUBJID' as a string.
#> [INFO] strSiteCol = SITEID: No matching data found. Passing 'SITEID' as a string.
#> [INFO] strCountryCol = COUNTRY: No matching data found. Passing 'COUNTRY' as a string.
#> [INFO] Calling `gsm.ctas::Input_Subjects`
#> [INFO] 120x4 data.frame saved as `lData$Temp_CTAS_Subjects`.
#> [INFO] Workflow Step 2 of 5: `gsm.ctas::Input_Numeric`
#> [INFO] Evaluating 10 parameter(s) for `gsm.ctas::Input_Numeric`
#> [INFO] dfDomain = Mapped_VS: Passing lData$Mapped_VS.
#> [INFO] strSubjectCol = USUBJID: No matching data found. Passing 'USUBJID' as a string.
#> [INFO] strTestCDCol = VSTESTCD: No matching data found. Passing 'VSTESTCD' as a string.
#> [INFO] strTestCol = VSTEST: No matching data found. Passing 'VSTEST' as a string.
#> [INFO] strValueCol = VSSTRESN: No matching data found. Passing 'VSSTRESN' as a string.
#> [INFO] strVisitCol = VISIT: No matching data found. Passing 'VISIT' as a string.
#> [INFO] strVisitNumCol = VISITNUM: No matching data found. Passing 'VISITNUM' as a string.
#> [INFO] strExcludePattern = unsch: No matching data found. Passing 'unsch' as a string.
#> [INFO] strCategory = Vital Signs: No matching data found. Passing 'Vital Signs' as a string.
#> [INFO] strPrefix = VS: No matching data found. Passing 'VS' as a string.
#> [INFO] Calling `gsm.ctas::Input_Numeric`
#> [INFO] list of length 3 saved as `lData$Temp_CTAS_VS`.
#> [INFO] Workflow Step 3 of 5: `gsm.ctas::Input_Range`
#> [INFO] Evaluating 12 parameter(s) for `gsm.ctas::Input_Range`
#> [INFO] dfDomain = Mapped_LB: Passing lData$Mapped_LB.
#> [INFO] strSubjectCol = USUBJID: No matching data found. Passing 'USUBJID' as a string.
#> [INFO] strTestCDCol = LBTESTCD: No matching data found. Passing 'LBTESTCD' as a string.
#> [INFO] strTestCol = LBTEST: No matching data found. Passing 'LBTEST' as a string.
#> [INFO] strValueCol = LBSTRESN: No matching data found. Passing 'LBSTRESN' as a string.
#> [INFO] strLowCol = LBSTNRLO: No matching data found. Passing 'LBSTNRLO' as a string.
#> [INFO] strHighCol = LBSTNRHI: No matching data found. Passing 'LBSTNRHI' as a string.
#> [INFO] strVisitCol = VISIT: No matching data found. Passing 'VISIT' as a string.
#> [INFO] strVisitNumCol = VISITNUM: No matching data found. Passing 'VISITNUM' as a string.
#> [INFO] strExcludePattern = unsch: No matching data found. Passing 'unsch' as a string.
#> [INFO] strCategory = Labs: No matching data found. Passing 'Labs' as a string.
#> [INFO] strPrefix = LB_NORM: No matching data found. Passing 'LB_NORM' as a string.
#> [INFO] Calling `gsm.ctas::Input_Range`
#> [INFO] list of length 3 saved as `lData$Temp_CTAS_LB_Range`.
#> [INFO] Workflow Step 4 of 5: `gsm.ctas::Input_Missing`
#> [INFO] Evaluating 10 parameter(s) for `gsm.ctas::Input_Missing`
#> [INFO] dfDomain = Mapped_LB: Passing lData$Mapped_LB.
#> [INFO] strSubjectCol = USUBJID: No matching data found. Passing 'USUBJID' as a string.
#> [INFO] strTestCDCol = LBTESTCD: No matching data found. Passing 'LBTESTCD' as a string.
#> [INFO] strTestCol = LBTEST: No matching data found. Passing 'LBTEST' as a string.
#> [INFO] strValueCol = LBSTRESN: No matching data found. Passing 'LBSTRESN' as a string.
#> [INFO] strVisitCol = VISIT: No matching data found. Passing 'VISIT' as a string.
#> [INFO] strVisitNumCol = VISITNUM: No matching data found. Passing 'VISITNUM' as a string.
#> [INFO] strExcludePattern = unsch: No matching data found. Passing 'unsch' as a string.
#> [INFO] strCategory = Labs: No matching data found. Passing 'Labs' as a string.
#> [INFO] strPrefix = LB_MISS: No matching data found. Passing 'LB_MISS' as a string.
#> [INFO] Calling `gsm.ctas::Input_Missing`
#> [INFO] list of length 3 saved as `lData$Temp_CTAS_LB_Missing`.
#> [INFO] Workflow Step 5 of 5: `gsm.ctas::Combine_CTAS_Input`
#> [INFO] Evaluating 4 parameter(s) for `gsm.ctas::Combine_CTAS_Input`
#> [INFO] dfVS = Temp_CTAS_VS: Passing lData$Temp_CTAS_VS.
#> [INFO] dfLBRange = Temp_CTAS_LB_Range: Passing lData$Temp_CTAS_LB_Range.
#> [INFO] dfLBMissing = Temp_CTAS_LB_Missing: Passing lData$Temp_CTAS_LB_Missing.
#> [INFO] dfSubjects = Temp_CTAS_Subjects: Passing lData$Temp_CTAS_Subjects.
#> [INFO] Calling `gsm.ctas::Combine_CTAS_Input`
#> [INFO] list of length 6 saved as `lData$Mapped_CTAS_Input`.
#> [INFO] Returning results from final step: list of length 6`.
#> [INFO] Completed `Mapped_CTAS_Input` Workflow
#> [INFO] Initializing `Mapped_CTAS_SiteScores` Workflow
#> [INFO] Checking data against spec
#> [INFO] Workflow Step 1 of 2: `gsm.ctas::Analyze_CTAS`
#> [INFO] Evaluating 8 parameter(s) for `gsm.ctas::Analyze_CTAS`
#> [INFO] lInput = Mapped_CTAS_Input: Passing lData$Mapped_CTAS_Input.
#> [INFO] strFeatures = Features: Passing lMeta$Features.
#> [INFO] nMinTimepoints = MinTimepoints: Passing lMeta$MinTimepoints.
#> [INFO] nMinSubjects = MinSubjects: Passing lMeta$MinSubjects.
#> [INFO] dMaxShareMissing = MaxShareMissing: Passing lMeta$MaxShareMissing.
#> [INFO] strScoringMethod = ScoringMethod: Passing lMeta$ScoringMethod.
#> [INFO] strPadjustMethod = PadjustMethod: Passing lMeta$PadjustMethod.
#> [INFO] nSeed = Seed: Passing lMeta$Seed.
#> [INFO] Calling `gsm.ctas::Analyze_CTAS`
#> [INFO] list of length 4 saved as `lData$Temp_CTAS_Result`.
#> [INFO] Workflow Step 2 of 2: `gsm.ctas::Combine_CTAS_Scores`
#> [INFO] Evaluating 2 parameter(s) for `gsm.ctas::Combine_CTAS_Scores`
#> [INFO] lResult = Temp_CTAS_Result: Passing lData$Temp_CTAS_Result.
#> [INFO] lInput = Mapped_CTAS_Input: Passing lData$Mapped_CTAS_Input.
#> [INFO] Calling `gsm.ctas::Combine_CTAS_Scores`
#> [INFO] 324x13 data.frame saved as `lData$Mapped_CTAS_SiteScores`.
#> [INFO] Returning results from final step: 324x13 data.frame`.
#> [INFO] Completed `Mapped_CTAS_SiteScores` Workflow
#> [INFO] Initializing `Mapped_CTAS_Detail` Workflow
#> [INFO] Checking data against spec
#> [INFO] Workflow Step 1 of 1: `gsm.ctas::Combine_CTAS_Detail`
#> [INFO] Evaluating 2 parameter(s) for `gsm.ctas::Combine_CTAS_Detail`
#> [INFO] dfScores = Mapped_CTAS_SiteScores: Passing lData$Mapped_CTAS_SiteScores.
#> [INFO] lInput = Mapped_CTAS_Input: Passing lData$Mapped_CTAS_Input.
#> [INFO] Calling `gsm.ctas::Combine_CTAS_Detail`
#> [INFO] list of length 3 saved as `lData$Mapped_CTAS_Detail`.
#> [INFO] Returning results from final step: list of length 3`.
#> [INFO] Completed `Mapped_CTAS_Detail` Workflow

names(lMapped)
#> [1] "Mapped_DM"              "Mapped_LB"              "Mapped_VS"             
#> [4] "Mapped_SITE"            "Mapped_STUDY"           "Mapped_CTAS_Input"     
#> [7] "Mapped_CTAS_SiteScores" "Mapped_CTAS_Detail"
```

Labs are mapped **twice** from the same domain, because the two
questions are different:

- [`Input_Range()`](../reference/Input_Range.md) -\> `LB_NORM_*` – do a
  site’s *values* deviate, once the reference range has made different
  tests comparable?
- [`Input_Missing()`](../reference/Input_Missing.md) -\> `LB_MISS_*` –
  does its *completeness* deviate? The value-based input drops missing
  results, so it is structurally blind to this.

`Mapped_CTAS_SiteScores` is the shared result: one row per timeseries x
feature x site, carrying the identifiers needed to tell the families
apart.

``` r

utils::head(lMapped$Mapped_CTAS_SiteScores, 3)
#>           timeseries_id site country region feature pvalue_kstest_logp
#> 1 ts_1_autogen_original  701     USA   <NA>      sd          0.1171308
#> 2 ts_1_autogen_original  702     USA   <NA>      sd          0.2400736
#> 3 ts_1_autogen_original  703     USA   <NA>      sd          0.4049458
#>   kstest_statistic fdr_corrected_pvalue_logp ref_group subject_count
#> 1        0.1500000                0.01947527    global            28
#> 2        0.7222222                0.04761386    global             1
#> 3        0.2691257                0.08192151    global            12
#>   parameter_id parameter_category_1 parameter_category_3
#> 1  LB_MISS_ALB                 Labs        ratio_missing
#> 2  LB_MISS_ALB                 Labs        ratio_missing
#> 3  LB_MISS_ALB                 Labs        ratio_missing

unique(lMapped$Mapped_CTAS_SiteScores[
  , c("parameter_category_1", "parameter_category_3")
])
#>     parameter_category_1 parameter_category_3
#> 1                   Labs        ratio_missing
#> 109                 Labs     range_normalized
#> 253          Vital Signs              numeric
```

The mapping functions also work directly, outside a workflow:

``` r

lInput <- Combine_CTAS_Input(
  dfVS = Input_Numeric(
    dfDomain = lMapped$Mapped_VS,
    strSubjectCol = "USUBJID",
    strTestCDCol = "VSTESTCD",
    strTestCol = "VSTEST",
    strValueCol = "VSSTRESN",
    strVisitCol = "VISIT",
    strVisitNumCol = "VISITNUM",
    strCategory = "Vital Signs",
    strPrefix = "VS"
  ),
  dfSubjects = Input_Subjects(
    dfDM = lMapped$Mapped_DM,
    strSubjectCol = "USUBJID",
    strSiteCol = "SITEID",
    strCountryCol = "COUNTRY"
  )
)

names(lInput)
#> [1] "data"                    "subjects"               
#> [3] "parameters"              "custom_timeseries"      
#> [5] "custom_reference_groups" "untransformed"
```

## 2. Metrics

Each metric filters the shared scores to one family and one feature,
then aggregates timeseries into the gsm `Analysis_Analyzed` contract.

``` r

lMetricWorkflows <- workr::MakeWorkflowList(
  strNames = NULL,
  strPath = system.file("workflow/2_metrics", package = "gsm.ctas"),
  strPackage = NULL
)

lAnalysis <- gsm.core::RunWorkflows(
  lWorkflows = lMetricWorkflows,
  lData = lMapped
)
#> [INFO] Running 11 Workflows
#> [INFO] Initializing `Analysis_ctas0001` Workflow
#> [INFO] Checking data against spec
#> [INFO] Workflow Step 1 of 7: `workr::RunQuery`
#> [INFO] Evaluating 2 parameter(s) for `workr::RunQuery`
#> [INFO] df = Mapped_SITE: Passing lData$Mapped_SITE.
#> [INFO] strQuery = SELECT DISTINCT GroupID FROM df: No matching data found. Passing 'SELECT DISTINCT GroupID FROM df' as a string.
#> [INFO] Calling `workr::RunQuery`
#> [INFO] Creating a new temporary DuckDB connection.
#> duckdb keeps downloaded extensions and secrets in a temporary directory:
#> ℹ /tmp/RtmpQqZ56W/duckdb
#> This is removed when the R session ends.
#> • Extensions are re-downloaded each session.
#> • Secrets are lost.
#> ℹ Run duckdb(shared_home = TRUE) (or create ~/.duckdb) to keep them (suitable for most users).
#> ℹ Run duckdb(shared_home = FALSE) to accept the temporary directory (and silence this message).
#> ℹ See ?duckdb_storage for details and alternatives.
#> [INFO] SQL Query complete: 6 rows returned.
#> 
#> [INFO] Disconnected from temporary DuckDB connection.
#> 
#> [INFO] 6x1 data.frame saved as `lData$Temp_GroupIDs`.
#> 
#> [INFO] Workflow Step 2 of 7: `dplyr::pull`
#> 
#> [INFO] Evaluating 2 parameter(s) for `dplyr::pull`
#> 
#> [INFO] .data = Temp_GroupIDs: Passing lData$Temp_GroupIDs.
#> 
#> [INFO] var = GroupID: No matching data found. Passing 'GroupID' as a string.
#> 
#> [INFO] Calling `dplyr::pull`
#> 
#> [INFO] character of length 6 saved as `lData$vGroupIDs`.
#> 
#> [INFO] Workflow Step 3 of 7: `gsm.core::ParseThreshold`
#> 
#> [INFO] Evaluating 1 parameter(s) for `gsm.core::ParseThreshold`
#> 
#> [INFO] strThreshold = Threshold: Passing lMeta$Threshold.
#> 
#> [INFO] Calling `gsm.core::ParseThreshold`
#> 
#> Parsed 0.842, 2.326 to numeric vector: 0.842, 2.326
#> [INFO] double of length 2 saved as `lData$vThreshold`.
#> 
#> [INFO] Workflow Step 4 of 7: `gsm.ctas::Summarize_CTAS`
#> 
#> [INFO] Evaluating 8 parameter(s) for `gsm.ctas::Summarize_CTAS`
#> 
#> [INFO] dfSiteScores = Mapped_CTAS_SiteScores: Passing lData$Mapped_CTAS_SiteScores.
#> 
#> [INFO] strFeature = Feature: Passing lMeta$Feature.
#> 
#> [INFO] strGroupLevel = GroupLevel: Passing lMeta$GroupLevel.
#> 
#> [INFO] strDomain = Domain: Passing lMeta$Domain.
#> 
#> [INFO] strTransformation = Transformation: Passing lMeta$Transformation.
#> 
#> [INFO] vGroupIDs = vGroupIDs: Passing lData$vGroupIDs.
#> 
#> [INFO] dHigh = TriggerHigh: Passing lMeta$TriggerHigh.
#> 
#> [INFO] dLow = TriggerLow: Passing lMeta$TriggerLow.
#> 
#> [INFO] Calling `gsm.ctas::Summarize_CTAS`
#> 
#> [INFO] 6x6 data.frame saved as `lData$Analysis_Analyzed`.
#> 
#> [INFO] Workflow Step 5 of 7: `gsm.ctas::Flag_CTAS`
#> 
#> [INFO] Evaluating 2 parameter(s) for `gsm.ctas::Flag_CTAS`
#> 
#> [INFO] dfAnalyzed = Analysis_Analyzed: Passing lData$Analysis_Analyzed.
#> 
#> [INFO] vThreshold = vThreshold: Passing lData$vThreshold.
#> 
#> [INFO] Calling `gsm.ctas::Flag_CTAS`
#> 
#> ℹ Sorted dfFlagged using custom Flag order: 2.Sorted dfFlagged using custom Flag order: 1.Sorted dfFlagged using custom Flag order: 0.
#> 
#> [INFO] 6x7 data.frame saved as `lData$Analysis_Flagged`.
#> 
#> [INFO] Workflow Step 6 of 7: `gsm.core::Summarize`
#> 
#> [INFO] Evaluating 1 parameter(s) for `gsm.core::Summarize`
#> 
#> [INFO] dfFlagged = Analysis_Flagged: Passing lData$Analysis_Flagged.
#> 
#> [INFO] Calling `gsm.core::Summarize`
#> 
#> [INFO] 6x7 data.frame saved as `lData$Analysis_Summary`.
#> 
#> [INFO] Workflow Step 7 of 7: `list`
#> 
#> [INFO] Evaluating 4 parameter(s) for `list`
#> 
#> [INFO] ID = ID: Passing lMeta$ID.
#> 
#> [INFO] Analysis_Analyzed = Analysis_Analyzed: Passing lData$Analysis_Analyzed.
#> 
#> [INFO] Analysis_Flagged = Analysis_Flagged: Passing lData$Analysis_Flagged.
#> 
#> [INFO] Analysis_Summary = Analysis_Summary: Passing lData$Analysis_Summary.
#> 
#> [INFO] Calling `list`
#> 
#> [INFO] list of length 4 saved as `lData$lAnalysis`.
#> 
#> [INFO] Returning results from final step: list of length 4`.
#> 
#> [INFO] Completed `Analysis_ctas0001` Workflow
#> 
#> [INFO] Initializing `Analysis_ctas0002` Workflow
#> 
#> [INFO] Checking data against spec
#> 
#> [INFO] Workflow Step 1 of 7: `workr::RunQuery`
#> 
#> [INFO] Evaluating 2 parameter(s) for `workr::RunQuery`
#> 
#> [INFO] df = Mapped_SITE: Passing lData$Mapped_SITE.
#> 
#> [INFO] strQuery = SELECT DISTINCT GroupID FROM df: No matching data found. Passing 'SELECT DISTINCT GroupID FROM df' as a string.
#> 
#> [INFO] Calling `workr::RunQuery`
#> 
#> [INFO] Creating a new temporary DuckDB connection.
#> 
#> duckdb keeps downloaded extensions and secrets in a temporary directory:
#> ℹ /tmp/RtmpQqZ56W/duckdb
#> This is removed when the R session ends.
#> • Extensions are re-downloaded each session.
#> • Secrets are lost.
#> ℹ Run duckdb(shared_home = TRUE) (or create ~/.duckdb) to keep them (suitable for most users).
#> ℹ Run duckdb(shared_home = FALSE) to accept the temporary directory (and silence this message).
#> ℹ See ?duckdb_storage for details and alternatives.
#> [INFO] SQL Query complete: 6 rows returned.
#> 
#> [INFO] Disconnected from temporary DuckDB connection.
#> 
#> [INFO] 6x1 data.frame saved as `lData$Temp_GroupIDs`.
#> 
#> [INFO] Workflow Step 2 of 7: `dplyr::pull`
#> 
#> [INFO] Evaluating 2 parameter(s) for `dplyr::pull`
#> 
#> [INFO] .data = Temp_GroupIDs: Passing lData$Temp_GroupIDs.
#> 
#> [INFO] var = GroupID: No matching data found. Passing 'GroupID' as a string.
#> 
#> [INFO] Calling `dplyr::pull`
#> 
#> [INFO] character of length 6 saved as `lData$vGroupIDs`.
#> 
#> [INFO] Workflow Step 3 of 7: `gsm.core::ParseThreshold`
#> 
#> [INFO] Evaluating 1 parameter(s) for `gsm.core::ParseThreshold`
#> 
#> [INFO] strThreshold = Threshold: Passing lMeta$Threshold.
#> 
#> [INFO] Calling `gsm.core::ParseThreshold`
#> 
#> Parsed 0.842, 2.326 to numeric vector: 0.842, 2.326
#> [INFO] double of length 2 saved as `lData$vThreshold`.
#> 
#> [INFO] Workflow Step 4 of 7: `gsm.ctas::Summarize_CTAS`
#> 
#> [INFO] Evaluating 8 parameter(s) for `gsm.ctas::Summarize_CTAS`
#> 
#> [INFO] dfSiteScores = Mapped_CTAS_SiteScores: Passing lData$Mapped_CTAS_SiteScores.
#> 
#> [INFO] strFeature = Feature: Passing lMeta$Feature.
#> 
#> [INFO] strGroupLevel = GroupLevel: Passing lMeta$GroupLevel.
#> 
#> [INFO] strDomain = Domain: Passing lMeta$Domain.
#> 
#> [INFO] strTransformation = Transformation: Passing lMeta$Transformation.
#> 
#> [INFO] vGroupIDs = vGroupIDs: Passing lData$vGroupIDs.
#> 
#> [INFO] dHigh = TriggerHigh: Passing lMeta$TriggerHigh.
#> 
#> [INFO] dLow = TriggerLow: Passing lMeta$TriggerLow.
#> 
#> [INFO] Calling `gsm.ctas::Summarize_CTAS`
#> 
#> [INFO] 6x6 data.frame saved as `lData$Analysis_Analyzed`.
#> 
#> [INFO] Workflow Step 5 of 7: `gsm.ctas::Flag_CTAS`
#> 
#> [INFO] Evaluating 2 parameter(s) for `gsm.ctas::Flag_CTAS`
#> 
#> [INFO] dfAnalyzed = Analysis_Analyzed: Passing lData$Analysis_Analyzed.
#> 
#> [INFO] vThreshold = vThreshold: Passing lData$vThreshold.
#> 
#> [INFO] Calling `gsm.ctas::Flag_CTAS`
#> 
#> ℹ Sorted dfFlagged using custom Flag order: 2.Sorted dfFlagged using custom Flag order: 1.Sorted dfFlagged using custom Flag order: 0.
#> 
#> [INFO] 6x7 data.frame saved as `lData$Analysis_Flagged`.
#> 
#> [INFO] Workflow Step 6 of 7: `gsm.core::Summarize`
#> 
#> [INFO] Evaluating 1 parameter(s) for `gsm.core::Summarize`
#> 
#> [INFO] dfFlagged = Analysis_Flagged: Passing lData$Analysis_Flagged.
#> 
#> [INFO] Calling `gsm.core::Summarize`
#> 
#> [INFO] 6x7 data.frame saved as `lData$Analysis_Summary`.
#> 
#> [INFO] Workflow Step 7 of 7: `list`
#> 
#> [INFO] Evaluating 4 parameter(s) for `list`
#> 
#> [INFO] ID = ID: Passing lMeta$ID.
#> 
#> [INFO] Analysis_Analyzed = Analysis_Analyzed: Passing lData$Analysis_Analyzed.
#> 
#> [INFO] Analysis_Flagged = Analysis_Flagged: Passing lData$Analysis_Flagged.
#> 
#> [INFO] Analysis_Summary = Analysis_Summary: Passing lData$Analysis_Summary.
#> 
#> [INFO] Calling `list`
#> 
#> [INFO] list of length 4 saved as `lData$lAnalysis`.
#> 
#> [INFO] Returning results from final step: list of length 4`.
#> 
#> [INFO] Completed `Analysis_ctas0002` Workflow
#> 
#> [INFO] Initializing `Analysis_ctas0003` Workflow
#> 
#> [INFO] Checking data against spec
#> 
#> [INFO] Workflow Step 1 of 7: `workr::RunQuery`
#> 
#> [INFO] Evaluating 2 parameter(s) for `workr::RunQuery`
#> 
#> [INFO] df = Mapped_SITE: Passing lData$Mapped_SITE.
#> 
#> [INFO] strQuery = SELECT DISTINCT GroupID FROM df: No matching data found. Passing 'SELECT DISTINCT GroupID FROM df' as a string.
#> 
#> [INFO] Calling `workr::RunQuery`
#> 
#> [INFO] Creating a new temporary DuckDB connection.
#> 
#> duckdb keeps downloaded extensions and secrets in a temporary directory:
#> ℹ /tmp/RtmpQqZ56W/duckdb
#> This is removed when the R session ends.
#> • Extensions are re-downloaded each session.
#> • Secrets are lost.
#> ℹ Run duckdb(shared_home = TRUE) (or create ~/.duckdb) to keep them (suitable for most users).
#> ℹ Run duckdb(shared_home = FALSE) to accept the temporary directory (and silence this message).
#> ℹ See ?duckdb_storage for details and alternatives.
#> [INFO] SQL Query complete: 6 rows returned.
#> 
#> [INFO] Disconnected from temporary DuckDB connection.
#> 
#> [INFO] 6x1 data.frame saved as `lData$Temp_GroupIDs`.
#> 
#> [INFO] Workflow Step 2 of 7: `dplyr::pull`
#> 
#> [INFO] Evaluating 2 parameter(s) for `dplyr::pull`
#> 
#> [INFO] .data = Temp_GroupIDs: Passing lData$Temp_GroupIDs.
#> 
#> [INFO] var = GroupID: No matching data found. Passing 'GroupID' as a string.
#> 
#> [INFO] Calling `dplyr::pull`
#> 
#> [INFO] character of length 6 saved as `lData$vGroupIDs`.
#> 
#> [INFO] Workflow Step 3 of 7: `gsm.core::ParseThreshold`
#> 
#> [INFO] Evaluating 1 parameter(s) for `gsm.core::ParseThreshold`
#> 
#> [INFO] strThreshold = Threshold: Passing lMeta$Threshold.
#> 
#> [INFO] Calling `gsm.core::ParseThreshold`
#> 
#> Parsed 0.842, 2.326 to numeric vector: 0.842, 2.326
#> [INFO] double of length 2 saved as `lData$vThreshold`.
#> 
#> [INFO] Workflow Step 4 of 7: `gsm.ctas::Summarize_CTAS`
#> 
#> [INFO] Evaluating 8 parameter(s) for `gsm.ctas::Summarize_CTAS`
#> 
#> [INFO] dfSiteScores = Mapped_CTAS_SiteScores: Passing lData$Mapped_CTAS_SiteScores.
#> 
#> [INFO] strFeature = Feature: Passing lMeta$Feature.
#> 
#> [INFO] strGroupLevel = GroupLevel: Passing lMeta$GroupLevel.
#> 
#> [INFO] strDomain = Domain: Passing lMeta$Domain.
#> 
#> [INFO] strTransformation = Transformation: Passing lMeta$Transformation.
#> 
#> [INFO] vGroupIDs = vGroupIDs: Passing lData$vGroupIDs.
#> 
#> [INFO] dHigh = TriggerHigh: Passing lMeta$TriggerHigh.
#> 
#> [INFO] dLow = TriggerLow: Passing lMeta$TriggerLow.
#> 
#> [INFO] Calling `gsm.ctas::Summarize_CTAS`
#> 
#> [INFO] 6x6 data.frame saved as `lData$Analysis_Analyzed`.
#> 
#> [INFO] Workflow Step 5 of 7: `gsm.ctas::Flag_CTAS`
#> 
#> [INFO] Evaluating 2 parameter(s) for `gsm.ctas::Flag_CTAS`
#> 
#> [INFO] dfAnalyzed = Analysis_Analyzed: Passing lData$Analysis_Analyzed.
#> 
#> [INFO] vThreshold = vThreshold: Passing lData$vThreshold.
#> 
#> [INFO] Calling `gsm.ctas::Flag_CTAS`
#> 
#> ℹ Sorted dfFlagged using custom Flag order: 2.Sorted dfFlagged using custom Flag order: 1.Sorted dfFlagged using custom Flag order: 0.
#> 
#> [INFO] 6x7 data.frame saved as `lData$Analysis_Flagged`.
#> 
#> [INFO] Workflow Step 6 of 7: `gsm.core::Summarize`
#> 
#> [INFO] Evaluating 1 parameter(s) for `gsm.core::Summarize`
#> 
#> [INFO] dfFlagged = Analysis_Flagged: Passing lData$Analysis_Flagged.
#> 
#> [INFO] Calling `gsm.core::Summarize`
#> 
#> [INFO] 6x7 data.frame saved as `lData$Analysis_Summary`.
#> 
#> [INFO] Workflow Step 7 of 7: `list`
#> 
#> [INFO] Evaluating 4 parameter(s) for `list`
#> 
#> [INFO] ID = ID: Passing lMeta$ID.
#> 
#> [INFO] Analysis_Analyzed = Analysis_Analyzed: Passing lData$Analysis_Analyzed.
#> 
#> [INFO] Analysis_Flagged = Analysis_Flagged: Passing lData$Analysis_Flagged.
#> 
#> [INFO] Analysis_Summary = Analysis_Summary: Passing lData$Analysis_Summary.
#> 
#> [INFO] Calling `list`
#> 
#> [INFO] list of length 4 saved as `lData$lAnalysis`.
#> 
#> [INFO] Returning results from final step: list of length 4`.
#> 
#> [INFO] Completed `Analysis_ctas0003` Workflow
#> 
#> [INFO] Initializing `Analysis_ctas0004` Workflow
#> 
#> [INFO] Checking data against spec
#> 
#> [INFO] Workflow Step 1 of 7: `workr::RunQuery`
#> 
#> [INFO] Evaluating 2 parameter(s) for `workr::RunQuery`
#> 
#> [INFO] df = Mapped_SITE: Passing lData$Mapped_SITE.
#> 
#> [INFO] strQuery = SELECT DISTINCT GroupID FROM df: No matching data found. Passing 'SELECT DISTINCT GroupID FROM df' as a string.
#> 
#> [INFO] Calling `workr::RunQuery`
#> 
#> [INFO] Creating a new temporary DuckDB connection.
#> 
#> duckdb keeps downloaded extensions and secrets in a temporary directory:
#> ℹ /tmp/RtmpQqZ56W/duckdb
#> This is removed when the R session ends.
#> • Extensions are re-downloaded each session.
#> • Secrets are lost.
#> ℹ Run duckdb(shared_home = TRUE) (or create ~/.duckdb) to keep them (suitable for most users).
#> ℹ Run duckdb(shared_home = FALSE) to accept the temporary directory (and silence this message).
#> ℹ See ?duckdb_storage for details and alternatives.
#> [INFO] SQL Query complete: 6 rows returned.
#> 
#> [INFO] Disconnected from temporary DuckDB connection.
#> 
#> [INFO] 6x1 data.frame saved as `lData$Temp_GroupIDs`.
#> 
#> [INFO] Workflow Step 2 of 7: `dplyr::pull`
#> 
#> [INFO] Evaluating 2 parameter(s) for `dplyr::pull`
#> 
#> [INFO] .data = Temp_GroupIDs: Passing lData$Temp_GroupIDs.
#> 
#> [INFO] var = GroupID: No matching data found. Passing 'GroupID' as a string.
#> 
#> [INFO] Calling `dplyr::pull`
#> 
#> [INFO] character of length 6 saved as `lData$vGroupIDs`.
#> 
#> [INFO] Workflow Step 3 of 7: `gsm.core::ParseThreshold`
#> 
#> [INFO] Evaluating 1 parameter(s) for `gsm.core::ParseThreshold`
#> 
#> [INFO] strThreshold = Threshold: Passing lMeta$Threshold.
#> 
#> [INFO] Calling `gsm.core::ParseThreshold`
#> 
#> Parsed 0.842, 2.326 to numeric vector: 0.842, 2.326
#> [INFO] double of length 2 saved as `lData$vThreshold`.
#> 
#> [INFO] Workflow Step 4 of 7: `gsm.ctas::Summarize_CTAS`
#> 
#> [INFO] Evaluating 8 parameter(s) for `gsm.ctas::Summarize_CTAS`
#> 
#> [INFO] dfSiteScores = Mapped_CTAS_SiteScores: Passing lData$Mapped_CTAS_SiteScores.
#> 
#> [INFO] strFeature = Feature: Passing lMeta$Feature.
#> 
#> [INFO] strGroupLevel = GroupLevel: Passing lMeta$GroupLevel.
#> 
#> [INFO] strDomain = Domain: Passing lMeta$Domain.
#> 
#> [INFO] strTransformation = Transformation: Passing lMeta$Transformation.
#> 
#> [INFO] vGroupIDs = vGroupIDs: Passing lData$vGroupIDs.
#> 
#> [INFO] dHigh = TriggerHigh: Passing lMeta$TriggerHigh.
#> 
#> [INFO] dLow = TriggerLow: Passing lMeta$TriggerLow.
#> 
#> [INFO] Calling `gsm.ctas::Summarize_CTAS`
#> 
#> [INFO] 6x6 data.frame saved as `lData$Analysis_Analyzed`.
#> 
#> [INFO] Workflow Step 5 of 7: `gsm.ctas::Flag_CTAS`
#> 
#> [INFO] Evaluating 2 parameter(s) for `gsm.ctas::Flag_CTAS`
#> 
#> [INFO] dfAnalyzed = Analysis_Analyzed: Passing lData$Analysis_Analyzed.
#> 
#> [INFO] vThreshold = vThreshold: Passing lData$vThreshold.
#> 
#> [INFO] Calling `gsm.ctas::Flag_CTAS`
#> 
#> ℹ Sorted dfFlagged using custom Flag order: 2.Sorted dfFlagged using custom Flag order: 1.Sorted dfFlagged using custom Flag order: 0.
#> 
#> [INFO] 6x7 data.frame saved as `lData$Analysis_Flagged`.
#> 
#> [INFO] Workflow Step 6 of 7: `gsm.core::Summarize`
#> 
#> [INFO] Evaluating 1 parameter(s) for `gsm.core::Summarize`
#> 
#> [INFO] dfFlagged = Analysis_Flagged: Passing lData$Analysis_Flagged.
#> 
#> [INFO] Calling `gsm.core::Summarize`
#> 
#> [INFO] 6x7 data.frame saved as `lData$Analysis_Summary`.
#> 
#> [INFO] Workflow Step 7 of 7: `list`
#> 
#> [INFO] Evaluating 4 parameter(s) for `list`
#> 
#> [INFO] ID = ID: Passing lMeta$ID.
#> 
#> [INFO] Analysis_Analyzed = Analysis_Analyzed: Passing lData$Analysis_Analyzed.
#> 
#> [INFO] Analysis_Flagged = Analysis_Flagged: Passing lData$Analysis_Flagged.
#> 
#> [INFO] Analysis_Summary = Analysis_Summary: Passing lData$Analysis_Summary.
#> 
#> [INFO] Calling `list`
#> 
#> [INFO] list of length 4 saved as `lData$lAnalysis`.
#> 
#> [INFO] Returning results from final step: list of length 4`.
#> 
#> [INFO] Completed `Analysis_ctas0004` Workflow
#> 
#> [INFO] Initializing `Analysis_ctas0005` Workflow
#> 
#> [INFO] Checking data against spec
#> 
#> [INFO] Workflow Step 1 of 7: `workr::RunQuery`
#> 
#> [INFO] Evaluating 2 parameter(s) for `workr::RunQuery`
#> 
#> [INFO] df = Mapped_SITE: Passing lData$Mapped_SITE.
#> 
#> [INFO] strQuery = SELECT DISTINCT GroupID FROM df: No matching data found. Passing 'SELECT DISTINCT GroupID FROM df' as a string.
#> 
#> [INFO] Calling `workr::RunQuery`
#> 
#> [INFO] Creating a new temporary DuckDB connection.
#> 
#> duckdb keeps downloaded extensions and secrets in a temporary directory:
#> ℹ /tmp/RtmpQqZ56W/duckdb
#> This is removed when the R session ends.
#> • Extensions are re-downloaded each session.
#> • Secrets are lost.
#> ℹ Run duckdb(shared_home = TRUE) (or create ~/.duckdb) to keep them (suitable for most users).
#> ℹ Run duckdb(shared_home = FALSE) to accept the temporary directory (and silence this message).
#> ℹ See ?duckdb_storage for details and alternatives.
#> [INFO] SQL Query complete: 6 rows returned.
#> 
#> [INFO] Disconnected from temporary DuckDB connection.
#> 
#> [INFO] 6x1 data.frame saved as `lData$Temp_GroupIDs`.
#> 
#> [INFO] Workflow Step 2 of 7: `dplyr::pull`
#> 
#> [INFO] Evaluating 2 parameter(s) for `dplyr::pull`
#> 
#> [INFO] .data = Temp_GroupIDs: Passing lData$Temp_GroupIDs.
#> 
#> [INFO] var = GroupID: No matching data found. Passing 'GroupID' as a string.
#> 
#> [INFO] Calling `dplyr::pull`
#> 
#> [INFO] character of length 6 saved as `lData$vGroupIDs`.
#> 
#> [INFO] Workflow Step 3 of 7: `gsm.core::ParseThreshold`
#> 
#> [INFO] Evaluating 1 parameter(s) for `gsm.core::ParseThreshold`
#> 
#> [INFO] strThreshold = Threshold: Passing lMeta$Threshold.
#> 
#> [INFO] Calling `gsm.core::ParseThreshold`
#> 
#> Parsed 0.842, 2.326 to numeric vector: 0.842, 2.326
#> [INFO] double of length 2 saved as `lData$vThreshold`.
#> 
#> [INFO] Workflow Step 4 of 7: `gsm.ctas::Summarize_CTAS`
#> 
#> [INFO] Evaluating 8 parameter(s) for `gsm.ctas::Summarize_CTAS`
#> 
#> [INFO] dfSiteScores = Mapped_CTAS_SiteScores: Passing lData$Mapped_CTAS_SiteScores.
#> 
#> [INFO] strFeature = Feature: Passing lMeta$Feature.
#> 
#> [INFO] strGroupLevel = GroupLevel: Passing lMeta$GroupLevel.
#> 
#> [INFO] strDomain = Domain: Passing lMeta$Domain.
#> 
#> [INFO] strTransformation = Transformation: Passing lMeta$Transformation.
#> 
#> [INFO] vGroupIDs = vGroupIDs: Passing lData$vGroupIDs.
#> 
#> [INFO] dHigh = TriggerHigh: Passing lMeta$TriggerHigh.
#> 
#> [INFO] dLow = TriggerLow: Passing lMeta$TriggerLow.
#> 
#> [INFO] Calling `gsm.ctas::Summarize_CTAS`
#> 
#> [INFO] 6x6 data.frame saved as `lData$Analysis_Analyzed`.
#> 
#> [INFO] Workflow Step 5 of 7: `gsm.ctas::Flag_CTAS`
#> 
#> [INFO] Evaluating 2 parameter(s) for `gsm.ctas::Flag_CTAS`
#> 
#> [INFO] dfAnalyzed = Analysis_Analyzed: Passing lData$Analysis_Analyzed.
#> 
#> [INFO] vThreshold = vThreshold: Passing lData$vThreshold.
#> 
#> [INFO] Calling `gsm.ctas::Flag_CTAS`
#> 
#> ℹ Sorted dfFlagged using custom Flag order: 2.Sorted dfFlagged using custom Flag order: 1.Sorted dfFlagged using custom Flag order: 0.
#> 
#> [INFO] 6x7 data.frame saved as `lData$Analysis_Flagged`.
#> 
#> [INFO] Workflow Step 6 of 7: `gsm.core::Summarize`
#> 
#> [INFO] Evaluating 1 parameter(s) for `gsm.core::Summarize`
#> 
#> [INFO] dfFlagged = Analysis_Flagged: Passing lData$Analysis_Flagged.
#> 
#> [INFO] Calling `gsm.core::Summarize`
#> 
#> [INFO] 6x7 data.frame saved as `lData$Analysis_Summary`.
#> 
#> [INFO] Workflow Step 7 of 7: `list`
#> 
#> [INFO] Evaluating 4 parameter(s) for `list`
#> 
#> [INFO] ID = ID: Passing lMeta$ID.
#> 
#> [INFO] Analysis_Analyzed = Analysis_Analyzed: Passing lData$Analysis_Analyzed.
#> 
#> [INFO] Analysis_Flagged = Analysis_Flagged: Passing lData$Analysis_Flagged.
#> 
#> [INFO] Analysis_Summary = Analysis_Summary: Passing lData$Analysis_Summary.
#> 
#> [INFO] Calling `list`
#> 
#> [INFO] list of length 4 saved as `lData$lAnalysis`.
#> 
#> [INFO] Returning results from final step: list of length 4`.
#> 
#> [INFO] Completed `Analysis_ctas0005` Workflow
#> 
#> [INFO] Initializing `Analysis_ctas0006` Workflow
#> 
#> [INFO] Checking data against spec
#> 
#> [INFO] Workflow Step 1 of 7: `workr::RunQuery`
#> 
#> [INFO] Evaluating 2 parameter(s) for `workr::RunQuery`
#> 
#> [INFO] df = Mapped_SITE: Passing lData$Mapped_SITE.
#> 
#> [INFO] strQuery = SELECT DISTINCT GroupID FROM df: No matching data found. Passing 'SELECT DISTINCT GroupID FROM df' as a string.
#> 
#> [INFO] Calling `workr::RunQuery`
#> 
#> [INFO] Creating a new temporary DuckDB connection.
#> 
#> duckdb keeps downloaded extensions and secrets in a temporary directory:
#> ℹ /tmp/RtmpQqZ56W/duckdb
#> This is removed when the R session ends.
#> • Extensions are re-downloaded each session.
#> • Secrets are lost.
#> ℹ Run duckdb(shared_home = TRUE) (or create ~/.duckdb) to keep them (suitable for most users).
#> ℹ Run duckdb(shared_home = FALSE) to accept the temporary directory (and silence this message).
#> ℹ See ?duckdb_storage for details and alternatives.
#> [INFO] SQL Query complete: 6 rows returned.
#> 
#> [INFO] Disconnected from temporary DuckDB connection.
#> 
#> [INFO] 6x1 data.frame saved as `lData$Temp_GroupIDs`.
#> 
#> [INFO] Workflow Step 2 of 7: `dplyr::pull`
#> 
#> [INFO] Evaluating 2 parameter(s) for `dplyr::pull`
#> 
#> [INFO] .data = Temp_GroupIDs: Passing lData$Temp_GroupIDs.
#> 
#> [INFO] var = GroupID: No matching data found. Passing 'GroupID' as a string.
#> 
#> [INFO] Calling `dplyr::pull`
#> 
#> [INFO] character of length 6 saved as `lData$vGroupIDs`.
#> 
#> [INFO] Workflow Step 3 of 7: `gsm.core::ParseThreshold`
#> 
#> [INFO] Evaluating 1 parameter(s) for `gsm.core::ParseThreshold`
#> 
#> [INFO] strThreshold = Threshold: Passing lMeta$Threshold.
#> 
#> [INFO] Calling `gsm.core::ParseThreshold`
#> 
#> Parsed 0.842, 2.326 to numeric vector: 0.842, 2.326
#> [INFO] double of length 2 saved as `lData$vThreshold`.
#> 
#> [INFO] Workflow Step 4 of 7: `gsm.ctas::Summarize_CTAS`
#> 
#> [INFO] Evaluating 8 parameter(s) for `gsm.ctas::Summarize_CTAS`
#> 
#> [INFO] dfSiteScores = Mapped_CTAS_SiteScores: Passing lData$Mapped_CTAS_SiteScores.
#> 
#> [INFO] strFeature = Feature: Passing lMeta$Feature.
#> 
#> [INFO] strGroupLevel = GroupLevel: Passing lMeta$GroupLevel.
#> 
#> [INFO] strDomain = Domain: Passing lMeta$Domain.
#> 
#> [INFO] strTransformation = Transformation: Passing lMeta$Transformation.
#> 
#> [INFO] vGroupIDs = vGroupIDs: Passing lData$vGroupIDs.
#> 
#> [INFO] dHigh = TriggerHigh: Passing lMeta$TriggerHigh.
#> 
#> [INFO] dLow = TriggerLow: Passing lMeta$TriggerLow.
#> 
#> [INFO] Calling `gsm.ctas::Summarize_CTAS`
#> 
#> [INFO] 6x6 data.frame saved as `lData$Analysis_Analyzed`.
#> 
#> [INFO] Workflow Step 5 of 7: `gsm.ctas::Flag_CTAS`
#> 
#> [INFO] Evaluating 2 parameter(s) for `gsm.ctas::Flag_CTAS`
#> 
#> [INFO] dfAnalyzed = Analysis_Analyzed: Passing lData$Analysis_Analyzed.
#> 
#> [INFO] vThreshold = vThreshold: Passing lData$vThreshold.
#> 
#> [INFO] Calling `gsm.ctas::Flag_CTAS`
#> 
#> ℹ Sorted dfFlagged using custom Flag order: 2.Sorted dfFlagged using custom Flag order: 1.Sorted dfFlagged using custom Flag order: 0.
#> 
#> [INFO] 6x7 data.frame saved as `lData$Analysis_Flagged`.
#> 
#> [INFO] Workflow Step 6 of 7: `gsm.core::Summarize`
#> 
#> [INFO] Evaluating 1 parameter(s) for `gsm.core::Summarize`
#> 
#> [INFO] dfFlagged = Analysis_Flagged: Passing lData$Analysis_Flagged.
#> 
#> [INFO] Calling `gsm.core::Summarize`
#> 
#> [INFO] 6x7 data.frame saved as `lData$Analysis_Summary`.
#> 
#> [INFO] Workflow Step 7 of 7: `list`
#> 
#> [INFO] Evaluating 4 parameter(s) for `list`
#> 
#> [INFO] ID = ID: Passing lMeta$ID.
#> 
#> [INFO] Analysis_Analyzed = Analysis_Analyzed: Passing lData$Analysis_Analyzed.
#> 
#> [INFO] Analysis_Flagged = Analysis_Flagged: Passing lData$Analysis_Flagged.
#> 
#> [INFO] Analysis_Summary = Analysis_Summary: Passing lData$Analysis_Summary.
#> 
#> [INFO] Calling `list`
#> 
#> [INFO] list of length 4 saved as `lData$lAnalysis`.
#> 
#> [INFO] Returning results from final step: list of length 4`.
#> 
#> [INFO] Completed `Analysis_ctas0006` Workflow
#> 
#> [INFO] Initializing `Analysis_ctas0007` Workflow
#> 
#> [INFO] Checking data against spec
#> 
#> [INFO] Workflow Step 1 of 7: `workr::RunQuery`
#> 
#> [INFO] Evaluating 2 parameter(s) for `workr::RunQuery`
#> 
#> [INFO] df = Mapped_SITE: Passing lData$Mapped_SITE.
#> 
#> [INFO] strQuery = SELECT DISTINCT GroupID FROM df: No matching data found. Passing 'SELECT DISTINCT GroupID FROM df' as a string.
#> 
#> [INFO] Calling `workr::RunQuery`
#> 
#> [INFO] Creating a new temporary DuckDB connection.
#> 
#> duckdb keeps downloaded extensions and secrets in a temporary directory:
#> ℹ /tmp/RtmpQqZ56W/duckdb
#> This is removed when the R session ends.
#> • Extensions are re-downloaded each session.
#> • Secrets are lost.
#> ℹ Run duckdb(shared_home = TRUE) (or create ~/.duckdb) to keep them (suitable for most users).
#> ℹ Run duckdb(shared_home = FALSE) to accept the temporary directory (and silence this message).
#> ℹ See ?duckdb_storage for details and alternatives.
#> [INFO] SQL Query complete: 6 rows returned.
#> 
#> [INFO] Disconnected from temporary DuckDB connection.
#> 
#> [INFO] 6x1 data.frame saved as `lData$Temp_GroupIDs`.
#> 
#> [INFO] Workflow Step 2 of 7: `dplyr::pull`
#> 
#> [INFO] Evaluating 2 parameter(s) for `dplyr::pull`
#> 
#> [INFO] .data = Temp_GroupIDs: Passing lData$Temp_GroupIDs.
#> 
#> [INFO] var = GroupID: No matching data found. Passing 'GroupID' as a string.
#> 
#> [INFO] Calling `dplyr::pull`
#> 
#> [INFO] character of length 6 saved as `lData$vGroupIDs`.
#> 
#> [INFO] Workflow Step 3 of 7: `gsm.core::ParseThreshold`
#> 
#> [INFO] Evaluating 1 parameter(s) for `gsm.core::ParseThreshold`
#> 
#> [INFO] strThreshold = Threshold: Passing lMeta$Threshold.
#> 
#> [INFO] Calling `gsm.core::ParseThreshold`
#> 
#> Parsed 0.842, 2.326 to numeric vector: 0.842, 2.326
#> [INFO] double of length 2 saved as `lData$vThreshold`.
#> 
#> [INFO] Workflow Step 4 of 7: `gsm.ctas::Summarize_CTAS`
#> 
#> [INFO] Evaluating 8 parameter(s) for `gsm.ctas::Summarize_CTAS`
#> 
#> [INFO] dfSiteScores = Mapped_CTAS_SiteScores: Passing lData$Mapped_CTAS_SiteScores.
#> 
#> [INFO] strFeature = Feature: Passing lMeta$Feature.
#> 
#> [INFO] strGroupLevel = GroupLevel: Passing lMeta$GroupLevel.
#> 
#> [INFO] strDomain = Domain: Passing lMeta$Domain.
#> 
#> [INFO] strTransformation = Transformation: Passing lMeta$Transformation.
#> 
#> [INFO] vGroupIDs = vGroupIDs: Passing lData$vGroupIDs.
#> 
#> [INFO] dHigh = TriggerHigh: Passing lMeta$TriggerHigh.
#> 
#> [INFO] dLow = TriggerLow: Passing lMeta$TriggerLow.
#> 
#> [INFO] Calling `gsm.ctas::Summarize_CTAS`
#> 
#> [INFO] 6x6 data.frame saved as `lData$Analysis_Analyzed`.
#> 
#> [INFO] Workflow Step 5 of 7: `gsm.ctas::Flag_CTAS`
#> 
#> [INFO] Evaluating 2 parameter(s) for `gsm.ctas::Flag_CTAS`
#> 
#> [INFO] dfAnalyzed = Analysis_Analyzed: Passing lData$Analysis_Analyzed.
#> 
#> [INFO] vThreshold = vThreshold: Passing lData$vThreshold.
#> 
#> [INFO] Calling `gsm.ctas::Flag_CTAS`
#> 
#> ℹ Sorted dfFlagged using custom Flag order: 2.Sorted dfFlagged using custom Flag order: 1.Sorted dfFlagged using custom Flag order: 0.
#> 
#> [INFO] 6x7 data.frame saved as `lData$Analysis_Flagged`.
#> 
#> [INFO] Workflow Step 6 of 7: `gsm.core::Summarize`
#> 
#> [INFO] Evaluating 1 parameter(s) for `gsm.core::Summarize`
#> 
#> [INFO] dfFlagged = Analysis_Flagged: Passing lData$Analysis_Flagged.
#> 
#> [INFO] Calling `gsm.core::Summarize`
#> 
#> [INFO] 6x7 data.frame saved as `lData$Analysis_Summary`.
#> 
#> [INFO] Workflow Step 7 of 7: `list`
#> 
#> [INFO] Evaluating 4 parameter(s) for `list`
#> 
#> [INFO] ID = ID: Passing lMeta$ID.
#> 
#> [INFO] Analysis_Analyzed = Analysis_Analyzed: Passing lData$Analysis_Analyzed.
#> 
#> [INFO] Analysis_Flagged = Analysis_Flagged: Passing lData$Analysis_Flagged.
#> 
#> [INFO] Analysis_Summary = Analysis_Summary: Passing lData$Analysis_Summary.
#> 
#> [INFO] Calling `list`
#> 
#> [INFO] list of length 4 saved as `lData$lAnalysis`.
#> 
#> [INFO] Returning results from final step: list of length 4`.
#> 
#> [INFO] Completed `Analysis_ctas0007` Workflow
#> 
#> [INFO] Initializing `Analysis_ctas0008` Workflow
#> 
#> [INFO] Checking data against spec
#> 
#> [INFO] Workflow Step 1 of 7: `workr::RunQuery`
#> 
#> [INFO] Evaluating 2 parameter(s) for `workr::RunQuery`
#> 
#> [INFO] df = Mapped_SITE: Passing lData$Mapped_SITE.
#> 
#> [INFO] strQuery = SELECT DISTINCT GroupID FROM df: No matching data found. Passing 'SELECT DISTINCT GroupID FROM df' as a string.
#> 
#> [INFO] Calling `workr::RunQuery`
#> 
#> [INFO] Creating a new temporary DuckDB connection.
#> 
#> duckdb keeps downloaded extensions and secrets in a temporary directory:
#> ℹ /tmp/RtmpQqZ56W/duckdb
#> This is removed when the R session ends.
#> • Extensions are re-downloaded each session.
#> • Secrets are lost.
#> ℹ Run duckdb(shared_home = TRUE) (or create ~/.duckdb) to keep them (suitable for most users).
#> ℹ Run duckdb(shared_home = FALSE) to accept the temporary directory (and silence this message).
#> ℹ See ?duckdb_storage for details and alternatives.
#> [INFO] SQL Query complete: 6 rows returned.
#> 
#> [INFO] Disconnected from temporary DuckDB connection.
#> 
#> [INFO] 6x1 data.frame saved as `lData$Temp_GroupIDs`.
#> 
#> [INFO] Workflow Step 2 of 7: `dplyr::pull`
#> 
#> [INFO] Evaluating 2 parameter(s) for `dplyr::pull`
#> 
#> [INFO] .data = Temp_GroupIDs: Passing lData$Temp_GroupIDs.
#> 
#> [INFO] var = GroupID: No matching data found. Passing 'GroupID' as a string.
#> 
#> [INFO] Calling `dplyr::pull`
#> 
#> [INFO] character of length 6 saved as `lData$vGroupIDs`.
#> 
#> [INFO] Workflow Step 3 of 7: `gsm.core::ParseThreshold`
#> 
#> [INFO] Evaluating 1 parameter(s) for `gsm.core::ParseThreshold`
#> 
#> [INFO] strThreshold = Threshold: Passing lMeta$Threshold.
#> 
#> [INFO] Calling `gsm.core::ParseThreshold`
#> 
#> Parsed 0.842, 2.326 to numeric vector: 0.842, 2.326
#> [INFO] double of length 2 saved as `lData$vThreshold`.
#> 
#> [INFO] Workflow Step 4 of 7: `gsm.ctas::Summarize_CTAS`
#> 
#> [INFO] Evaluating 8 parameter(s) for `gsm.ctas::Summarize_CTAS`
#> 
#> [INFO] dfSiteScores = Mapped_CTAS_SiteScores: Passing lData$Mapped_CTAS_SiteScores.
#> 
#> [INFO] strFeature = Feature: Passing lMeta$Feature.
#> 
#> [INFO] strGroupLevel = GroupLevel: Passing lMeta$GroupLevel.
#> 
#> [INFO] strDomain = Domain: Passing lMeta$Domain.
#> 
#> [INFO] strTransformation = Transformation: Passing lMeta$Transformation.
#> 
#> [INFO] vGroupIDs = vGroupIDs: Passing lData$vGroupIDs.
#> 
#> [INFO] dHigh = TriggerHigh: Passing lMeta$TriggerHigh.
#> 
#> [INFO] dLow = TriggerLow: Passing lMeta$TriggerLow.
#> 
#> [INFO] Calling `gsm.ctas::Summarize_CTAS`
#> 
#> [INFO] 6x6 data.frame saved as `lData$Analysis_Analyzed`.
#> 
#> [INFO] Workflow Step 5 of 7: `gsm.ctas::Flag_CTAS`
#> 
#> [INFO] Evaluating 2 parameter(s) for `gsm.ctas::Flag_CTAS`
#> 
#> [INFO] dfAnalyzed = Analysis_Analyzed: Passing lData$Analysis_Analyzed.
#> 
#> [INFO] vThreshold = vThreshold: Passing lData$vThreshold.
#> 
#> [INFO] Calling `gsm.ctas::Flag_CTAS`
#> 
#> ℹ Sorted dfFlagged using custom Flag order: 2.Sorted dfFlagged using custom Flag order: 1.Sorted dfFlagged using custom Flag order: 0.
#> 
#> [INFO] 6x7 data.frame saved as `lData$Analysis_Flagged`.
#> 
#> [INFO] Workflow Step 6 of 7: `gsm.core::Summarize`
#> 
#> [INFO] Evaluating 1 parameter(s) for `gsm.core::Summarize`
#> 
#> [INFO] dfFlagged = Analysis_Flagged: Passing lData$Analysis_Flagged.
#> 
#> [INFO] Calling `gsm.core::Summarize`
#> 
#> [INFO] 6x7 data.frame saved as `lData$Analysis_Summary`.
#> 
#> [INFO] Workflow Step 7 of 7: `list`
#> 
#> [INFO] Evaluating 4 parameter(s) for `list`
#> 
#> [INFO] ID = ID: Passing lMeta$ID.
#> 
#> [INFO] Analysis_Analyzed = Analysis_Analyzed: Passing lData$Analysis_Analyzed.
#> 
#> [INFO] Analysis_Flagged = Analysis_Flagged: Passing lData$Analysis_Flagged.
#> 
#> [INFO] Analysis_Summary = Analysis_Summary: Passing lData$Analysis_Summary.
#> 
#> [INFO] Calling `list`
#> 
#> [INFO] list of length 4 saved as `lData$lAnalysis`.
#> 
#> [INFO] Returning results from final step: list of length 4`.
#> 
#> [INFO] Completed `Analysis_ctas0008` Workflow
#> 
#> [INFO] Initializing `Analysis_ctas0009` Workflow
#> 
#> [INFO] Checking data against spec
#> 
#> [INFO] Workflow Step 1 of 7: `workr::RunQuery`
#> 
#> [INFO] Evaluating 2 parameter(s) for `workr::RunQuery`
#> 
#> [INFO] df = Mapped_SITE: Passing lData$Mapped_SITE.
#> 
#> [INFO] strQuery = SELECT DISTINCT GroupID FROM df: No matching data found. Passing 'SELECT DISTINCT GroupID FROM df' as a string.
#> 
#> [INFO] Calling `workr::RunQuery`
#> 
#> [INFO] Creating a new temporary DuckDB connection.
#> 
#> duckdb keeps downloaded extensions and secrets in a temporary directory:
#> ℹ /tmp/RtmpQqZ56W/duckdb
#> This is removed when the R session ends.
#> • Extensions are re-downloaded each session.
#> • Secrets are lost.
#> ℹ Run duckdb(shared_home = TRUE) (or create ~/.duckdb) to keep them (suitable for most users).
#> ℹ Run duckdb(shared_home = FALSE) to accept the temporary directory (and silence this message).
#> ℹ See ?duckdb_storage for details and alternatives.
#> [INFO] SQL Query complete: 6 rows returned.
#> 
#> [INFO] Disconnected from temporary DuckDB connection.
#> 
#> [INFO] 6x1 data.frame saved as `lData$Temp_GroupIDs`.
#> 
#> [INFO] Workflow Step 2 of 7: `dplyr::pull`
#> 
#> [INFO] Evaluating 2 parameter(s) for `dplyr::pull`
#> 
#> [INFO] .data = Temp_GroupIDs: Passing lData$Temp_GroupIDs.
#> 
#> [INFO] var = GroupID: No matching data found. Passing 'GroupID' as a string.
#> 
#> [INFO] Calling `dplyr::pull`
#> 
#> [INFO] character of length 6 saved as `lData$vGroupIDs`.
#> 
#> [INFO] Workflow Step 3 of 7: `gsm.core::ParseThreshold`
#> 
#> [INFO] Evaluating 1 parameter(s) for `gsm.core::ParseThreshold`
#> 
#> [INFO] strThreshold = Threshold: Passing lMeta$Threshold.
#> 
#> [INFO] Calling `gsm.core::ParseThreshold`
#> 
#> Parsed 0.842, 2.326 to numeric vector: 0.842, 2.326
#> [INFO] double of length 2 saved as `lData$vThreshold`.
#> 
#> [INFO] Workflow Step 4 of 7: `gsm.ctas::Summarize_CTAS`
#> 
#> [INFO] Evaluating 8 parameter(s) for `gsm.ctas::Summarize_CTAS`
#> 
#> [INFO] dfSiteScores = Mapped_CTAS_SiteScores: Passing lData$Mapped_CTAS_SiteScores.
#> 
#> [INFO] strFeature = Feature: Passing lMeta$Feature.
#> 
#> [INFO] strGroupLevel = GroupLevel: Passing lMeta$GroupLevel.
#> 
#> [INFO] strDomain = Domain: Passing lMeta$Domain.
#> 
#> [INFO] strTransformation = Transformation: Passing lMeta$Transformation.
#> 
#> [INFO] vGroupIDs = vGroupIDs: Passing lData$vGroupIDs.
#> 
#> [INFO] dHigh = TriggerHigh: Passing lMeta$TriggerHigh.
#> 
#> [INFO] dLow = TriggerLow: Passing lMeta$TriggerLow.
#> 
#> [INFO] Calling `gsm.ctas::Summarize_CTAS`
#> 
#> [INFO] 6x6 data.frame saved as `lData$Analysis_Analyzed`.
#> 
#> [INFO] Workflow Step 5 of 7: `gsm.ctas::Flag_CTAS`
#> 
#> [INFO] Evaluating 2 parameter(s) for `gsm.ctas::Flag_CTAS`
#> 
#> [INFO] dfAnalyzed = Analysis_Analyzed: Passing lData$Analysis_Analyzed.
#> 
#> [INFO] vThreshold = vThreshold: Passing lData$vThreshold.
#> 
#> [INFO] Calling `gsm.ctas::Flag_CTAS`
#> 
#> ℹ Sorted dfFlagged using custom Flag order: 2.Sorted dfFlagged using custom Flag order: 1.Sorted dfFlagged using custom Flag order: 0.
#> 
#> [INFO] 6x7 data.frame saved as `lData$Analysis_Flagged`.
#> 
#> [INFO] Workflow Step 6 of 7: `gsm.core::Summarize`
#> 
#> [INFO] Evaluating 1 parameter(s) for `gsm.core::Summarize`
#> 
#> [INFO] dfFlagged = Analysis_Flagged: Passing lData$Analysis_Flagged.
#> 
#> [INFO] Calling `gsm.core::Summarize`
#> 
#> [INFO] 6x7 data.frame saved as `lData$Analysis_Summary`.
#> 
#> [INFO] Workflow Step 7 of 7: `list`
#> 
#> [INFO] Evaluating 4 parameter(s) for `list`
#> 
#> [INFO] ID = ID: Passing lMeta$ID.
#> 
#> [INFO] Analysis_Analyzed = Analysis_Analyzed: Passing lData$Analysis_Analyzed.
#> 
#> [INFO] Analysis_Flagged = Analysis_Flagged: Passing lData$Analysis_Flagged.
#> 
#> [INFO] Analysis_Summary = Analysis_Summary: Passing lData$Analysis_Summary.
#> 
#> [INFO] Calling `list`
#> 
#> [INFO] list of length 4 saved as `lData$lAnalysis`.
#> 
#> [INFO] Returning results from final step: list of length 4`.
#> 
#> [INFO] Completed `Analysis_ctas0009` Workflow
#> 
#> [INFO] Initializing `Analysis_ctas0010` Workflow
#> 
#> [INFO] Checking data against spec
#> 
#> [INFO] Workflow Step 1 of 7: `workr::RunQuery`
#> 
#> [INFO] Evaluating 2 parameter(s) for `workr::RunQuery`
#> 
#> [INFO] df = Mapped_SITE: Passing lData$Mapped_SITE.
#> 
#> [INFO] strQuery = SELECT DISTINCT GroupID FROM df: No matching data found. Passing 'SELECT DISTINCT GroupID FROM df' as a string.
#> 
#> [INFO] Calling `workr::RunQuery`
#> 
#> [INFO] Creating a new temporary DuckDB connection.
#> 
#> duckdb keeps downloaded extensions and secrets in a temporary directory:
#> ℹ /tmp/RtmpQqZ56W/duckdb
#> This is removed when the R session ends.
#> • Extensions are re-downloaded each session.
#> • Secrets are lost.
#> ℹ Run duckdb(shared_home = TRUE) (or create ~/.duckdb) to keep them (suitable for most users).
#> ℹ Run duckdb(shared_home = FALSE) to accept the temporary directory (and silence this message).
#> ℹ See ?duckdb_storage for details and alternatives.
#> [INFO] SQL Query complete: 6 rows returned.
#> 
#> [INFO] Disconnected from temporary DuckDB connection.
#> 
#> [INFO] 6x1 data.frame saved as `lData$Temp_GroupIDs`.
#> 
#> [INFO] Workflow Step 2 of 7: `dplyr::pull`
#> 
#> [INFO] Evaluating 2 parameter(s) for `dplyr::pull`
#> 
#> [INFO] .data = Temp_GroupIDs: Passing lData$Temp_GroupIDs.
#> 
#> [INFO] var = GroupID: No matching data found. Passing 'GroupID' as a string.
#> 
#> [INFO] Calling `dplyr::pull`
#> 
#> [INFO] character of length 6 saved as `lData$vGroupIDs`.
#> 
#> [INFO] Workflow Step 3 of 7: `gsm.core::ParseThreshold`
#> 
#> [INFO] Evaluating 1 parameter(s) for `gsm.core::ParseThreshold`
#> 
#> [INFO] strThreshold = Threshold: Passing lMeta$Threshold.
#> 
#> [INFO] Calling `gsm.core::ParseThreshold`
#> 
#> Parsed 0.842, 2.326 to numeric vector: 0.842, 2.326
#> [INFO] double of length 2 saved as `lData$vThreshold`.
#> 
#> [INFO] Workflow Step 4 of 7: `gsm.ctas::Summarize_CTAS`
#> 
#> [INFO] Evaluating 8 parameter(s) for `gsm.ctas::Summarize_CTAS`
#> 
#> [INFO] dfSiteScores = Mapped_CTAS_SiteScores: Passing lData$Mapped_CTAS_SiteScores.
#> 
#> [INFO] strFeature = Feature: Passing lMeta$Feature.
#> 
#> [INFO] strGroupLevel = GroupLevel: Passing lMeta$GroupLevel.
#> 
#> [INFO] strDomain = Domain: Passing lMeta$Domain.
#> 
#> [INFO] strTransformation = Transformation: Passing lMeta$Transformation.
#> 
#> [INFO] vGroupIDs = vGroupIDs: Passing lData$vGroupIDs.
#> 
#> [INFO] dHigh = TriggerHigh: Passing lMeta$TriggerHigh.
#> 
#> [INFO] dLow = TriggerLow: Passing lMeta$TriggerLow.
#> 
#> [INFO] Calling `gsm.ctas::Summarize_CTAS`
#> 
#> [INFO] 6x6 data.frame saved as `lData$Analysis_Analyzed`.
#> 
#> [INFO] Workflow Step 5 of 7: `gsm.ctas::Flag_CTAS`
#> 
#> [INFO] Evaluating 2 parameter(s) for `gsm.ctas::Flag_CTAS`
#> 
#> [INFO] dfAnalyzed = Analysis_Analyzed: Passing lData$Analysis_Analyzed.
#> 
#> [INFO] vThreshold = vThreshold: Passing lData$vThreshold.
#> 
#> [INFO] Calling `gsm.ctas::Flag_CTAS`
#> 
#> ℹ Sorted dfFlagged using custom Flag order: 2.Sorted dfFlagged using custom Flag order: 1.Sorted dfFlagged using custom Flag order: 0.
#> 
#> [INFO] 6x7 data.frame saved as `lData$Analysis_Flagged`.
#> 
#> [INFO] Workflow Step 6 of 7: `gsm.core::Summarize`
#> 
#> [INFO] Evaluating 1 parameter(s) for `gsm.core::Summarize`
#> 
#> [INFO] dfFlagged = Analysis_Flagged: Passing lData$Analysis_Flagged.
#> 
#> [INFO] Calling `gsm.core::Summarize`
#> 
#> [INFO] 6x7 data.frame saved as `lData$Analysis_Summary`.
#> 
#> [INFO] Workflow Step 7 of 7: `list`
#> 
#> [INFO] Evaluating 4 parameter(s) for `list`
#> 
#> [INFO] ID = ID: Passing lMeta$ID.
#> 
#> [INFO] Analysis_Analyzed = Analysis_Analyzed: Passing lData$Analysis_Analyzed.
#> 
#> [INFO] Analysis_Flagged = Analysis_Flagged: Passing lData$Analysis_Flagged.
#> 
#> [INFO] Analysis_Summary = Analysis_Summary: Passing lData$Analysis_Summary.
#> 
#> [INFO] Calling `list`
#> 
#> [INFO] list of length 4 saved as `lData$lAnalysis`.
#> 
#> [INFO] Returning results from final step: list of length 4`.
#> 
#> [INFO] Completed `Analysis_ctas0010` Workflow
#> 
#> [INFO] Initializing `Analysis_ctas0011` Workflow
#> 
#> [INFO] Checking data against spec
#> 
#> [INFO] Workflow Step 1 of 7: `workr::RunQuery`
#> 
#> [INFO] Evaluating 2 parameter(s) for `workr::RunQuery`
#> 
#> [INFO] df = Mapped_SITE: Passing lData$Mapped_SITE.
#> 
#> [INFO] strQuery = SELECT DISTINCT GroupID FROM df: No matching data found. Passing 'SELECT DISTINCT GroupID FROM df' as a string.
#> 
#> [INFO] Calling `workr::RunQuery`
#> 
#> [INFO] Creating a new temporary DuckDB connection.
#> 
#> duckdb keeps downloaded extensions and secrets in a temporary directory:
#> ℹ /tmp/RtmpQqZ56W/duckdb
#> This is removed when the R session ends.
#> • Extensions are re-downloaded each session.
#> • Secrets are lost.
#> ℹ Run duckdb(shared_home = TRUE) (or create ~/.duckdb) to keep them (suitable for most users).
#> ℹ Run duckdb(shared_home = FALSE) to accept the temporary directory (and silence this message).
#> ℹ See ?duckdb_storage for details and alternatives.
#> [INFO] SQL Query complete: 6 rows returned.
#> 
#> [INFO] Disconnected from temporary DuckDB connection.
#> 
#> [INFO] 6x1 data.frame saved as `lData$Temp_GroupIDs`.
#> 
#> [INFO] Workflow Step 2 of 7: `dplyr::pull`
#> 
#> [INFO] Evaluating 2 parameter(s) for `dplyr::pull`
#> 
#> [INFO] .data = Temp_GroupIDs: Passing lData$Temp_GroupIDs.
#> 
#> [INFO] var = GroupID: No matching data found. Passing 'GroupID' as a string.
#> 
#> [INFO] Calling `dplyr::pull`
#> 
#> [INFO] character of length 6 saved as `lData$vGroupIDs`.
#> 
#> [INFO] Workflow Step 3 of 7: `gsm.core::ParseThreshold`
#> 
#> [INFO] Evaluating 1 parameter(s) for `gsm.core::ParseThreshold`
#> 
#> [INFO] strThreshold = Threshold: Passing lMeta$Threshold.
#> 
#> [INFO] Calling `gsm.core::ParseThreshold`
#> 
#> Parsed 0.842, 2.326 to numeric vector: 0.842, 2.326
#> [INFO] double of length 2 saved as `lData$vThreshold`.
#> 
#> [INFO] Workflow Step 4 of 7: `gsm.ctas::Summarize_CTAS`
#> 
#> [INFO] Evaluating 8 parameter(s) for `gsm.ctas::Summarize_CTAS`
#> 
#> [INFO] dfSiteScores = Mapped_CTAS_SiteScores: Passing lData$Mapped_CTAS_SiteScores.
#> 
#> [INFO] strFeature = Feature: Passing lMeta$Feature.
#> 
#> [INFO] strGroupLevel = GroupLevel: Passing lMeta$GroupLevel.
#> 
#> [INFO] strDomain = Domain: Passing lMeta$Domain.
#> 
#> [INFO] strTransformation = Transformation: Passing lMeta$Transformation.
#> 
#> [INFO] vGroupIDs = vGroupIDs: Passing lData$vGroupIDs.
#> 
#> [INFO] dHigh = TriggerHigh: Passing lMeta$TriggerHigh.
#> 
#> [INFO] dLow = TriggerLow: Passing lMeta$TriggerLow.
#> 
#> [INFO] Calling `gsm.ctas::Summarize_CTAS`
#> 
#> [INFO] 6x6 data.frame saved as `lData$Analysis_Analyzed`.
#> 
#> [INFO] Workflow Step 5 of 7: `gsm.ctas::Flag_CTAS`
#> 
#> [INFO] Evaluating 2 parameter(s) for `gsm.ctas::Flag_CTAS`
#> 
#> [INFO] dfAnalyzed = Analysis_Analyzed: Passing lData$Analysis_Analyzed.
#> 
#> [INFO] vThreshold = vThreshold: Passing lData$vThreshold.
#> 
#> [INFO] Calling `gsm.ctas::Flag_CTAS`
#> 
#> ℹ Sorted dfFlagged using custom Flag order: 2.Sorted dfFlagged using custom Flag order: 1.Sorted dfFlagged using custom Flag order: 0.
#> 
#> [INFO] 6x7 data.frame saved as `lData$Analysis_Flagged`.
#> 
#> [INFO] Workflow Step 6 of 7: `gsm.core::Summarize`
#> 
#> [INFO] Evaluating 1 parameter(s) for `gsm.core::Summarize`
#> 
#> [INFO] dfFlagged = Analysis_Flagged: Passing lData$Analysis_Flagged.
#> 
#> [INFO] Calling `gsm.core::Summarize`
#> 
#> [INFO] 6x7 data.frame saved as `lData$Analysis_Summary`.
#> 
#> [INFO] Workflow Step 7 of 7: `list`
#> 
#> [INFO] Evaluating 4 parameter(s) for `list`
#> 
#> [INFO] ID = ID: Passing lMeta$ID.
#> 
#> [INFO] Analysis_Analyzed = Analysis_Analyzed: Passing lData$Analysis_Analyzed.
#> 
#> [INFO] Analysis_Flagged = Analysis_Flagged: Passing lData$Analysis_Flagged.
#> 
#> [INFO] Analysis_Summary = Analysis_Summary: Passing lData$Analysis_Summary.
#> 
#> [INFO] Calling `list`
#> 
#> [INFO] list of length 4 saved as `lData$lAnalysis`.
#> 
#> [INFO] Returning results from final step: list of length 4`.
#> 
#> [INFO] Completed `Analysis_ctas0011` Workflow

utils::head(lAnalysis$Analysis_ctas0001$Analysis_Flagged)
#> # A tibble: 6 × 7
#>   GroupID GroupLevel Numerator Denominator Metric  Score  Flag
#>   <chr>   <chr>          <dbl>       <dbl>  <dbl>  <dbl> <dbl>
#> 1 701     Site               1           3  0.333 4.19       2
#> 2 705     Site               2           3  0.667 2.68       2
#> 3 703     Site               0           3  0     1.23       1
#> 4 702     Site               0           3  0     0.0768     0
#> 5 704     Site               0           3  0     0.690      0
#> 6 706     Site               0           3  0     0.0988     0
```

The aggregation is:

| gsm field     | CTAS source                                       |
|---------------|---------------------------------------------------|
| `GroupID`     | `site_scores$site`                                |
| `Numerator`   | timeseries with `trigger == "Further Evaluation"` |
| `Denominator` | timeseries evaluated for that group x feature     |
| `Metric`      | `Numerator / Denominator`                         |
| `Score`       | `max(fdr_corrected_pvalue_logp)`                  |

Flagging is **one-sided** (`0`/`1`/`2`): $`-\log_{10}p`$ is unsigned, so
it says that a site differs, not in which direction.

`Denominator` counts *timeseries*, not participants and not tests – CTAS
autogenerates a timeseries per timepoint combination, so the lab
families contribute more of them than vital signs do.

## 3-4. Reporting and the KRI report

``` r

lReportingWorkflows <- workr::MakeWorkflowList(
  strNames = NULL,
  strPath = system.file("workflow/3_reporting", package = "gsm.ctas"),
  strPackage = NULL
)

lReporting <- gsm.core::RunWorkflows(
  lWorkflows = lReportingWorkflows,
  lData = c(
    lMapped,
    list(lAnalyzed = lAnalysis, lWorkflows = lMetricWorkflows)
  )
)
#> [INFO] Running 4 Workflows
#> [INFO] Initializing `Reporting_Groups` Workflow
#> [INFO] Checking data against spec
#> [INFO] Workflow Step 1 of 1: `dplyr::bind_rows`
#> [INFO] Evaluating 2 parameter(s) for `dplyr::bind_rows`
#> [INFO] Study = Mapped_STUDY: Passing lData$Mapped_STUDY.
#> [INFO] Site = Mapped_SITE: Passing lData$Mapped_SITE.
#> [INFO] Calling `dplyr::bind_rows`
#> [INFO] 26x4 data.frame saved as `lData$Reporting_Groups`.
#> [INFO] Returning results from final step: 26x4 data.frame`.
#> [INFO] Completed `Reporting_Groups` Workflow
#> [INFO] Initializing `Reporting_Metrics` Workflow
#> [INFO] No spec found in workflow. Proceeding without checking data.
#> [INFO] Workflow Step 1 of 1: `gsm.reporting::MakeMetric`
#> [INFO] Evaluating 1 parameter(s) for `gsm.reporting::MakeMetric`
#> [INFO] lWorkflows = lWorkflows: Passing lData$lWorkflows.
#> [INFO] Calling `gsm.reporting::MakeMetric`
#> [INFO] 11x18 data.frame saved as `lData$Reporting_Metrics`.
#> [INFO] Returning results from final step: 11x18 data.frame`.
#> [INFO] Completed `Reporting_Metrics` Workflow
#> [INFO] Initializing `Reporting_Results` Workflow
#> [INFO] Checking data against spec
#> [INFO] Workflow Step 1 of 5: `dplyr::pull`
#> [INFO] Evaluating 2 parameter(s) for `dplyr::pull`
#> [INFO] .data = Mapped_STUDY: Passing lData$Mapped_STUDY.
#> [INFO] var = GroupID: No matching data found. Passing 'GroupID' as a string.
#> [INFO] Calling `dplyr::pull`
#> [INFO] character of length 2 saved as `lData$GroupID`.
#> [INFO] Workflow Step 2 of 5: `unique`
#> [INFO] Evaluating 1 parameter(s) for `unique`
#> [INFO] x = GroupID: Passing lData$GroupID.
#> [INFO] Calling `unique`
#> [INFO] character of length 1 saved as `lData$strStudyID`.
#> [INFO] Workflow Step 3 of 5: `gsm.reporting::BindResults`
#> [INFO] Evaluating 4 parameter(s) for `gsm.reporting::BindResults`
#> [INFO] lAnalysis = lAnalyzed: Passing lData$lAnalyzed.
#> [INFO] strName = Analysis_Summary: No matching data found. Passing 'Analysis_Summary' as a string.
#> [INFO] strStudyID = strStudyID: Passing lData$strStudyID.
#> [INFO] dSnapshotDate = dSnapshotDate: No matching data found. Passing 'dSnapshotDate' as a string.
#> [INFO] Calling `gsm.reporting::BindResults`
#> [INFO] 66x10 data.frame saved as `lData$Results_Summary`.
#> [INFO] Workflow Step 4 of 5: `gsm.reporting::CalculateChange`
#> [INFO] Evaluating 2 parameter(s) for `gsm.reporting::CalculateChange`
#> [INFO] dfResults = Results_Summary: Passing lData$Results_Summary.
#> [INFO] dfResultsLongitudinal = Reporting_Results_Longitudinal: No matching data found. Passing 'Reporting_Results_Longitudinal' as a string.
#> [INFO] Calling `gsm.reporting::CalculateChange`
#> ℹ `dfResultsLongitudinal` not supplied properly, so dfResults will be returned unchanged.
#> [INFO] 66x10 data.frame saved as `lData$Reporting_Results_With_Changes`.
#> [INFO] Workflow Step 5 of 5: `gsm.kri::FilterByLatestSnapshotDate`
#> [INFO] Evaluating 1 parameter(s) for `gsm.kri::FilterByLatestSnapshotDate`
#> [INFO] df = Reporting_Results_With_Changes: Passing lData$Reporting_Results_With_Changes.
#> [INFO] Calling `gsm.kri::FilterByLatestSnapshotDate`
#> [INFO] 66x10 data.frame saved as `lData$Reporting_Results`.
#> [INFO] Returning results from final step: 66x10 data.frame`.
#> [INFO] Completed `Reporting_Results` Workflow
#> [INFO] Initializing `Reporting_Bounds` Workflow
#> [INFO] Checking data against spec
#> [INFO] Workflow Step 1 of 1: `gsm.reporting::MakeBounds`
#> [INFO] Evaluating 2 parameter(s) for `gsm.reporting::MakeBounds`
#> [INFO] dfResults = Reporting_Results: Passing lData$Reporting_Results.
#> [INFO] dfMetrics = Reporting_Metrics: Passing lData$Reporting_Metrics.
#> [INFO] Calling `gsm.reporting::MakeBounds`
#> Creating stacked dfBounds data for strMetrics
#> Parsed 0.842, 2.326 to numeric vector: 0.842, 2.326
#> Parsed 0.842, 2.326 to numeric vector: 0.842, 2.326
#> Parsed 0.842, 2.326 to numeric vector: 0.842, 2.326
#> Parsed 0.842, 2.326 to numeric vector: 0.842, 2.326
#> Parsed 0.842, 2.326 to numeric vector: 0.842, 2.326
#> Parsed 0.842, 2.326 to numeric vector: 0.842, 2.326
#> Parsed 0.842, 2.326 to numeric vector: 0.842, 2.326
#> Parsed 0.842, 2.326 to numeric vector: 0.842, 2.326
#> Parsed 0.842, 2.326 to numeric vector: 0.842, 2.326
#> Parsed 0.842, 2.326 to numeric vector: 0.842, 2.326
#> Parsed 0.842, 2.326 to numeric vector: 0.842, 2.326
#> [INFO] 0x0 data.frame saved as `lData$Reporting_Bounds`.
#> 
#> [INFO] Returning results from final step: 0x0 data.frame`.
#> 
#> [INFO] Completed `Reporting_Bounds` Workflow

names(lReporting)
#> [1] "Reporting_Groups"  "Reporting_Metrics" "Reporting_Results"
#> [4] "Reporting_Bounds"
```

There is deliberately no `Reporting_Input`. CTAS has no subject-level
numerator/denominator – each subject contributes a whole timeseries and
the statistic is computed on a distribution – so synthesising one would
be a fiction that renders misleadingly. The stock `gsm.kri` site report
does not need one.

``` r

lModuleWorkflows <- workr::MakeWorkflowList(
  strNames = NULL,
  strPath = system.file("workflow/4_modules", package = "gsm.ctas"),
  strPackage = NULL
)

workr::RunWorkflows(lModuleWorkflows, lReporting)
```

The module drops the stock scatter plot via
[`DropChart()`](../reference/DropChart.md). That chart plots
`Denominator` against `Numerator`, which suits a rate metric where the
denominator is exposure; here it is a coverage count, near-identical
across sites, so the points collapse onto one x position. The bar chart
and KRI table carry the same information on the $`-\log_{10}p`$ scale
the metric is actually defined on.

## Customising thresholds

Thresholds are exposed the gsm-native way, through `meta` and
`ParseThreshold`. Edit the metric YAML – no code change, no fork:

``` yaml
meta:
  Threshold: 0.842, 2.326   # flagging cut points, -log10(p) scale
  TriggerHigh: 2.326        # timeseries -> "Further Evaluation"
  TriggerLow: 0.842         # timeseries -> "Watch List"
```

`TriggerHigh` / `TriggerLow` classify *timeseries*, feeding `Numerator`.
`Threshold` classifies *groups*, feeding `Flag`. The same numbers,
different jobs.

The defaults `2.326` and `0.842` are one-sided normal z-quantiles (99%
and 80%) applied to a $`-\log_{10}p`$ scale, where they correspond to
$`p \approx 0.0047`$ and $`p \approx 0.144`$. They are adopted from
operational experience for consistency with existing CTAS review, and
documented here rather than silently inherited.

To use your own workflows, copy the shipped directory and point
`MakeWorkflowList()` at the copy:

``` r

lMyMetrics <- workr::MakeWorkflowList(
  strNames = NULL,
  strPath = "my_workflows/2_metrics",
  strPackage = NULL
)
```

## Adding a metric

A new metric is a YAML file, not a function. Copy `ctas0001.yaml` and
change a few `meta` fields:

``` yaml
meta:
  ID: ctas0012
  Metric: CTAS Labs Missingness Autocorrelation
  Feature: autocorr               # a ctas timeseries feature
  Domain: "Labs"                  # parameter_category_1
  Transformation: "ratio_missing" # parameter_category_3
```

`Domain` and `Transformation` are required **together**, and
[`Summarize_CTAS()`](../reference/Summarize_CTAS.md) errors if only one
is supplied. Neither identifies a family alone:

|             | `Domain`      | `Transformation`   |
|-------------|---------------|--------------------|
| `VS_*`      | `Vital Signs` | `numeric`          |
| `LB_NORM_*` | `Labs`        | `range_normalized` |
| `LB_MISS_*` | `Labs`        | `ratio_missing`    |

A selector matching nothing is an error rather than an empty result:
zero timeseries would render every site as unevaluated, which is
indistinguishable from a genuinely absent domain.

To score a feature the shipped workflows do not compute, add it to
`Features` in `1_mappings/CTAS_SiteScores.yaml` as well.

## Drill-down: handing off to ctasapp

Aggregation collapses many timeseries into one row per site. The
timeseries detail is retained separately for the `ctasapp` dashboard,
which is the tool for investigating a signal that the gsm report has
detected.

``` r

lDetail <- lMapped$Mapped_CTAS_Detail
vapply(lDetail, nrow, numeric(1))
#>       Results         Input Untransformed 
#>           324         14053         14053
```

`Results` is the site scores unchanged; `Input` is the analysed series
joined to site and parameter labels; `Untransformed` holds the original
values, so a lab result can be shown in its own units next to the
range-normalised value that was actually analysed. Write them out for
upload with:

``` r

Write_CTAS_Detail(lDetail, strPath = "ctas_detail", strFormat = "csv")
```

`parquet` is available via `Suggests: arrow`, and is worth using for
deployment – `Input` is one row per subject x parameter x timepoint and
grows quickly.
