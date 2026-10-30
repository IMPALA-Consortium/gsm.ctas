# Standardise an EDC query frame into the CTAS + ctasapp vocabulary

Mirrors [`Standardize_Domain()`](Standardize_Domain.md) for query
records. Renames the raw query columns into the shared CTAS long-format
vocabulary (`subject_id`, `parameter_id`, `parameter_category_1/2`,
`timepoint_1_name`) and inner-joins the standardised subject metadata to
drop queries whose subject isn't in `dfSubjects`. All query-specific
columns are preserved unchanged so the frame stays upload-ready for the
[ctasapp](https://github.com/IMPALA-Consortium/ctasapp) `queries` table.

## Usage

``` r
Standardize_Queries(dfQueries, dfSubjects, dfInput = NULL)
```

## Arguments

- dfQueries:

  `data.frame` Raw queries frame with the 15-column ctasapp contract
  (`study`, `domain`, `field`, `subject_id`, `visit`, `parameter_id`,
  `query_text`, `query_answer`, `query_status`, `query_type`,
  `data_change`, `value_first_entry`, `value_at_query_open`,
  `value_at_query_close`, `value_now`).

- dfSubjects:

  `data.frame` Standardised subject table with `studyid` and
  `subject_id`.

- dfInput:

  `data.frame` Optional bound CTAS input frame (typically
  `Reporting_Input`) providing the
  `(parameter_category_2, parameter_id)` mapping used to fan out queries
  onto the transformed CTAS parameter ids. When `NULL`, `parameter_id`
  is left at the raw field code.

## Value

`data.frame` with CTAS-vocabulary key columns (`subject_id`,
`parameter_id`, `parameter_category_1`, `parameter_category_2`,
`timepoint_1_name`) and every original query column preserved.

## Details

`parameter_category_1` is stamped by mapping the raw `domain` column
(`"LB"`, `"VS"`, `"EG"`, `"RS"`) onto the same human-readable labels the
metric YAMLs pass to [`Standardize_Domain()`](Standardize_Domain.md)
(`"Labs"`, `"Vital Signs"`, `"ECG"`, `"Disease Response"`). Any
unrecognised domain is passed through verbatim.

When `dfInput` is supplied, each raw `parameter_id` (a field-level test
code such as `"AST"`) is fanned out into the transformed CTAS ids
present in the reporting input for the same `parameter_category_2` (e.g.
`"RANGE_AST"`, `"MISS_AST"`). This is required for the ctasapp
`query_table` and timeseries overlay, whose joins use the transformed
`parameter_id`. Queries whose field never appears in `dfInput` are
dropped. `site` / `country` / `studyid` are not written to the output –
ctasapp re-joins `site` onto queries from the input frame and a
duplicate column would collide on `dplyr::left_join(by = "subject_id")`.

## Examples

``` r
Standardize_Queries(
  dfQueries = data.frame(
    study = "A", domain = "LB", field = "ALT",
    subject_id = "S1", visit = "WEEK 2",
    parameter_id = "ALT",
    query_text = "verify", query_answer = NA_character_,
    query_status = "Open", query_type = "Monitor",
    data_change = FALSE,
    value_first_entry = "42", value_at_query_open = "42",
    value_at_query_close = "42", value_now = "42"
  ),
  dfSubjects = data.frame(
    studyid = "A", subject_id = "S1", site = "701", country = "USA"
  )
)
#>   study domain field subject_id  visit parameter_id query_text query_answer
#> 1     A     LB   ALT         S1 WEEK 2          ALT     verify         <NA>
#>   query_status query_type data_change value_first_entry value_at_query_open
#> 1         Open    Monitor       FALSE                42                  42
#>   value_at_query_close value_now timepoint_1_name parameter_category_2
#> 1                   42        42           WEEK 2                  ALT
#>   parameter_category_1
#> 1                 Labs
```
