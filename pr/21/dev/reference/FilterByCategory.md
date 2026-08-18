# Filter site scores on the CTAS parameter categories

Filter site scores on the CTAS parameter categories

## Usage

``` r
FilterByCategory(dfSiteScores, strDomain, strTransformation)
```

## Arguments

- dfSiteScores:

  `data.frame` CTAS site scores.

- strDomain:

  `character` `parameter_category_1` to keep, or `NULL`.

- strTransformation:

  `character` `parameter_category_3` to keep, or `NULL`.

## Value

`data.frame` A filtered copy of `dfSiteScores`.
