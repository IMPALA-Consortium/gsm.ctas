# SDTM LB (Laboratory) domain

Verbatim copy of
[pharmaversesdtm::lb](https://pharmaverse.github.io/pharmaversesdtm/reference/lb.html).

## Usage

``` r
lb
```

## Format

A `data.frame` with one row per lab measurement and the standard SDTM LB
columns (`STUDYID`, `USUBJID`, `LBTESTCD`, `LBTEST`, `LBSTRESN`,
`VISIT`, `VISITNUM`, `LBSTNRLO`, `LBSTNRHI`, ...).

## Source

[pharmaversesdtm::lb](https://pharmaverse.github.io/pharmaversesdtm/reference/lb.html)

## Examples

``` r
data(lb)
head(lb)
#> # A tibble: 6 × 23
#>   STUDYID   DOMAIN USUBJID LBSEQ LBTESTCD LBTEST LBCAT LBORRES LBORRESU LBORNRLO
#>   <chr>     <chr>  <chr>   <dbl> <chr>    <chr>  <chr> <chr>   <chr>    <chr>   
#> 1 CDISCPIL… LB     01-701…     1 ALB      Album… CHEM… 3.8     g/dL     3.3     
#> 2 CDISCPIL… LB     01-701…    39 ALB      Album… CHEM… 3.9     g/dL     3.3     
#> 3 CDISCPIL… LB     01-701…    74 ALB      Album… CHEM… 3.8     g/dL     3.3     
#> 4 CDISCPIL… LB     01-701…   104 ALB      Album… CHEM… 3.7     g/dL     3.3     
#> 5 CDISCPIL… LB     01-701…   134 ALB      Album… CHEM… 3.8     g/dL     3.3     
#> 6 CDISCPIL… LB     01-701…   164 ALB      Album… CHEM… 3.8     g/dL     3.3     
#> # ℹ 13 more variables: LBORNRHI <chr>, LBSTRESC <chr>, LBSTRESN <dbl>,
#> #   LBSTRESU <chr>, LBSTNRLO <dbl>, LBSTNRHI <dbl>, LBNRIND <chr>,
#> #   LBBLFL <chr>, VISITNUM <dbl>, VISIT <chr>, VISITDY <dbl>, LBDTC <chr>,
#> #   LBDY <dbl>
```
