# SDTM VS (Vital Signs) domain

Verbatim copy of
[pharmaversesdtm::vs](https://pharmaverse.github.io/pharmaversesdtm/reference/vs.html).

## Usage

``` r
vs
```

## Format

A `data.frame` with one row per vital-signs measurement and the standard
SDTM VS columns (`STUDYID`, `USUBJID`, `VSTESTCD`, `VSTEST`, `VSSTRESN`,
`VISIT`, `VISITNUM`, ...).

## Source

[pharmaversesdtm::vs](https://pharmaverse.github.io/pharmaversesdtm/reference/vs.html)

## Examples

``` r
data(vs)
head(vs)
#> # A tibble: 6 × 24
#>   STUDYID   DOMAIN USUBJID VSSEQ VSTESTCD VSTEST VSPOS VSORRES VSORRESU VSSTRESC
#>   <chr>     <chr>  <chr>   <dbl> <chr>    <chr>  <chr> <chr>   <chr>    <chr>   
#> 1 CDISCPIL… VS     01-701…     1 DIABP    Diast… SUPI… 64      mmHg     64      
#> 2 CDISCPIL… VS     01-701…     2 DIABP    Diast… STAN… 83      mmHg     83      
#> 3 CDISCPIL… VS     01-701…     3 DIABP    Diast… STAN… 57      mmHg     57      
#> 4 CDISCPIL… VS     01-701…     4 DIABP    Diast… SUPI… 68      mmHg     68      
#> 5 CDISCPIL… VS     01-701…     5 DIABP    Diast… STAN… 59      mmHg     59      
#> 6 CDISCPIL… VS     01-701…     6 DIABP    Diast… STAN… 71      mmHg     71      
#> # ℹ 14 more variables: VSSTRESN <dbl>, VSSTRESU <chr>, VSSTAT <chr>,
#> #   VSLOC <chr>, VSBLFL <chr>, VISITNUM <dbl>, VISIT <chr>, VISITDY <dbl>,
#> #   VSDTC <chr>, VSDY <dbl>, VSTPT <chr>, VSTPTNUM <dbl>, VSELTM <chr>,
#> #   VSTPTREF <chr>
```
