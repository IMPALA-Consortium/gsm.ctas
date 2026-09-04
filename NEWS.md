# gsm.ctas (development)

* **Breaking:** `Summarize_CTAS()` no longer emits `Numerator`,
  `Denominator` or `Metric` columns. These were placeholder columns
  satisfying the gsm reporting contract; `Metric` was a pure alias for
  `Score`, and CTAS has no natural numerator/denominator. Callers that
  want `Flag_CTAS(strAccrualMetric = ...)` accrual gating must supply
  those columns themselves.

* **Internal:** removed unused `inst/report/Report_KRI.Rmd`;
  `Report_CTAS.Rmd` is the sole report template. Renamed
  `inst/workflow/4_modules/report_kri_site.yaml` to
  `report_ctas_site.yaml` (with matching `meta.ID`). Rewrote KRI-specific
  wording ("KRI Overview", "Red/Amber KRIs") to CTAS terms in the report
  template.

* **Internal:** workflow execution now calls `workr::RunWorkflows()`
  (the lightweight runtime extracted from `gsm.core`) instead of
  `gsm.core::RunWorkflows()`. `gsm.core` stays in `Suggests` because
  `gsm.mapping::MakeLongMeta()` (used by `SITE.yaml` / `STUDY.yaml`)
  pulls it transitively.

* **Breaking:** `Bind_Analysis()` is renamed to `BindResults_CTAS()` to
  echo `gsm.reporting::BindResults()` while keeping the ctasapp
  column-contract shaping (`studyid` -> `study` rename and the
  `untransformed` `original_value`/`original_category` filter).

* **Breaking:** `Input_Range()`, `Input_Missing()` and `Input_OneHot()`
  are renamed to `Transform_Range()`, `Transform_Missing()` and
  `Transform_OneHot()` to match the `gsm.core::Transform_*` naming
  convention. Workflow YAML step names, the vignette and the test file
  are updated in step. `Transform_Range()` now emits a `cli::cli_warn()`
  reporting how many rows were dropped for `NA` `value` or an unusable
  reference range.

## Reinstated markdown KRI report on top of the gsm.kri engine

* New `Summarize_CTAS(dfResults, dfSubjects, bIncludeMissingness, bByFeature,
  strStudyID, dSnapshotDate)` aggregates the long CTAS results frame
  (`Reporting_Results$results`) into the gsm reporting `dfResults` contract:
  one row per site x synthetic `MetricID`. `MetricID` is `ctas_<field>` by
  default; pass `bByFeature = TRUE` for `ctas_<field>_<feature>`.
  `Score = max(fdr_corrected_pvalue_logp)` per group and sites present in
  `dfSubjects` but with no scored timeseries are retained with `Score = NA`
  and `Numerator = Denominator = 0`.
* New `Flag_CTAS(dfAnalyzed, strColumn, vThreshold, vFlag, vFlagOrder,
  nAccrualThreshold, strAccrualMetric)` mirrors the `gsm.core::Flag()`
  seam with unsigned CTAS defaults for the `-log10(p)` scale: two
  ascending thresholds (`0.842` amber, `2.326` red) and three flag levels
  (`0`, `1`, `2`). Left-closed intervals; optional accrual filter NAs out
  Score + Flag when sites don't meet a minimum count.
* New `Make_KRI_Metrics()` and `Make_KRI_Groups()` shape the minimal
  `dfMetrics` and `dfGroups` frames the stock `gsm.kri` KRI report
  consumes (one metric row per `MetricID`; `Enrolled` + placeholder
  `InvestigatorLastName` per site).
* New `inst/workflow/3_reporting/Summary.yaml` (Priority 3) chains those
  four steps into a `Reporting_Summary` list of `summary`, `metrics`, and
  `groups` frames. Missingness inclusion, by-feature grouping, and flag
  thresholds are workflow `meta` parameters, so a sponsor can retune them
  in YAML without editing R.
