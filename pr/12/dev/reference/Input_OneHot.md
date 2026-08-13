# Map a categorical findings domain to CTAS input via one-hot encoding

CTAS operates on numeric timeseries, so a categorical result such as
`RSORRES` is expanded by
[`Prepare_Categorical()`](Prepare_Categorical.md) into one binary
timeseries per observed level. Each level becomes its own
`parameter_id`, while all levels share a `parameter_category_2` so they
stay grouped for review.

## Usage

``` r
Input_OneHot(
  dfDomain,
  strSubjectCol = "USUBJID",
  strTestCDCol = "RSTESTCD",
  strTestCol = "RSTEST",
  strValueCol = "RSORRES",
  strVisitCol = "VISIT",
  strVisitNumCol = "VISITNUM",
  strVisitPattern = NULL,
  strExcludePattern = "unsch",
  strCategory = "Response",
  strPrefix = "RS"
)
```

## Arguments

- dfDomain:

  `data.frame` An SDTM domain.

- strSubjectCol:

  `character` Subject identifier column.

- strTestCDCol:

  `character` Short test-code column.

- strTestCol:

  `character` Long test-name column. Falls back to `strTestCDCol` when
  `NULL`.

- strValueCol:

  `character` Categorical result column.

- strVisitCol:

  `character` Name of the visit column.

- strVisitNumCol:

  `character` Numeric visit-order column.

- strVisitPattern:

  `character` Regular expression that a visit must match to be retained.
  `NULL` (default) keeps all visits.

- strExcludePattern:

  `character` Regular expression whose matches are dropped. Matched
  case-insensitively. Default `"unsch"` removes unscheduled visits.
  `NULL` disables the exclusion.

- strCategory:

  `character` Value written to `parameter_category_1`, used as the
  display grouping in downstream tools.

- strPrefix:

  `character` Prefix for the generated `parameter_id`.

## Value

`list` with elements `data`, `parameters` and `untransformed`.

## Examples

``` r
Input_OneHot(data.frame(
  USUBJID = c("S1", "S1"),
  RSTESTCD = c("OVRLRESP", "OVRLRESP"),
  RSTEST = c("Overall Response", "Overall Response"),
  VISIT = c("WEEK 2", "WEEK 4"),
  VISITNUM = c(3, 4),
  RSORRES = c("CR", "PR")
))
#> $data
#>   subject_id   parameter_id timepoint_1_name timepoint_2_name timepoint_rank
#> 1         S1 RS_OVRLRESP=CR           WEEK 2             <NA>              1
#> 2         S1 RS_OVRLRESP=CR           WEEK 4             <NA>              2
#> 3         S1 RS_OVRLRESP=PR           WEEK 2             <NA>              1
#> 4         S1 RS_OVRLRESP=PR           WEEK 4             <NA>              2
#>   result baseline
#> 1      1       NA
#> 2      0       NA
#> 3      0       NA
#> 4      1       NA
#> 
#> $parameters
#>     parameter_id        parameter_name parameter_category_1
#> 1 RS_OVRLRESP=CR Overall Response = CR             Response
#> 2 RS_OVRLRESP=PR Overall Response = PR             Response
#>   parameter_category_2 parameter_category_3
#> 1          RS_OVRLRESP          categorical
#> 2          RS_OVRLRESP          categorical
#> 
#> $untransformed
#>   subject_id parameter_category_2 timepoint_1_name original_value lower upper
#> 1         S1          RS_OVRLRESP           WEEK 2             NA    NA    NA
#> 2         S1          RS_OVRLRESP           WEEK 4             NA    NA    NA
#>   original_category
#> 1                CR
#> 2                PR
#> 
```
