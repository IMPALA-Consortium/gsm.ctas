# Validate the CTAS result

`process_a_study()` returns a list of `NULL`s when no timeseries could
be constructed. Turn that into an actionable message rather than letting
it surface as a downstream subsetting failure.

## Usage

``` r
AssertCTASResult(lCTAS)
```

## Arguments

- lCTAS:

  `list` Result of
  [`ctas::process_a_study()`](https://rdrr.io/pkg/ctas/man/process_a_study.html).

## Value

`NULL`, invisibly. Aborts when the result is degenerate.