* New `inst/workflow/4_modules/report_kri_site.yaml` module renders the
  site-level HTML report by piping the vendored
  `inst/report/Report_CTAS.Rmd` template into `gsm.kri::Report_KRI()` via
  `strInputPath`. The template collapses the family-granular audit
  (`Reporting_Summary$metrics`) inline for every join and renders the
  full frame as the "Metric Details" `gt` table. `gsm.kri` and
  `gsm.reporting` move to `Suggests:` so the CTAS mapping + analysis
  stack stays lightweight.

## ctasapp compatibility fixes for the queries reporting frame

* `Standardize_Queries()` now drops `site`, `country`, and `studyid` from
  the emitted queries frame. ctasapp re-joins `site` onto queries with
  `dplyr::left_join(by = "subject_id")`, and a duplicate column silently
  produced `site.x`/`site.y` and broke the downstream `site` filter, so the
  ctasapp query table stayed empty.
* `Standardize_Queries(dfQueries, dfSubjects, dfInput)` now accepts the
  bound `Reporting_Input` frame and fans each raw `parameter_id` (a
  field-level test code such as `"AST"`) out onto every transformed CTAS
  parameter id sharing the same `parameter_category_2`
  (e.g. `"RANGE_AST"`, `"MISS_AST"`, `"CAT_OVRLRESP=CR"`). ctasapp joins
  queries onto measures by the transformed id, so raw codes never matched
  and the query table and timeseries overlay were empty.
* `inst/workflow/3_reporting/Queries.yaml` now depends on the
  `Reporting_Results` list produced by the `Results` reporting workflow
  (Priority 1) and pulls `input` out of it via `base::getElement` before
  handing it to `Standardize_Queries()`.

## `Write_Results()` renamed to `Write_ctasapp()`

* Same signature and behaviour, but the name now reflects that the target
  layout is the ctasapp dashboard. The `dfQueries` argument accepts the
  standardised queries frame produced by the `Queries` reporting workflow
  (typically `lReportingQueries$Reporting_Queries$queries`) and writes it
  alongside the metric shards as `queries.<format>`.

## Queries standardisation and reporting

* New `Standardize_Queries()` maps the ctasapp query-upload contract into
  the CTAS long vocabulary: `study`/`subject_id`/`visit`/`field`
  become `studyid`/`subject_id`/`timepoint_1_name`/`parameter_category_2`,
  and `domain` is translated to `parameter_category_1` (`LB` -> `"Labs"`,
  `VS` -> `"Vital Signs"`, `EG` -> `"ECG"`, `RS` -> `"Disease Response"`;
  unknown domains pass through). Rows are inner-joined to
  `Mapped_Subjects` on `(studyid, subject_id)`.
* New `inst/workflow/1_mappings/Queries.yaml` produces `Mapped_Queries`
  as a pass-through of `Raw_Queries`, and new
  `inst/workflow/3_reporting/Queries.yaml` calls `Standardize_Queries()`
  to emit `lReportingQueries$queries`. `Results.yaml` is untouched.

## Bundled SDTM sample data

* Ships verbatim copies of the `pharmaversesdtm` domains needed by the
  workflow (`dm`, `lb`, `vs`, `eg`, `rs`) as bundled datasets, plus a
  synthetic `queries` frame matching the ctasapp upload contract. The
  regeneration scripts live under `data-raw/` (not installed) and run
  deterministically from a fixed seed.

## Derived BMI category flows through the categorical metric

* New mapping `inst/workflow/1_mappings/BMI.yaml` derives per-visit BMI
  category rows entirely in DuckDB SQL via `workr::RunQuery`. HEIGHT is
  pooled to one value per subject (median across screening rows), each
  `WEIGHT` row is joined 1:1, and BMI is bucketed into the WHO adult
  categories (`"Underweight"`, `"Normal"`, `"Overweight"`, `"Obese"`).
  Output rows carry `VSTESTCD = "BMICAT"` in the standard SDTM shape.
