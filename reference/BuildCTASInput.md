# Derive the CTAS-shaped `subjects`, `parameters` and `data` from a long frame

Re-splits the single long frame consumed by
[`Analyze_CTAS()`](Analyze_CTAS.md) into the three data frames
[`ctas::process_a_study()`](https://rdrr.io/pkg/ctas/man/process_a_study.html)
requires. `country` and `region` are populated with `"no"` when absent,
matching the ctas defaults used in
[ctas::ctas_data](https://rdrr.io/pkg/ctas/man/ctas_data.html).

## Usage

``` r
BuildCTASInput(
  dfInput,
  strStudyCol,
  dfCustomTimeseries,
  dfCustomReferenceGroups
)
```
