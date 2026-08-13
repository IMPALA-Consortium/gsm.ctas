# Filter a domain to the visits of interest

Applied before any CTAS timeseries is constructed. Both patterns are
deliberately parameterised: sponsors encode scheduled visits differently
(e.g. `"^SCHED_VISIT_"`), so the defaults must stay permissive and any
sponsor-specific convention must be supplied through the workflow YAML
rather than baked into the mapping layer.

## Usage

``` r
FilterVisits(
  dfInput,
  strVisitCol = "VISIT",
  strVisitPattern = NULL,
  strExcludePattern = "unsch"
)
```

## Arguments

- dfInput:

  `data.frame` Containing the visit column.

- strVisitCol:

  `character` Name of the visit column.

- strVisitPattern:

  `character` Regular expression that a visit must match to be retained.
  `NULL` (default) keeps all visits.

- strExcludePattern:

  `character` Regular expression whose matches are dropped. Matched
  case-insensitively. Default `"unsch"` removes unscheduled visits.
  `NULL` disables the exclusion.

## Value

`data.frame` A filtered copy of `dfInput`.
