# gsm.ctas (development)

## Multi-study redesign

* Multi-study inputs are honoured throughout: a `studyid` column is threaded
  through the mapping layer and `Analyze_CTAS()` splits the input by study,
  runs CTAS on each, and stacks the results with a `study` column on every
  row of `results`, `input` and `untransformed`.
* `Analyze_CTAS()` now returns a flat `list(ID, results, input, untransformed)`
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
