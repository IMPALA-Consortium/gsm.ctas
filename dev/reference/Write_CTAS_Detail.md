# Write the CTAS detail object to files `ctasapp` can load

`ctasapp` reads flat files rather than R objects, so the handoff is a
directory of `results` / `input` / `untransformed` files - the same
names its upload tab and its `embedded:` config block expect.

## Usage

``` r
Write_CTAS_Detail(lDetail, strPath, strFormat = "csv")
```

## Arguments

- lDetail:

  `list` Result of [`Combine_CTAS_Detail()`](Combine_CTAS_Detail.md).

- strPath:

  `character` Directory to write into. Created if absent.

- strFormat:

  `character` `"csv"` or `"parquet"`.

## Value

`character` Paths written, invisibly.

## Details

CSV is the default because it needs no extra dependency and is what the
dashboard's upload tab accepts. Use `strFormat = "parquet"` for a real
study: `Input` holds one row per subject x parameter x timepoint and
becomes large quickly, and a Posit Connect deployment reads parquet from
`embedded:`.

`Untransformed` is written only when it has rows, matching the
dashboard's treatment of it as optional.

## Examples

``` r
if (FALSE) { # \dontrun{
Write_CTAS_Detail(lDetail, tempdir())
} # }
```