* `inst/workflow/2_metrics/categorical.yaml` now standardises `Mapped_RS`
  (as `"Disease Response"`) and `Mapped_BMI` (as `"BMI"`) separately, then
  row-binds them before `Input_OneHot()`. `parameter_category_1` traces
  each row back to its source, and the CTAS categorical run scores both
  disease response and BMI-category site-level rates in a single
  Analysis slot.

## Numeric metric now covers VS and EG in one Analysis slot

* `inst/workflow/2_metrics/numeric.yaml` now standardises `Mapped_VS` and
  `Mapped_EG` separately (each with its own `strCategory` -- `"Vital Signs"`
  and `"ECG"`) then row-binds them with `dplyr::bind_rows` before a single
  `Analyze_CTAS` call. `parameter_category_1` is stamped once, at
  standardisation time, and every downstream step is category-agnostic --
  so any additional numeric findings domain (LB, VS, EG, ...) can be
  wired into the same metric as a YAML-only edit.
* The dedicated `numeric_eg` metric YAML is removed.

## Categorical rows carry original_category into `untransformed`

* New `Prepare_Untransformed()` helper de-duplicates a metric `input` frame
  to one row per `(subject_id, parameter_category_2, timepoint_1_name)`,
  so an `Input_OneHot()` output (multiplied by observed level) can flow
  through the reporting workflow as an `untransformed` shard without
  repeating each source observation once per level.
* `inst/workflow/2_metrics/categorical.yaml` now emits an `untransformed`
  entry backed by `Prepare_Untransformed(Temp_CTAS_Values)`, so
  `pub/untransformed.parquet` includes `OVRLRESP` (and any other one-hot
  test) with the raw label (`"CR"`, `"PR"`, `"SD"`, `"PD"`, ...) in
  `original_category`.
* `Bind_Analysis(strName = "untransformed")` now keeps rows where **either**
  `original_value` or `original_category` is non-`NA`. Numeric metrics
  keep contributing their `original_value`; categorical metrics keep
  contributing their `original_category`.

## Visit rank normalization in Standardize_Domain

* `Standardize_Domain()` now recalculates `visitnum` and `timepoint_rank`
  as a contiguous `1..N` `row_number()` per `(subject_id, parameter_id)`,
  ordered by the source `VISITNUM` with `VISIT` as a tiebreaker -- the
  same algorithm as ctasapp's `recalculate_timepoint_rank()`. Callers no
  longer need to remember to normalize the rank downstream, and the
  `Prepare_TimepointRank()` call inside `Analyze_CTAS()` is now an
  idempotent safety net.

## Reporting: bind shards without writing

* New `Bind_Analysis(lAnalysis, strName)` concatenates one named shard
  (`"results"`, `"input"` or `"untransformed"`) across every metric workflow
  output. Renames `studyid` -> `study` and drops untransformed rows with
  missing `original_value`, matching the ctasapp column contract.
