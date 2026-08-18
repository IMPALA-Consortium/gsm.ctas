# gsm.ctas

<!-- badges: start -->
[![R-CMD-check](https://github.com/IMPALA-Consortium/gsm.ctas/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/IMPALA-Consortium/gsm.ctas/actions/workflows/R-CMD-check.yaml)
[![test-coverage](https://github.com/IMPALA-Consortium/gsm.ctas/actions/workflows/test-coverage.yaml/badge.svg)](https://github.com/IMPALA-Consortium/gsm.ctas/actions/workflows/test-coverage.yaml)
[![pkgdown](https://github.com/IMPALA-Consortium/gsm.ctas/actions/workflows/pkgdown-all.yaml/badge.svg)](https://github.com/IMPALA-Consortium/gsm.ctas/actions/workflows/pkgdown-all.yaml)
<!-- badges: end -->

`gsm.ctas` runs the [ctas](https://github.com/IMPALA-Consortium/ctas) clinical
trial anomaly detection engine inside the
[gsm](https://github.com/Gilead-Public/gsm.core) workflow framework, so that
CTAS site scores appear alongside the usual KRIs in a standard gsm site report.

The two frameworks answer different questions. gsm KRIs count events against
exposure -- enrolment rate, AE rate, query age. CTAS instead compares the
*distribution* of a site's measurements against the rest of the study, and so
detects patterns a rate-based metric cannot: values that are too consistent,
too smooth over time, too rounded, or missing in a structured way. This package
is the adapter that lets one report carry both.

## Installation

```r
install.packages("pak")
pak::pak("IMPALA-Consortium/gsm.ctas")
```

The gsm framework packages and `ctas` are declared in `Remotes` and will be
pulled in automatically. They are `Suggests`, not `Imports`: the mapping and
aggregation functions are usable on their own, and only the workflow layer
needs the full framework.

## Usage

`gsm.ctas` ships all four gsm workflow layers in `inst/workflow/`, so a full
run is a sequence of `RunWorkflows()` calls over SDTM input:

```r
library(gsm.ctas)

lRaw <- list(
  Raw_DM = as.data.frame(pharmaversesdtm::dm),
  Raw_VS = as.data.frame(pharmaversesdtm::vs),
  Raw_LB = as.data.frame(pharmaversesdtm::lb)
)

lMappingWorkflows <- workr::MakeWorkflowList(
  strNames = NULL,
  strPath = system.file("workflow/1_mappings", package = "gsm.ctas"),
  strPackage = NULL
)

lIngest <- gsm.mapping::Ingest(
  lRaw,
  gsm.mapping::CombineSpecs(lMappingWorkflows)
)

lMapped <- gsm.core::RunWorkflows(lMappingWorkflows, lIngest)
```

`lMapped$Mapped_CTAS_SiteScores` is then filtered by each metric workflow in
`2_metrics`, summarised into the gsm analysis contract, and rendered by the
stock `gsm.kri` site report. The full path -- including reporting and the
rendered HTML -- is in `vignette("gsm-ctas")`.

## How it fits together

```
lRaw --Ingest--> lIngest --1_mappings--> lMapped --2_metrics--> lAnalysis
     --3_reporting--> Reporting_* --4_modules--> HTML report
```

| Layer | Contents |
|---|---|
| `1_mappings` | `DM`, `VS`, `LB`, `SITE`, `STUDY`, plus `CTAS_Input` -> `CTAS_SiteScores` -> `CTAS_Detail` |
| `2_metrics` | `ctas0001`-`ctas0011`, one per parameter family x CTAS feature |
| `3_reporting` | `Groups`, `Metrics`, `Results`, `Bounds` |
| `4_modules` | `report_kri_site` |

The key structural point is that CTAS is an *all-metrics-at-once* engine. A
single `ctas::process_a_study()` call scores every timeseries x feature x site,
so it runs **once**, in `1_mappings/CTAS_SiteScores.yaml`. Each metric workflow
then merely filters that shared result down to one parameter family and one
feature. Adding a metric is therefore a YAML change, not a code change.

## Extending

Both common customisations are config-only and are documented in the vignette:

- **Thresholds** are exposed the gsm-native way, through `meta` and
  `ParseThreshold` in each metric YAML.
- **New metrics** are added by copying a metric YAML and changing the `Feature`,
  `Domain` and `Transformation` fields.

## Related packages

| Package | Role |
|---|---|
| [`ctas`](https://github.com/IMPALA-Consortium/ctas) | The statistics engine |
| [`gsm.core`](https://github.com/Gilead-Public/gsm.core) | Workflow execution |
| [`gsm.kri`](https://github.com/Gilead-Public/gsm.kri) | Report rendering |
| `ctasapp` | Dashboard for drilling into a flagged site |

The division of labour between the last two is deliberate: the gsm report
detects signals, `ctasapp` investigates them. `Combine_CTAS_Detail()` and
`Write_CTAS_Detail()` retain the timeseries-level detail that aggregation
discards, for handoff to the dashboard.

## Contributing

Issues and pull requests are welcome. Please use the issue templates in
`.github/ISSUE_TEMPLATE/`.

Exported functions follow a stage-based naming scheme --
`Input_*` (SDTM to CTAS input), `Prepare_*` (make values comparable),
`Analyze_*` / `Summarize_*` / `Flag_*` (run CTAS and bridge into gsm),
`Combine_*` and `Write_*` (assemble and export). Note that `Transform_*` is
**not** used, as it carries a specific and different meaning within gsm itself.

## License

MIT. See [LICENSE.md](LICENSE.md).
