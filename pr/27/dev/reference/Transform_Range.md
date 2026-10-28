# Normalise reference-bounded numeric findings for CTAS

Consumes the long-format frame produced by
[`Standardize_Domain()`](Standardize_Domain.md) and normalises `value`
against the reference bounds `low`/`high` so results from different
tests are comparable on the same scale. The original values are
preserved as extra columns (`original_value`, `lower`, `upper`,
`original_category`) so [`Analyze_CTAS()`](Analyze_CTAS.md) can emit the
ctasapp-shaped `untransformed` frame without extra bookkeeping.

## Usage

``` r
Transform_Range(dfInput, strPrefix = "RANGE")
```

## Arguments

- dfInput:

  `data.frame` Long-format output of
  [`Standardize_Domain()`](Standardize_Domain.md) with the reference
  range columns `low`/`high`.

- strPrefix:

  `character` Prefix for the generated `parameter_id`.

## Value

`data.frame` in the CTAS long-format vocabulary carrying the extra
`original_value`/`lower`/`upper`/`original_category` columns.
`parameter_id` is prefixed with `strPrefix`; `parameter_category_2`
keeps the raw input `parameter_id` so ctasapp can stitch this metric
with sibling metrics on the same field.

## Data Specification

`dfInput` must include:

- `subject_id` - Subject identifier.

- `parameter_id` - Raw test code (e.g. `LBTESTCD`).

- `parameter_name` - Human-readable test label.

- `parameter_category_1` - Domain label (e.g. `"Labs"`).

- `parameter_category_2` - Field anchor; retained as the grouping key.

- `visit`, `visitnum` - Visit label and numeric ordering.

- `value`, `low`, `high` - Numeric result and reference bounds.
