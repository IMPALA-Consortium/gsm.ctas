# SDTM EG (ECG) domain

Verbatim copy of
[pharmaversesdtm::eg](https://pharmaverse.github.io/pharmaversesdtm/reference/eg.html).

## Usage

``` r
eg
```

## Format

A `data.frame` with one row per ECG measurement and the standard SDTM EG
columns (`STUDYID`, `USUBJID`, `EGTESTCD`, `EGTEST`, `EGSTRESN`,
`VISIT`, `VISITNUM`, ...).

## Source

[pharmaversesdtm::eg](https://pharmaverse.github.io/pharmaversesdtm/reference/eg.html)

## Examples

``` r
data(eg)
head(eg)
#> # A tibble: 6 × 23
#>   STUDYID      DOMAIN USUBJID    EGSEQ EGTESTCD EGTEST EGORRES EGORRESU EGSTRESC
#>   <chr>        <chr>  <chr>      <dbl> <chr>    <chr>  <chr>   <chr>    <chr>   
#> 1 CDISCPILOT01 EG     01-701-10…     1 ECGINT   ECG I… ABNORM… LB       ABNORMAL
#> 2 CDISCPILOT01 EG     01-701-10…     2 ECGINT   ECG I… ABNORM… LB       ABNORMAL
#> 3 CDISCPILOT01 EG     01-701-10…     3 ECGINT   ECG I… ABNORM… LB       ABNORMAL
#> 4 CDISCPILOT01 EG     01-701-10…     4 ECGINT   ECG I… ABNORM… LB       ABNORMAL
#> 5 CDISCPILOT01 EG     01-701-10…     5 ECGINT   ECG I… ABNORM… LB       ABNORMAL
#> 6 CDISCPILOT01 EG     01-701-10…     6 ECGINT   ECG I… ABNORM… LB       ABNORMAL
#> # ℹ 14 more variables: EGSTRESN <dbl>, EGSTRESU <chr>, EGSTAT <chr>,
#> #   EGLOC <chr>, EGBLFL <chr>, VISITNUM <dbl>, VISIT <chr>, VISITDY <dbl>,
#> #   EGDTC <chr>, EGDY <dbl>, EGTPT <chr>, EGTPTNUM <dbl>, EGELTM <chr>,
#> #   EGTPTREF <chr>
```
