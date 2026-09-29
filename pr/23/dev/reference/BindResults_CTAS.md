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

  `character` Shard name to pluck from each entry.

## Value

`data.frame` The bound frame. Zero rows when no entry contained the
shard.

## Details

`studyid` is renamed to `study` when present so the bound frames match
the ctasapp column convention. For `"untransformed"`, rows are dropped
only when both `original_value` and `original_category` are missing –
numeric metrics carry `original_value`, categorical metrics carry
`original_category`, and either signal is enough to keep the row.

## Examples

``` r
if (FALSE) { # \dontrun{
BindResults_CTAS(lAnalysis, "results")
} # }
```
