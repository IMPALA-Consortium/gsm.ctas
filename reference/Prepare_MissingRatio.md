# Running ratio of missing values over time

For each subject and parameter, computes the cumulative proportion of
missing values in row order: row `k` of a group receives
`sum(is.na(vValue[1:k])) / k`. The result is a timeseries in its own
right, allowing CTAS to detect sites whose data completeness deviates
over time.

## Usage

``` r
Prepare_MissingRatio(vValue, vSubjectID, vParameterID)
```

## Arguments

- vValue:

  `numeric` Observed values, possibly containing `NA`.

- vSubjectID:

  `character` Subject identifiers.

- vParameterID:

  `character` Parameter identifiers.

## Value

`numeric` vector of the same length as `vValue`.

## Details

Rows are assumed to be supplied in chronological order within each
group; the returned vector is aligned to the input row order.
