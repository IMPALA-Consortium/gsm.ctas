# Count timeseries per group for a given trigger category

Note that a naive `filter(trigger == trigger)` would compare the column
to itself, the argument being shadowed by the column of the same name,
and so always evaluate to `TRUE`, counting every timeseries rather than
the triggered ones. Here the argument is disambiguated with `.env`.

## Usage

``` r
CountTriggered(
  dfSiteScores,
  strTrigger = "Further Evaluation",
  strGroupCol = "site"
)
```

## Arguments

- dfSiteScores:

  `data.frame` CTAS site scores with a `Trigger` column, as returned by
  [`AddCTASTrigger()`](AddCTASTrigger.md).

- strTrigger:

  `character` Trigger category to count.

- strGroupCol:

  `character` Grouping column.

## Value

`data.frame` with the grouping column and `N`.
