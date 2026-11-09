# Convert findings to a running missing-ratio timeseries for CTAS

Consumes the long-format frame produced by
[`Standardize_Domain()`](Standardize_Domain.md) and replaces `value`
with a running missing ratio per (subject, parameter, visit) so CTAS can
score sites on data-completeness patterns. Rows with `NA` values are
kept because they carry the signal. Fields that are `NA` for every row
are kept as well (their ratio is a constant `1`) and listed in a message
so the all-missing case is explicit.

## Usage

``` r
Transform_Missing(dfInput, strPrefix = "MISS")
```

## Arguments

- dfInput:

  `data.frame` Long-format output of
  [`Standardize_Domain()`](Standardize_Domain.md).

- strPrefix:

  `character` Prefix for the generated `parameter_id`.

## Value

`data.frame` in the CTAS long-format vocabulary. `parameter_id` is
prefixed with `strPrefix`; `parameter_category_2` keeps the raw input
`parameter_id` so ctasapp can stitch this metric with sibling metrics on
the same field.

## Data Specification

`dfInput` must include:

- `subject_id` - Subject identifier.

- `parameter_id` - Raw test code (e.g. `LBTESTCD`).

- `parameter_name` - Human-readable test label.

- `parameter_category_1` - Domain label (e.g. `"Labs"`).

- `parameter_category_2` - Field anchor; retained as the grouping key.

- `visit`, `visitnum` - Visit label and numeric ordering.

- `value` - Numeric result; `NA` carries the missingness signal.
