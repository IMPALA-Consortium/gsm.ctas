# Assemble the CTAS `data` frame from a standardised working frame

Assemble the CTAS `data` frame from a standardised working frame

## Usage

``` r
BuildCTASData(dfWork)
```

## Arguments

- dfWork:

  `data.frame` With `subject_id`, `parameter_id`, `timepoint_1_name`,
  `timepoint_rank` and `result`.

## Value

`data.frame` in the CTAS `data` schema, with contiguous ranks.
