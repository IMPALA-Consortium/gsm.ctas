# Map a subject-level domain to the CTAS `subjects` frame

CTAS requires one row per subject carrying the grouping variables it
uses as reference groups: `site`, `country` and `region`.

## Usage

``` r
Input_Subjects(
  dfDM,
  strSubjectCol = "USUBJID",
  strSiteCol = "SITEID",
  strCountryCol = "COUNTRY",
  strRegionCol = NULL,
  fnCountry = NULL
)
```

## Arguments

- dfDM:

  `data.frame` SDTM DM (or any subject-level domain).

- strSubjectCol:

  `character` Subject identifier column.

- strSiteCol:

  `character` Site identifier column.

- strCountryCol:

  `character` Country column. `NULL` if unavailable, in which case
  `country` is derived by `fnCountry`.

- strRegionCol:

  `character` Region column. `NULL` (default) yields `NA`.

- fnCountry:

  `function` Optional. Takes the site vector and returns a country
  vector. Overrides `strCountryCol` when supplied.

## Value

`data.frame` with one distinct row per subject and columns `subject_id`,
`site`, `country`, `region`.

## Details

The country derivation is parameterised rather than hard-coded. PDQRM
derives country from characters 11-13 of the site identifier; that is a
sponsor convention, not a property of SDTM, so it must be supplied by
the caller via `fnCountry` instead of being inherited.

## Examples

``` r
Input_Subjects(data.frame(
  USUBJID = c("S1", "S2"),
  SITEID = c("701", "702"),
  COUNTRY = c("USA", "USA")
))
#>   subject_id site country region
#> 1         S1  701     USA   <NA>
#> 2         S2  702     USA   <NA>
```
