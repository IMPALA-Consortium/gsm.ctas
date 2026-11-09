# Check that required columns are present

Check that required columns are present

## Usage

``` r
AssertColumns(dfInput, vColumns, strLabel = "dfInput")
```

## Arguments

- dfInput:

  `data.frame` Data frame to check.

- vColumns:

  `character` Required column names.

- strLabel:

  `character` Name used in the error message.

## Value

`NULL`, invisibly. Aborts if columns are missing.
