# Map a numeric findings domain with reference ranges to CTAS input

Like [`Input_Numeric()`](Input_Numeric.md), but normalises each value by
its own reference range via
[`Prepare_Normalize()`](Prepare_Normalize.md), so that tests measured on
different scales become directly comparable. Intended for LB, but
applies to any domain carrying low/high bounds.

## Usage

``` r
Input_Range(
  dfDomain,
  strSubjectCol = "USUBJID",
  strTestCDCol = "LBTESTCD",
  strTestCol = "LBTEST",
  strValueCol = "LBSTRESN",
  strLowCol = "LBSTNRLO",
  strHighCol = "LBSTNRHI",
  strVisitCol = "VISIT",
  strVisitNumCol = "VISITNUM",
  strVisitPattern = NULL,
  strExcludePattern = "unsch",
  strCategory = "Labs",
  strPrefix = "LB_NORM"
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

- strLowCol:

  `character` Lower reference-bound column.

- strHighCol:

  `character` Upper reference-bound column.

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

Rows with an invalid range (missing bound or non-positive width) yield
`NA` and are dropped, since CTAS cannot use them.

## Examples

``` r
Input_Range(data.frame(
  USUBJID = c("S1", "S1"),
  LBTESTCD = c("ALT", "ALT"),
  LBTEST = c("Alanine Aminotransferase", "Alanine Aminotransferase"),
  VISIT = c("WEEK 2", "WEEK 4"),
  VISITNUM = c(3, 4),
  LBSTRESN = c(20, 30),
  LBSTNRLO = c(10, 10),
  LBSTNRHI = c(40, 40)
))
#> $data
#>   subject_id parameter_id timepoint_1_name timepoint_2_name timepoint_rank
#> 1         S1  LB_NORM_ALT           WEEK 2             <NA>              1
#> 2         S1  LB_NORM_ALT           WEEK 4             <NA>              2
#>      result baseline
#> 1 0.3333333       NA
#> 2 0.6666667       NA
#> 
#> $parameters
#>   parameter_id                        parameter_name parameter_category_1
#> 1  LB_NORM_ALT Labs (norm): Alanine Aminotransferase                 Labs
#>   parameter_category_2 parameter_category_3
#> 1          LB_NORM_ALT     range_normalized
#> 
#> $untransformed
#>   subject_id parameter_category_2 timepoint_1_name original_value lower upper
#> 1         S1          LB_NORM_ALT           WEEK 2             20    10    40
#> 2         S1          LB_NORM_ALT           WEEK 4             30    10    40
#>   original_category
#> 1              <NA>
#> 2              <NA>
#> 
```
