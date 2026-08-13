# Map a findings domain to a missingness-ratio CTAS input

Turns data *completeness* into a timeseries: for each subject and test,
the running proportion of missing results over visits
([`Prepare_MissingRatio()`](Prepare_MissingRatio.md)). This lets CTAS
flag sites whose reporting completeness deviates from the study, which
the value-based inputs cannot see because they drop `NA` rows.

## Usage

``` r
Input_Missing(
  dfDomain,
  strSubjectCol = "USUBJID",
  strTestCDCol = "LBTESTCD",
  strTestCol = "LBTEST",
  strValueCol = "LBSTRESN",
  strVisitCol = "VISIT",
  strVisitNumCol = "VISITNUM",
  strVisitPattern = NULL,
  strExcludePattern = "unsch",
  strCategory = "Labs",
  strPrefix = "LB_MISS"
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

  `character` Result column.

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

## Details

Unlike the other `Input_*()` functions, rows with missing results are
retained - they are the signal.

## Examples

``` r
Input_Missing(data.frame(
  USUBJID = c("S1", "S1"),
  LBTESTCD = c("ALT", "ALT"),
  LBTEST = c("Alanine Aminotransferase", "Alanine Aminotransferase"),
  VISIT = c("WEEK 2", "WEEK 4"),
  VISITNUM = c(3, 4),
  LBSTRESN = c(20, NA)
))
#> $data
#>   subject_id parameter_id timepoint_1_name timepoint_2_name timepoint_rank
#> 1         S1  LB_MISS_ALT           WEEK 2             <NA>              1
#> 2         S1  LB_MISS_ALT           WEEK 4             <NA>              2
#>   result baseline
#> 1    0.0       NA
#> 2    0.5       NA
#> 
#> $parameters
#>   parameter_id                          parameter_name parameter_category_1
#> 1  LB_MISS_ALT Ratio Missing: Alanine Aminotransferase                 Labs
#>   parameter_category_2 parameter_category_3
#> 1          LB_MISS_ALT        ratio_missing
#> 
#> $untransformed
#>   subject_id parameter_category_2 timepoint_1_name original_value lower upper
#> 1         S1          LB_MISS_ALT           WEEK 2             20    NA    NA
#> 2         S1          LB_MISS_ALT           WEEK 4             NA    NA    NA
#>   original_category
#> 1              <NA>
#> 2              <NA>
#> 
```
