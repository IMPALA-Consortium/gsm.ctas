# SDTM RS (Disease Response) domain

Verbatim copy of
[pharmaversesdtm::rs_onco](https://pharmaverse.github.io/pharmaversesdtm/reference/rs_onco.html)
renamed to `rs` for consistency with the two-letter SDTM domain
convention used by every other bundled dataset.

## Usage

``` r
rs
```

## Format

A `data.frame` with one row per response assessment and the standard
SDTM RS columns (`STUDYID`, `USUBJID`, `RSTESTCD`, `RSTEST`, `RSORRES`,
`VISIT`, `VISITNUM`, ...).

## Source

[pharmaversesdtm::rs_onco](https://pharmaverse.github.io/pharmaversesdtm/reference/rs_onco.html)

## Examples

``` r
data(rs)
head(rs)
#> # A tibble: 6 × 19
#>   STUDYID   DOMAIN USUBJID RSSEQ RSLNKGRP RSTESTCD RSTEST RSCAT RSORRES RSSTRESC
#>   <chr>     <chr>  <chr>   <int> <chr>    <chr>    <chr>  <chr> <chr>   <chr>   
#> 1 CDISCPIL… RS     01-701…     1 R1-A2    OVRLRESP Overa… RECI… PD      PD      
#> 2 CDISCPIL… RS     01-701…     2 NA       NTRGRESP Non-t… RECI… PD      PD      
#> 3 CDISCPIL… RS     01-701…     3 NA       TRGRESP  Targe… RECI… PR      PR      
#> 4 CDISCPIL… RS     01-701…     4 R2-A2    OVRLRESP Overa… RECI… SD      SD      
#> 5 CDISCPIL… RS     01-701…     5 NA       NTRGRESP Non-t… RECI… NON-CR… NON-CR/…
#> 6 CDISCPIL… RS     01-701…     6 NA       TRGRESP  Targe… RECI… SD      SD      
#> # ℹ 9 more variables: RSSTAT <chr>, RSREASND <chr>, RSEVAL <chr>,
#> #   RSEVALID <chr>, RSACPTFL <chr>, VISITNUM <dbl>, VISIT <chr>, RSDTC <chr>,
#> #   RSDY <dbl>
```
