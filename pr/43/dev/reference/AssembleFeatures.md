# Compose the CTAS feature string from boolean flags

Aborts when every flag is `FALSE`, since `process_a_study()` fed an
empty feature string would fail with an opaque error deep inside the
engine.

## Usage

``` r
AssembleFeatures(
  bAutocorr,
  bAverage,
  bSD,
  bRange,
  bUniqueValueCountRelative,
  bOwnSiteSimilScore,
  bLOF
)
```
