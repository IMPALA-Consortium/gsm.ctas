# Write ctasapp shards to disk

Writes the frames produced by the `3_reporting` workflows into `strDir`
in the layout the
[ctasapp](https://github.com/IMPALA-Consortium/ctasapp) dashboard reads.
The function walks `lReporting` two levels deep: each top-level element
is a reporting-workflow output (a named list of frames) and every data
frame it contains is written using its inner name as the file stem.
Top-level bare data frames (e.g. `Reporting_Metrics`) are also written,
keyed by the lowercase workflow ID (`Reporting_Metrics` -\>
`metrics.parquet`) so ctasapp picks them up even when the Summary
workflow that wraps them is skipped. This handles both the metric side
(`Reporting_Results = list(results, input, untransformed)`) and the
queries side (`Reporting_Queries = list(queries)`) in a single call.

## Usage

``` r
Write_ctasapp(lReporting, strDir, strFormat = "parquet")
```

## Arguments

- lReporting:

  `list` Output of
  [`workr::RunWorkflows()`](https://rdrr.io/pkg/workr/man/RunWorkflows.html)
  on the reporting workflows – a named list whose elements are
  themselves named lists of data frames.

- strDir:

  `character` Directory to write into. Created if absent.

- strFormat:

  `character` `"parquet"` (default) or `"csv"`.

## Value

`character` Paths written, invisibly.

## Details

`parquet` is the default: `input` grows quickly and Posit Connect
deployments of ctasapp read parquet from `embedded:`. `csv` is offered
because the dashboard's upload tab accepts it and it needs no extra
dependency.

Empty frames are skipped (an empty `untransformed` is normal - only some
`Input_*()` functions record original values). The function errors if
`lReporting` contains no writable frames, so a mis-shaped input never
silently produces an empty output directory.

## Examples

``` r
if (FALSE) { # \dontrun{
Write_ctasapp(lReporting, tempdir())
} # }
```