* New `inst/workflow/3_reporting/Results.yaml` runs three `Bind_Analysis`
  steps and packages the bound frames as `list(results, input,
  untransformed)`, ready to hand to
  [ctasapp](https://github.com/IMPALA-Consortium/ctasapp) validators or
  write to parquet.
* `Write_Results()` now delegates its binding step to `Bind_Analysis()` so
  the two entry points stay consistent.

## Categorical / one-hot metric

* New `Input_OneHot()` wrapper expands a categorical `value` column into one
  row per (observation x observed level of the same test) and encodes
  `result` as a 0/1 indicator. Levels are enumerated per
  `parameter_category_2`, so distinct RS tests stay separated. Follows the
  existing `Input_Range()` / `Input_Missing()` shape and prefixes
  `parameter_id` with `"CAT"` (e.g. `CAT_OVRLRESP=CR`) while keeping
  `parameter_category_2` as the raw test code so ctasapp stitches every
  level of the same test into one faceted field entry.
* New `inst/workflow/1_mappings/RS.yaml` maps SDTM RS (Disease Response,
  `pharmaversesdtm::rs_onco`) and filters to `RSTESTCD == "OVRLRESP"`.
* New `inst/workflow/2_metrics/categorical.yaml` chains
  `Standardize_Domain` -> `Input_OneHot` -> `Analyze_CTAS` with the binary
  series feature toggles (average on; autocorrelation, SD, range and unique
  value count off).
* `Standardize_Domain()` now leaves `result` as `NA_real_` when the raw
  value column is not numeric (character categorical sources), instead of
  emitting a coercion warning.

## Numeric-by-default `Standardize_Domain()`

* **Breaking:** `Input_Numeric()` is removed. `Standardize_Domain()` now
  emits the numeric CTAS-vocab columns (`parameter_category_2`,
  `parameter_category_3 = "numeric"`, `timepoint_1_name`, `timepoint_rank`,
  `result`, `baseline`) alongside the raw SDTM-derived columns, so the
  numeric metric YAML feeds the standardised frame straight into
  `Analyze_CTAS()`. Range and ratio-missing metrics still chain
  `Input_Range()` / `Input_Missing()` to overwrite `result`,
  `parameter_category_3`, and prefix `parameter_id`.
* `Standardize_Domain()` gains an optional `strPrefix` argument
  (default `""`) that prefixes `parameter_id` when supplied. The raw test
  code is preserved on `parameter_category_2` so ctasapp can still stitch
  sibling metrics.

## ctasapp stitching contract

* **Breaking:** `Input_Numeric()`, `Input_Range()` and `Input_Missing()`
  now keep `parameter_category_2` equal to the raw input `parameter_id`
  (e.g. `LBTESTCD`) instead of prefixing it with the transformation. This
  makes the same test's `range_normalized` and `ratio_missing` metrics
  stitch into a single ctasapp field entry. `parameter_id` remains
  prefixed (`NUM_`, `RANGE_`, `MISS_`) so score tables stay unique.

## ctasval-aligned redesign

* Adopted the [ctasval](https://github.com/IMPALA-Consortium/ctasval)
  single-frame convention: every stage after `Standardize_Domain()` operates
  on one long-format data frame carrying subject, site, parameter, timepoint,
  result and (for range) untransformed detail. `Analyze_CTAS()` re-derives
  the CTAS `subjects`, `parameters` and `data` internally via `distinct()`.
* New exported `Standardize_Domain()` renames an SDTM findings domain into
  the CTAS + ctasapp vocabulary and joins the standardised subject table in
  a single step. Metric YAMLs now chain
  `Standardize_Domain -> Input_* -> Analyze_CTAS` with three steps.
* `Input_Numeric()`, `Input_Range()` and `Input_Missing()` are now `df -> df`
  functions that consume the output of `Standardize_Domain()` and enrich it
  with the CTAS `result`/`baseline` columns and category triad.
  `Input_Range()` preserves the pre-transform values as extra columns
  (`original_value`/`lower`/`upper`/`original_category`) on the same frame;
  `Analyze_CTAS()` detects these and emits the `untransformed` shard.
* `Combine_CTAS_Input()`, `Input_Subjects()` and `Input_OneHot()` are removed;
  they are no longer required with the single-df flow.
* `Analyze_CTAS()` gains named `dfCustomTimeseries` and
  `dfCustomReferenceGroups` arguments (defaulting to `ctas::ctas_data`) so
  the ctas customisation surface is exposed at the wrapper.

## Multi-study redesign

* Multi-study inputs are honoured throughout: a `studyid` column is threaded
  through the mapping layer and `Analyze_CTAS()` splits the input by study,
  runs CTAS on each, and stacks the results with a `study` column on every
  row of `results`, `input` and `untransformed`.
* `Analyze_CTAS()` returns a flat `list(ID, results, input, untransformed)`
  in the shape [ctasapp](https://github.com/IMPALA-Consortium/ctasapp)
  uploads consume. Feature selection is expressed as seven boolean flags
  (`bAutocorr`, `bAverage`, `bSD`, `bRange`, `bUniqueValueCountRelative`,
  `bOwnSiteSimilScore`, `bLOF`) instead of a semicolon-delimited string.
* New `Write_Results()` binds the shards across metric workflows and writes
  them as parquet or csv in the layout ctasapp reads.
* Retired the gsm reporting bridge: `Combine_CTAS_Scores()`,
  `Combine_CTAS_Detail()`, `Summarize_CTAS()`, `Flag_CTAS()`, `DropChart()`
  and `Write_CTAS_Detail()` are removed. The `Bounds`/`Groups`/`Metrics`/
  `Results` reporting YAMLs and the `4_modules` KRI report have been
  retired with them.
* Each metric YAML now runs CTAS once for its data type and emits the
  ctasapp shards directly, keyed by a single `ID` in `meta:` instead of the
  `ctas000X` grid.

# gsm.ctas 0.0.0.9000

First development release. `gsm.ctas` integrates the `ctas` anomaly detection
engine into the gsm framework, from SDTM input through to a rendered site-level
KRI report.

## Mapping

* `Input_Numeric()`, `Input_Range()`, `Input_OneHot()` and `Input_Missing()` map
  SDTM domains into the long-format timeseries `ctas` expects, one function per
  *data type* rather than per domain, so the same code serves VS, LB and RS.
  Domain-specific detail lives in the workflow YAML `spec`.
* `Input_Subjects()` maps subject and site metadata.
* `Combine_CTAS_Input()` binds these into the frames
  `ctas::process_a_study()` requires.

## Preparation

* `Prepare_Normalize()` rescales a value by its reference range, making
  different tests comparable.
* `Prepare_MissingRatio()` derives a missingness ratio over time per subject and
  parameter.
* `Prepare_Categorical()` one-hot encodes categorical results into indicator
  timeseries.
* `Prepare_TimepointRank()` recomputes `timepoint_rank` after filtering or
  binding.

## Analysis

* `Analyze_CTAS()` wraps `ctas::process_a_study()` with reproducible seeding and
  informative errors for degenerate studies, rather than an opaque failure deep
  inside the engine.
* `Summarize_CTAS()` aggregates timeseries-level scores into the gsm
  `Analysis_Analyzed` contract, one row per site. Sites with no evaluated
  timeseries are retained with `Denominator = 0` and `Score = NA`, so the report
  cannot silently drop them.
* `Flag_CTAS()` flags one-sided (`0`/`1`/`2`). The `-log10(p)` scale is
  unsigned, so a flag says that a site differs, not in which direction.
* `Combine_CTAS_Scores()` assembles scores across parameter families.

## Reporting

* `DropChart()` removes the stock scatter plot from the KRI report. That chart
  plots `Denominator` against `Numerator`, which suits a rate metric where the
  denominator is exposure; here it is a coverage count, near-identical across
  sites, so the points collapse onto one x position.
* No `Analysis_Input` is emitted. CTAS has no subject-level
  numerator/denominator, so synthesising one would render misleadingly. The
  stock `gsm.kri` site report does not require it.

## Drill-down

* `Combine_CTAS_Detail()` and `Write_CTAS_Detail()` retain and export the
  timeseries-level detail that aggregation discards, for handoff to the
  `ctasapp` dashboard. `csv` and, via `Suggests: arrow`, `parquet`.

## Workflows

* All four gsm workflow layers ship in `inst/workflow/`: `1_mappings`
  (including `CTAS_Input`, `CTAS_SiteScores` and `CTAS_Detail`), `2_metrics`
  (`ctas0001`-`ctas0011`), `3_reporting` and `4_modules`.
* `ctas::process_a_study()` runs **once** per study, in
  `1_mappings/CTAS_SiteScores.yaml`; each metric workflow filters that shared
  result to one parameter family and one feature. Adding a metric is a YAML
  change, not a code change.
* Thresholds are configurable via `meta` and `ParseThreshold`. The defaults
  `2.326` and `0.842` are one-sided normal z-quantiles (99% and 80%) on a
  `-log10(p)` scale, adopted for consistency with existing CTAS review practice.

## Documentation

* `vignette("gsm-ctas")` walks the full pipeline and both customisation paths.
* pkgdown site with a reference index organised by pipeline stage.
