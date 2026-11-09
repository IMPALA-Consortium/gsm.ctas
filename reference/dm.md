# SDTM DM (Demographics) domain

Verbatim copy of
[pharmaversesdtm::dm](https://pharmaverse.github.io/pharmaversesdtm/reference/dm.html)
shipped with the package so the mapping workflow (`Raw_DM`) can run
without `pharmaversesdtm` at runtime.

## Usage

``` r
dm
```

## Format

A `data.frame` with one row per subject and the standard SDTM DM columns
(`STUDYID`, `USUBJID`, `SITEID`, `COUNTRY`, ...).

## Source

[pharmaversesdtm::dm](https://pharmaverse.github.io/pharmaversesdtm/reference/dm.html)

## Examples

``` r
data(dm)
head(dm)
#> # A tibble: 6 × 28
#>   STUDYID      DOMAIN USUBJID   SUBJID RFSTDTC RFENDTC RFXSTDTC RFXENDTC RFICDTC
#>   <chr>        <chr>  <chr>     <chr>  <chr>   <chr>   <chr>    <chr>    <chr>  
#> 1 CDISCPILOT01 DM     01-701-1… 1015   2014-0… 2014-0… 2014-01… 2014-07… NA     
#> 2 CDISCPILOT01 DM     01-701-1… 1023   2012-0… 2012-0… 2012-08… 2012-09… NA     
#> 3 CDISCPILOT01 DM     01-701-1… 1028   2013-0… 2014-0… 2013-07… 2014-01… NA     
#> 4 CDISCPILOT01 DM     01-701-1… 1033   2014-0… 2014-0… 2014-03… 2014-03… NA     
#> 5 CDISCPILOT01 DM     01-701-1… 1034   2014-0… 2014-1… 2014-07… 2014-12… NA     
#> 6 CDISCPILOT01 DM     01-701-1… 1047   2013-0… 2013-0… 2013-02… 2013-03… NA     
#> # ℹ 19 more variables: RFPENDTC <chr>, DTHDTC <chr>, DTHFL <chr>, SITEID <chr>,
#> #   BRTHDTC <chr>, AGE <dbl>, AGEU <chr>, SEX <chr>, RACE <chr>, ETHNIC <chr>,
#> #   ARMCD <chr>, ARM <chr>, ACTARMCD <chr>, ACTARM <chr>, COUNTRY <chr>,
#> #   DMDTC <chr>, DMDY <dbl>, ARMNRS <chr>, ACTARMUD <chr>
```
