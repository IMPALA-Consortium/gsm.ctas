# Normalize values by reference range

Computes `(vValue - vLow) / (vHigh - vLow)`, so that values inside the
reference range fall between 0 and 1, below-range values are negative
and above-range values exceed 1. This makes parameters with different
units and scales comparable within a single CTAS timeseries frame.

## Usage

``` r
Prepare_Normalize(vValue, vLow, vHigh)
```

## Arguments

- vValue:

  `numeric` Observed values.

- vLow:

  `numeric` Lower reference bounds.

- vHigh:

  `numeric` Upper reference bounds.

## Value

`numeric` vector of the same length as `vValue`.

## Details

Returns `NA_real_` wherever the range is invalid, i.e. either bound is
missing or the range width is not strictly positive.
