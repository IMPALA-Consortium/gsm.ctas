# Assemble the timeseries-level detail object for `ctasapp` drill-down

[`Summarize_CTAS()`](Summarize_CTAS.md) collapses many timeseries into
one row per group, which is what the gsm report needs and exactly what a
reviewer investigating a flag does not: once a site is flagged, the next
question is *which* measurement caused it. That question is answered by
the `ctasapp` dashboard, so this function preserves the join keys the
aggregation discards - `timeseries_id`, `parameter_id` and `feature` -
in the shape `ctasapp` reads.

## Usage

``` r
Combine_CTAS_Detail(dfScores, lInput, strStudyID = NULL)
```

## Arguments

- dfScores:

  `data.frame` Result of
  [`Combine_CTAS_Scores()`](Combine_CTAS_Scores.md).

- lInput:

  `list` Result of [`Combine_CTAS_Input()`](Combine_CTAS_Input.md), the
  input to the same CTAS run.

- strStudyID:

  `character` Optional study identifier.

## Value

`list` with elements `Results`, `Input` and `Untransformed`.

## Details

The division of labour is deliberate: the gsm report performs signal
detection, `ctasapp` performs signal investigation. This is a *parallel*
output of the same CTAS run, not a stage of the gsm pipeline - nothing
downstream consumes it, and `ctasapp` does not consume the gsm reporting
layer.

Three frames are returned, matching the files `ctasapp` accepts:

- `Results` - one row per timeseries x feature x group, carrying `site`,
  `timeseries_id`, `parameter_id`, `feature` and
  `fdr_corrected_pvalue_logp`. This is
  [`Combine_CTAS_Scores()`](Combine_CTAS_Scores.md) output unchanged,
  since that already satisfies the contract.

- `Input` - the CTAS `data` frame joined to `subjects` and `parameters`,
  so the dashboard can plot the underlying series with site and
  parameter labels.

- `Untransformed` - the pre-transformation values recorded by the
  `Input_*()` functions, letting the dashboard show a lab result in its
  original units alongside the range-normalised value actually analysed.
  Empty when no mapped domain records them.

`strStudyID` is optional and adds a `study` column to `Results` and
`Input`; `ctasapp` uses it to hold several studies in one upload.

## See also

[`Write_CTAS_Detail()`](Write_CTAS_Detail.md), which writes these frames
to disk in the layout `ctasapp` expects.

## Examples

``` r
lInput <- Combine_CTAS_Input(
  Input_Numeric(data.frame(
    USUBJID = "S1", VSTESTCD = "SYSBP", VSTEST = "Systolic Blood Pressure",
    VISIT = "WEEK 2", VISITNUM = 3, VSSTRESN = 120
  )),
  dfSubjects = Input_Subjects(data.frame(
    USUBJID = "S1", SITEID = "701", COUNTRY = "USA"
  ))
)
dfScores <- data.frame(
  timeseries_id = "ts1", site = "701", feature = "average",
  parameter_id = "VS_SYSBP", fdr_corrected_pvalue_logp = 1.2
)
Combine_CTAS_Detail(dfScores, lInput)
#> $Results
#>   timeseries_id site feature parameter_id fdr_corrected_pvalue_logp
#> 1           ts1  701 average     VS_SYSBP                       1.2
#> 
#> $Input
#>   subject_id parameter_id timepoint_1_name timepoint_2_name timepoint_rank
#> 1         S1     VS_SYSBP           WEEK 2             <NA>              1
#>   result baseline site country region                       parameter_name
#> 1    120       NA  701     USA   <NA> Vital Signs: Systolic Blood Pressure
#>   parameter_category_1 parameter_category_2 parameter_category_3
#> 1          Vital Signs             VS_SYSBP              numeric
#> 
#> $Untransformed
#>   subject_id parameter_category_2 timepoint_1_name original_value lower upper
#> 1         S1             VS_SYSBP           WEEK 2            120    NA    NA
#>   original_category
#> 1              <NA>
#> 
```
