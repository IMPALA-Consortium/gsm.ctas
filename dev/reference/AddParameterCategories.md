# Recover the parameter categories CTAS discards

`process_a_study()` consumes `parameters` but returns none of its
category columns, so the only way to label a score with its domain is to
join the input back on.

## Usage

``` r
AddParameterCategories(dfScores, lInput)
```

## Arguments

- dfScores:

  `data.frame` Site scores carrying `parameter_id`.

- lInput:

  `list` Result of [`Combine_CTAS_Input()`](Combine_CTAS_Input.md).

## Value

`data.frame` `dfScores` with the category columns added.
