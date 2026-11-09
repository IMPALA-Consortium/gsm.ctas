# Illustrative Protocol Deviation records

Synthetic protocol-deviation records generated deterministically from
the bundled `dm` dataset. Ports ctasapp's `simulate_pd_data()` (IMPALA-
Consortium/ctasapp, feature branch `19_pd`, now on `main`) so the
shipped frame matches the ctasapp Field Detail Protocol Deviations tab
column contract 1:1.

## Usage

``` r
pd
```

## Format

A `data.frame` with 10 columns: `study`, `site`, `subject_id`, `dv_seq`
(integer), `dv_term`, `dv_decod`, `dv_cat` (severity: `MAJOR`,
`IMPORTANT`, `MINOR`), `dv_scat` (subcategory), `dv_start_date` (Date),
`dv_end_date` (Date).

## Source

`data-raw/pd.R`

## Examples

``` r
data(pd)
head(pd)
#>          study site  subject_id dv_seq
#> 1 CDISCPILOT01  701 01-701-1415      1
#> 2 CDISCPILOT01  701 01-701-1118      2
#> 3 CDISCPILOT01  702 01-702-1082      1
#> 4 CDISCPILOT01  703 01-703-1299      1
#> 5 CDISCPILOT01  704 01-704-1164      1
#> 6 CDISCPILOT01  704 01-704-1241      2
#>                                           dv_term
#> 1 Reconsent not obtained after protocol amendment
#> 2          Consent form version mismatch at visit
#> 3                  Follow-up visit conducted late
#> 4  Subject took prohibited concomitant medication
#> 5                  Follow-up visit conducted late
#> 6                  Follow-up visit conducted late
#>                                          dv_decod    dv_cat
#> 1 Reconsent not obtained after protocol amendment     MAJOR
#> 2          Consent form version mismatch at visit     MAJOR
#> 3                  Follow-up visit conducted late     MINOR
#> 4  Subject took prohibited concomitant medication IMPORTANT
#> 5                  Follow-up visit conducted late     MINOR
#> 6                  Follow-up visit conducted late     MINOR
#>                  dv_scat dv_start_date dv_end_date
#> 1 INFORMED CONSENT ISSUE    2024-07-24  2024-07-24
#> 2 INFORMED CONSENT ISSUE    2024-09-30  2024-10-03
#> 3 VISIT WINDOW DEVIATION    2024-08-30  2024-09-04
#> 4      PROHIBITED CONMED    2023-03-24  2023-03-27
#> 5 VISIT WINDOW DEVIATION    2024-03-11  2024-03-24
#> 6 VISIT WINDOW DEVIATION    2023-03-22  2023-04-03
```
