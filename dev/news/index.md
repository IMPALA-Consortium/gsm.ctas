# Changelog

## gsm.ctas 0.0.0.9000

First development release. `gsm.ctas` integrates the `ctas` anomaly
detection engine into the gsm framework, from SDTM input through to a
rendered site-level KRI report.

### Mapping

- [`Input_Numeric()`](../reference/Input_Numeric.md),
  [`Input_Range()`](../reference/Input_Range.md),
  [`Input_OneHot()`](../reference/Input_OneHot.md) and
  [`Input_Missing()`](../reference/Input_Missing.md) map SDTM domains
  into the long-format timeseries `ctas` expects, one function per *data
  type* rather than per domain, so the same code serves VS, LB and RS.
  Domain-specific detail lives in the workflow YAML `spec`.
- [`Input_Subjects()`](../reference/Input_Subjects.md) maps subject and
  site metadata.
- [`Combine_CTAS_Input()`](../reference/Combine_CTAS_Input.md) binds
  these into the frames
  [`ctas::process_a_study()`](https://rdrr.io/pkg/ctas/man/process_a_study.html)
  requires.

### Preparation

- [`Prepare_Normalize()`](../reference/Prepare_Normalize.md) rescales a
  value by its reference range, making different tests comparable.
- [`Prepare_MissingRatio()`](../reference/Prepare_MissingRatio.md)
  derives a missingness ratio over time per subject and parameter.
- [`Prepare_Categorical()`](../reference/Prepare_Categorical.md) one-hot
  encodes categorical results into indicator timeseries.
- [`Prepare_TimepointRank()`](../reference/Prepare_TimepointRank.md)
  recomputes `timepoint_rank` after filtering or binding.

### Analysis

- [`Analyze_CTAS()`](../reference/Analyze_CTAS.md) wraps
  [`ctas::process_a_study()`](https://rdrr.io/pkg/ctas/man/process_a_study.html)
  with reproducible seeding and informative errors for degenerate
  studies, rather than an opaque failure deep inside the engine.
- [`Summarize_CTAS()`](../reference/Summarize_CTAS.md) aggregates
  timeseries-level scores into the gsm `Analysis_Analyzed` contract, one
  row per site. Sites with no evaluated timeseries are retained with
  `Denominator = 0` and `Score = NA`, so the report cannot silently drop
  them.
- [`Flag_CTAS()`](../reference/Flag_CTAS.md) flags one-sided
  (`0`/`1`/`2`). The `-log10(p)` scale is unsigned, so a flag says that
  a site differs, not in which direction.
- [`Combine_CTAS_Scores()`](../reference/Combine_CTAS_Scores.md)
  assembles scores across parameter families.

### Reporting

- [`DropChart()`](../reference/DropChart.md) removes the stock scatter
  plot from the KRI report. That chart plots `Denominator` against
  `Numerator`, which suits a rate metric where the denominator is
  exposure; here it is a coverage count, near-identical across sites, so
  the points collapse onto one x position.
- No `Analysis_Input` is emitted. CTAS has no subject-level
  numerator/denominator, so synthesising one would render misleadingly.
  The stock `gsm.kri` site report does not require it.

### Drill-down

- [`Combine_CTAS_Detail()`](../reference/Combine_CTAS_Detail.md) and
  [`Write_CTAS_Detail()`](../reference/Write_CTAS_Detail.md) retain and
  export the timeseries-level detail that aggregation discards, for
  handoff to the `ctasapp` dashboard. `csv` and, via `Suggests: arrow`,
  `parquet`.

### Workflows

- All four gsm workflow layers ship in `inst/workflow/`: `1_mappings`
  (including `CTAS_Input`, `CTAS_SiteScores` and `CTAS_Detail`),
  `2_metrics` (`ctas0001`-`ctas0011`), `3_reporting` and `4_modules`.
- [`ctas::process_a_study()`](https://rdrr.io/pkg/ctas/man/process_a_study.html)
  runs **once** per study, in `1_mappings/CTAS_SiteScores.yaml`; each
  metric workflow filters that shared result to one parameter family and
  one feature. Adding a metric is a YAML change, not a code change.
- Thresholds are configurable via `meta` and `ParseThreshold`. The
  defaults `2.326` and `0.842` are one-sided normal z-quantiles (99% and
  80%) on a `-log10(p)` scale, adopted for consistency with existing
  CTAS review practice.

### Documentation

- [`vignette("gsm-ctas")`](../articles/gsm-ctas.md) walks the full
  pipeline and both customisation paths.
- pkgdown site with a reference index organised by pipeline stage.
