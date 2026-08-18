# Add an optional study identifier column

Add an optional study identifier column

## Usage

``` r
AddStudyID(dfInput, strStudyID = NULL)
```

## Arguments

- dfInput:

  `data.frame` Frame to label.

- strStudyID:

  `character` Study identifier, or `NULL` to do nothing.

## Value

`data.frame`, with a `study` column when `strStudyID` is given.
