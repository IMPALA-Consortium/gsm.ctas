# Illustrative EDC query records

Synthetic clinical-query records generated deterministically from the
bundled SDTM domains (`dm`, `lb`, `vs`, `eg`, `rs`).

## Usage

``` r
queries
```

## Format

A `data.frame` with 15 columns: `study`, `domain`, `field`,
`subject_id`, `visit`, `parameter_id`, `query_text`, `query_answer`,
`query_status`, `query_type`, `data_change` (logical),
`value_first_entry`, `value_at_query_open`, `value_at_query_close`,
`value_now`.

## Source

`data-raw/queries.R`

## Examples

``` r
data(queries)
head(queries)
#>          study domain field  subject_id             visit parameter_id
#> 1 CDISCPILOT01     LB   LYM 01-716-1167           WEEK 26          LYM
#> 2 CDISCPILOT01     LB   ALB 01-718-1172            WEEK 6          ALB
#> 3 CDISCPILOT01     LB   AST 01-701-1148           WEEK 20          AST
#> 4 CDISCPILOT01     LB   HGB 01-709-1020           WEEK 12          HGB
#> 5 CDISCPILOT01     EG    RR 01-703-1335 AMBUL ECG REMOVAL           RR
#> 6 CDISCPILOT01     EG    RR 01-709-1029           WEEK 12           RR
#>                                              query_text
#> 1               Please confirm the unit of measurement.
#> 2               Please confirm the unit of measurement.
#> 3         Value deviates from protocol-specified range.
#> 4         Value deviates from protocol-specified range.
#> 5         Value deviates from protocol-specified range.
#> 6 Value appears outside expected range, please confirm.
#>                                query_answer query_status      query_type
#> 1             Confirmed correct per source.     Answered         Monitor
#> 2                                      <NA>         Open Data Management
#> 3 Original value confirmed by investigator.     Answered         Monitor
#> 4 Original value confirmed by investigator.       Closed Data Management
#> 5    Updated after reviewing patient chart.       Closed Data Management
#> 6   Value corrected as per source document.       Closed Data Management
#>   data_change value_first_entry value_at_query_open value_at_query_close
#> 1       FALSE              1.79                1.79                 1.79
#> 2       FALSE                40                  40                   40
#> 3       FALSE                26                  26                   26
#> 4        TRUE            6.7487              6.7487              8.50222
#> 5        TRUE          673.0671            673.0671                  548
#> 6       FALSE               668                 668                  668
#>   value_now
#> 1      1.79
#> 2        40
#> 3        26
#> 4   8.50222
#> 5       548
#> 6       668
```
