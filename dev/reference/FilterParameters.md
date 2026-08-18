# Restrict CTAS site scores to one family of parameters

Filtering is a no-op when no selector is given, so single-domain studies
need neither the category columns nor `parameter_id`.

## Usage

``` r
FilterParameters(
  dfSiteScores,
  strDomain = NULL,
  strTransformation = NULL,
  strParameterPattern = NULL
)
```

## Arguments

- dfSiteScores:

  `data.frame` CTAS site scores.

- strDomain:

  `character` `parameter_category_1` to keep, or `NULL`.

- strTransformation:

  `character` `parameter_category_3` to keep, or `NULL`.

- strParameterPattern:

  `character` Regular expression matched against `parameter_id`, or
  `NULL`.

## Value

`data.frame` A filtered copy of `dfSiteScores`.

## Details

The category pair is the intended selector. `strDomain` and
`strTransformation` must be supplied together: `parameter_category_3` is
`"numeric"` for every plain numeric domain, so on its own it cannot
separate vital signs from ECG, and `parameter_category_1` is `"Labs"`
for both lab views. Neither field identifies a family alone.
`strParameterPattern` remains available for scores that lack the
categories.

A selector that matches nothing is an error rather than an empty result:
silently summarising zero timeseries would present every site as
unevaluated, which is indistinguishable from a genuinely empty domain.
