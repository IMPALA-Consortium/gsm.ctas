# Combine domain inputs into the five CTAS input frames

Binds any number of `Input_*()` results together with a subjects frame
and emits exactly the five objects
[`ctas::process_a_study()`](https://rdrr.io/pkg/ctas/man/process_a_study.html)
consumes: `data`, `subjects`, `parameters`, `custom_timeseries` and
`custom_reference_groups`.

## Usage

``` r
Combine_CTAS_Input(..., dfSubjects)
```

## Arguments

- ...:

  `list` One or more `Input_*()` results, each with `data`, `parameters`
  and optionally `untransformed`.

- dfSubjects:

  `data.frame` Result of [`Input_Subjects()`](Input_Subjects.md).

## Value

`list` with elements `data`, `subjects`, `parameters`,
`custom_timeseries`, `custom_reference_groups` and `untransformed`.

## Details

The per-parameter tuning columns CTAS expects (`time_point_count_min`,
`subject_count_min`, ...) are added as `NA`, which instructs CTAS to
fall back on the study-level defaults passed to `process_a_study()`.
Setting them per parameter is a deliberate later decision, not something
the mapping layer should guess.

The combined `untransformed` frame is retained but is *not* CTAS input;
it is the detail object used for drill-down.

## Examples

``` r
Combine_CTAS_Input(
  Input_Numeric(data.frame(
    USUBJID = "S1", VSTESTCD = "SYSBP", VSTEST = "Systolic Blood Pressure",
    VISIT = "WEEK 2", VISITNUM = 3, VSSTRESN = 120
  )),
  dfSubjects = Input_Subjects(data.frame(
    USUBJID = "S1", SITEID = "701", COUNTRY = "USA"
  ))
)
#> $data
#>   subject_id parameter_id timepoint_1_name timepoint_2_name timepoint_rank
#> 1         S1     VS_SYSBP           WEEK 2             <NA>              1
#>   result baseline
#> 1    120       NA
#> 
#> $subjects
#>   subject_id site country region
#> 1         S1  701     USA   <NA>
#> 
#> $parameters
#>   parameter_id                       parameter_name parameter_category_1
#> 1     VS_SYSBP Vital Signs: Systolic Blood Pressure          Vital Signs
#>   parameter_category_2 parameter_category_3 time_point_count_min
#> 1             VS_SYSBP              numeric                   NA
#>   subject_count_min max_share_missing generate_change_from_baseline
#> 1                NA                NA                            NA
#>   timeseries_features_to_calculate use_only_custom_timeseries
#> 1                             <NA>                         NA
#> 
#> $custom_timeseries
#> [1] timeseries_id   parameter_id    timepoint_combo
#> <0 rows> (or 0-length row.names)
#> 
#> $custom_reference_groups
#> [1] parameter_id feature      ref_group   
#> <0 rows> (or 0-length row.names)
#> 
#> $untransformed
#>   subject_id parameter_category_2 timepoint_1_name original_value lower upper
#> 1         S1             VS_SYSBP           WEEK 2            120    NA    NA
#>   original_category
#> 1              <NA>
#> 
```
