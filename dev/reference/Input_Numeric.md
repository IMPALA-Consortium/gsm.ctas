# Map a numeric findings domain to CTAS input

Produces one CTAS timeseries per subject and test code from a plain
numeric findings domain such as VS. Values are used as-is; use
[`Input_Range()`](Input_Range.md) when reference ranges are available
and values must be made comparable across tests.

## Usage

``` r
Input_Numeric(
  dfDomain,
  strSubjectCol = "USUBJID",
  strTestCDCol = "VSTESTCD",
  strTestCol = "VSTEST",
  strValueCol = "VSSTRESN",
  strVisitCol = "VISIT",
  strVisitNumCol = "VISITNUM",
  strVisitPattern = NULL,
  strExcludePattern = "unsch",
  strCategory = "Vital Signs",
  strPrefix = "VS"
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

`list` with elements `data`, `parameters` and `untransformed`, ready to
be passed to [`Combine_CTAS_Input()`](Combine_CTAS_Input.md).

## Details

The function is named for the *data type*, not the SDTM domain, so the
same code serves VS, EG or any other numeric findings domain.
Domain-specific knowledge lives in the column arguments, supplied from
the workflow YAML.

## Examples

``` r
Input_Numeric(data.frame(
  USUBJID = c("S1", "S1"),
  VSTESTCD = c("SYSBP", "SYSBP"),
  VSTEST = c("Systolic Blood Pressure", "Systolic Blood Pressure"),
  VISIT = c("WEEK 2", "WEEK 4"),
  VISITNUM = c(3, 4),
  VSSTRESN = c(120, 124)
))
#> $data
#>   subject_id parameter_id timepoint_1_name timepoint_2_name timepoint_rank
#> 1         S1     VS_SYSBP           WEEK 2             <NA>              1
#> 2         S1     VS_SYSBP           WEEK 4             <NA>              2
#>   result baseline
#> 1    120       NA
#> 2    124       NA
#> 
#> $parameters
#>   parameter_id                       parameter_name parameter_category_1
#> 1     VS_SYSBP Vital Signs: Systolic Blood Pressure          Vital Signs
#>   parameter_category_2 parameter_category_3
#> 1             VS_SYSBP              numeric
#> 
#> $untransformed
#>   subject_id parameter_category_2 timepoint_1_name original_value lower upper
#> 1         S1             VS_SYSBP           WEEK 2            120    NA    NA
#> 2         S1             VS_SYSBP           WEEK 4            124    NA    NA
#>   original_category
#> 1              <NA>
#> 2              <NA>
#> 
```
