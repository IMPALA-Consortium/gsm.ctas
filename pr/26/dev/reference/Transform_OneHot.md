# One-hot encode a categorical findings frame for CTAS

Consumes the long-format frame produced by
[`Standardize_Domain()`](Standardize_Domain.md) on a categorical source
(e.g. SDTM RS with `RSSTRESC`) and expands it into one row per
(observation x observed level of the same test), so that each level
becomes its own binary CTAS timeseries. Levels are enumerated within
each `parameter_category_2` so tests with different level sets stay
separated.

## Usage

``` r
Transform_OneHot(dfInput, strPrefix = "CAT")
```

## Arguments

- dfInput:

  `data.frame` Long-format output of
  [`Standardize_Domain()`](Standardize_Domain.md), with at minimum
  `subject_id`, `parameter_id`, `parameter_name`,
  `parameter_category_1`, `parameter_category_2`, `visit`, `visitnum`,
  `value`. `value` is treated as a character categorical.

- strPrefix:

  `character` Prefix for the generated `parameter_id`.

## Value

`data.frame` in the CTAS long-format vocabulary carrying the extra
`original_category` column. `parameter_id` is prefixed with `strPrefix`
and includes the level (`CAT_OVRLRESP=CR`); `parameter_category_2` keeps
the raw input test code so ctasapp stitches every level of the same test
into a single faceted field entry. `result` is the 0/1 indicator used by
[`Analyze_CTAS()`](Analyze_CTAS.md).

## Data Specification

`dfInput` must include:

- `subject_id` - Subject identifier.

- `parameter_id` - Raw test code (e.g. `RSTESTCD`).

- `parameter_name` - Human-readable test label.

- `parameter_category_1` - Domain label (e.g. `"Disease Response"`).

- `parameter_category_2` - Field anchor; levels are enumerated within
  it.

- `visit`, `visitnum` - Visit label and numeric ordering.

- `value` - Character categorical result.
