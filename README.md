# gsm.ctas

<!-- badges: start -->

<div class="pkgdown-release">

[![R-CMD-check](https://github.com/IMPALA-Consortium/gsm.ctas/actions/workflows/R-CMD-check.yaml/badge.svg?branch=main)](https://github.com/IMPALA-Consortium/gsm.ctas/actions/workflows/R-CMD-check.yaml)
[![test-coverage](https://github.com/IMPALA-Consortium/gsm.ctas/actions/workflows/test-coverage.yaml/badge.svg?branch=main)](https://github.com/IMPALA-Consortium/gsm.ctas/actions/workflows/test-coverage.yaml)
[![pkgdown-all](https://github.com/IMPALA-Consortium/gsm.ctas/actions/workflows/pkgdown-all.yaml/badge.svg?branch=main)](https://github.com/IMPALA-Consortium/gsm.ctas/actions/workflows/pkgdown-all.yaml)

</div>

<div class="pkgdown-devel">

[![R-CMD-check](https://github.com/IMPALA-Consortium/gsm.ctas/actions/workflows/R-CMD-check.yaml/badge.svg?branch=dev)](https://github.com/IMPALA-Consortium/gsm.ctas/actions/workflows/R-CMD-check.yaml)
[![test-coverage](https://github.com/IMPALA-Consortium/gsm.ctas/actions/workflows/test-coverage.yaml/badge.svg?branch=dev)](https://github.com/IMPALA-Consortium/gsm.ctas/actions/workflows/test-coverage.yaml)
[![pkgdown-all](https://github.com/IMPALA-Consortium/gsm.ctas/actions/workflows/pkgdown-all.yaml/badge.svg?branch=dev)](https://github.com/IMPALA-Consortium/gsm.ctas/actions/workflows/pkgdown-all.yaml)

</div>

<!-- badges: end -->

`gsm.ctas` runs the [ctas](https://github.com/IMPALA-Consortium/ctas) clinical
trial anomaly detection engine inside the
[gsm](https://github.com/Gilead-Public/gsm.core) workflow framework and writes
the three files the
[ctasapp](https://github.com/IMPALA-Consortium/ctasapp) dashboard reads.

The two frameworks answer different questions. gsm KRIs count events against
exposure -- enrolment rate, AE rate, query age. CTAS instead compares the
*distribution* of a site's measurements against the rest of the study, and so
detects patterns a rate-based metric cannot: values that are too consistent,
too smooth over time, too rounded, or missing in a structured way. This package
is the adapter that lets one workflow run both and drop the result on ctasapp.

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

`gsm.ctas` ships three gsm workflow layers in `inst/workflow/`, so a full run
is a sequence of `RunWorkflows()` calls over SDTM input:

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

lMetricWorkflows <- workr::MakeWorkflowList(
  strNames = NULL,
  strPath = system.file("workflow/2_metrics", package = "gsm.ctas"),
  strPackage = NULL
)

lAnalysis <- gsm.core::RunWorkflows(lMetricWorkflows, lMapped)

lReportingWorkflows <- workr::MakeWorkflowList(
  strNames = NULL,
  strPath = system.file("workflow/3_reporting", package = "gsm.ctas"),
  strPackage = NULL
)

lReporting <- gsm.core::RunWorkflows(
  lReportingWorkflows,
  c(lMapped, list(lAnalyzed = lAnalysis))
)

Write_ctasapp(lReporting, strDir = "ctas_shards", strFormat = "parquet")
```

The last line writes `results.parquet`, `input.parquet` and (when non-empty)
`untransformed.parquet` in the shape ctasapp uploads. The full walkthrough --
mapping, metric YAMLs and the shard contract -- is in `vignette("gsm-ctas")`.

## How it fits together

```
lRaw --Ingest--> lIngest --1_mappings--> lMapped --2_metrics--> lAnalysis
     --3_reporting--> ctasapp shards on disk
```

| Layer | Contents |
|---|---|
| `1_mappings` | SDTM readers (`DM`, `VS`, `LB`), site/study group tables, plus the transformation-typed frames `Subjects`, `Numeric`, `Range` |
| `2_metrics` | One YAML per data-type transformation (`numeric`, `range_normalized`, `ratio_missing`), each running CTAS once |
| `3_reporting` | `Write_ctasapp`: bind ctasapp shards across metrics and write them to disk |

Each metric emits three flat frames -- `results`, `input`, `untransformed` --
in the shape ctasapp uploads consume. Multi-study inputs are honoured
automatically via a `studyid` column threaded through the mapping layer:
`Analyze_CTAS()` splits the input by study, runs CTAS on each, and stacks the
results with a `study` column on every row.

## Extending

Both common customisations are config-only and are documented in the vignette:

- **CTAS features** are exposed as boolean toggles in each metric's `meta:`
  (`FeatureAutocorr`, `FeatureAverage`, ...), so any metric can score any
  subset without editing R.
- **New metrics** are added by copying a metric YAML and pointing it at a
  different mapped frame or transformation.

## Related packages

| Package | Role |
|---|---|
| [`ctas`](https://github.com/IMPALA-Consortium/ctas) | The statistics engine |
| [`gsm.core`](https://github.com/Gilead-Public/gsm.core) | Workflow execution |
| [`ctasapp`](https://github.com/IMPALA-Consortium/ctasapp) | Dashboard for drilling into a flagged site |

`gsm.ctas` detects signals; `ctasapp` investigates them. `Write_ctasapp()`
retains the timeseries-level detail that aggregation would discard, in the
layout ctasapp reads.

## Contributing

Issues and pull requests are welcome. Please use the issue templates in
`.github/ISSUE_TEMPLATE/`.

Exported functions follow a stage-based naming scheme --
`Input_*` (SDTM to CTAS input), `Prepare_*` (make values comparable),
`Analyze_*` (run CTAS and emit ctasapp shards), `Combine_*` and `Write_*`
(assemble and export). Note that `Transform_*` is **not** used, as it carries
a specific and different meaning within gsm itself.

## License

MIT. See [LICENSE.md](LICENSE.md).
