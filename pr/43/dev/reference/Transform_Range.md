# Normalise reference-bounded numeric findings for CTAS

Consumes the long-format frame produced by
[`Standardize_Domain()`](Standardize_Domain.md) and normalises `value`
against the reference bounds `low`/`high` so results from different
tests are comparable on the same scale. The original values are
preserved as extra columns (`original_value`, `lower`, `upper`,
`original_category`).

## Usage

``` r
Transform_Range(
  dfInput,
  strPrefix = "RANGE",
  strFallbackPrefix = "NUM",
  dMaxShareMissingRange = 0.5
)
```

## Arguments

- dfInput:

  `data.frame` Long-format output of
  [`Standardize_Domain()`](Standardize_Domain.md) with the reference
  range columns `low`/`high`.

- strPrefix:

  `character` Prefix for the generated `parameter_id`.

- strFallbackPrefix:

  `character` Prefix for fields switched to raw numeric values.

- dMaxShareMissingRange:

  `numeric` Maximum share of observed values per field without a usable
  reference range before the field switches to raw numeric values.

## Value

`data.frame` in the CTAS long-format vocabulary carrying the extra
`original_value`/`lower`/`upper`/`original_category` columns.
`parameter_id` is prefixed with `strPrefix` (or `strFallbackPrefix`);
`parameter_category_2` keeps the raw input `parameter_id` so ctasapp can
stitch this metric with sibling metrics on the same field.

## Details

Rows are never dropped within a field: rows with a missing value or an
unusable reference range keep `result = NA` so CTAS can apply its
missingness threshold. Fields where more than `dMaxShareMissingRange` of
the observed values lack a usable range are emitted unnormalised as
`parameter_category_3 = "numeric"` with the `strFallbackPrefix` prefix.
Fields without any observed value are kept with `result = NA` and listed
in a message, so they still anchor source data in ctasapp.

## Data Specification

`dfInput` must include:

- `subject_id` - Subject identifier.

- `parameter_id` - Raw test code (e.g. `LBTESTCD`).

- `parameter_name` - Human-readable test label.

- `parameter_category_1` - Domain label (e.g. `"Labs"`).

- `parameter_category_2` - Field anchor; retained as the grouping key.

- `visit`, `visitnum` - Visit label and numeric ordering.

- `value`, `low`, `high` - Numeric result and reference bounds.
