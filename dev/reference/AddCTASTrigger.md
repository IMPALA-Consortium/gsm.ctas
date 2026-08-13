# Classify CTAS timeseries scores into trigger categories

Classifies each timeseries score against the two trigger cut points.

## Usage

``` r
AddCTASTrigger(dfSiteScores, dHigh = 2.326, dLow = 0.842)
```

## Arguments

- dfSiteScores:

  `data.frame` CTAS site scores.

- dHigh:

  `numeric` "Further Evaluation" threshold.

- dLow:

  `numeric` "Watch List" threshold.

## Value

`dfSiteScores` with an added `Trigger` column.
