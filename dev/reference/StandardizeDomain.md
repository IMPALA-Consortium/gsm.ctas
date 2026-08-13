# Standardise a domain into the shared CTAS working frame

Renames the sponsor's SDTM columns into the CTAS vocabulary and filters
visits. Shared by all `Input_*()` functions so that column-name
parameterisation is implemented once.

## Usage

``` r
StandardizeDomain(
  dfDomain,
  strSubjectCol = "USUBJID",
  strTestCDCol = "VSTESTCD",
  strTestCol = "VSTEST",
  strValueCol = "VSSTRESN",
  strVisitCol = "VISIT",
  strVisitNumCol = "VISITNUM",
  strVisitPattern = NULL,
  strExcludePattern = "unsch"
)
```

## Arguments

- dfDomain:

  `data.frame` An SDTM domain.

- strSubjectCol:

  `character` Subject identifier column.

- strTestCDCol:

  `character` Short test-code column.

- strTestCol:

  `character` Long test-name column. Falls back to `strTestCDCol` when
  `NULL`.

- strValueCol:

  `character` Result column.

- strVisitCol:

  `character` Name of the visit column.

- strVisitNumCol:

  `character` Numeric visit-order column.

- strVisitPattern:

  `character` Regular expression that a visit must match to be retained.
  `NULL` (default) keeps all visits.

- strExcludePattern:

  `character` Regular expression whose matches are dropped. Matched
  case-insensitively. Default `"unsch"` removes unscheduled visits.
  `NULL` disables the exclusion.

## Value

`data.frame` with columns `subject_id`, `TestCD`, `TestName`,
`timepoint_1_name`, `timepoint_rank` and `Value`.
