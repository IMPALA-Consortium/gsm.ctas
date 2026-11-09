# Bind one named shard across metric workflow outputs

Stacks the `strName` element (`"results"`, `"input"` or
`"untransformed"`) from every entry of `lAnalysis` into a single data
frame. Used by the reporting workflow to concatenate metric shards into
the frames [ctasapp](https://github.com/IMPALA-Consortium/ctasapp)
reads, and reused internally by [`Write_ctasapp()`](Write_ctasapp.md).

## Usage

``` r
BindResults_CTAS(lAnalysis, strName)
```

## Arguments

- lAnalysis:

  `list` Named list of metric workflow outputs, each with `results`,
  `input` and optionally `untransformed` frames.

- strName:

  `character` Frame name to pluck from each entry.

## Value

`data.frame` The bound frame. Zero rows when no entry contained the
frame.

## Details

`studyid` is renamed to `study` when present so the bound frames match
the ctasapp column convention.

For `"untransformed"`, the transformation columns (`value`, `result`,
`low`, `high`, `parameter_id`, `parameter_category_3`) are removed
before binding, since their types differ between metrics. Rows where no
value was reported are kept so source data stays visible in ctasapp.
Rows are de-duplicated on the ctasapp join keys (`study`, `subject_id`,
`parameter_category_2`, `timepoint_1_name`), keeping the row with the
most non-missing `original_value`/`lower`/`upper`/`original_category`,
so a field fed into several metrics appears once.

## Examples

``` r
if (FALSE) { # \dontrun{
BindResults_CTAS(lAnalysis, "results")
} # }
```
