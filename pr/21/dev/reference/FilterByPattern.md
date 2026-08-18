# Filter site scores by a `parameter_id` pattern

Filter site scores by a `parameter_id` pattern

## Usage

``` r
FilterByPattern(dfSiteScores, strParameterPattern)
```

## Arguments

- dfSiteScores:

  `data.frame` CTAS site scores.

- strParameterPattern:

  `character` Regular expression matched against `parameter_id`, or
  `NULL`.

## Value

`data.frame` A filtered copy of `dfSiteScores`.
