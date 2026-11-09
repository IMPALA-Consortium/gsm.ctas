# One-hot encode a categorical variable

Expands a categorical vector into a long data frame with one row per
observation per observed level, so that each level becomes its own
binary CTAS timeseries. `NA` values are dropped rather than encoded as a
level.

## Usage

``` r
Prepare_Categorical(vValue, strPrefix = "var")
```

## Arguments

- vValue:

  `character` Categorical values.

- strPrefix:

  `character` Prefix used to build level labels, typically the source
  parameter name.

## Value

`data.frame` with columns `RowIndex` (`integer` row index of the source
observation), `Level` (`character` label of the form
`"{strPrefix}={value}"`) and `Encoded` (`integer`, 1 if the observation
matches the level, else 0).
