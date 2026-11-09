# Rename an SDTM findings domain into the CTAS long-format vocabulary

The single step that translates SDTM column names into the CTAS +
[ctasapp](https://github.com/IMPALA-Consortium/ctasapp) vocabulary and
joins the standardised subject metadata (`studyid`, `site`, `country`)
onto every row. Downstream `Input_*()` functions consume the resulting
long frame and transform values without needing to know which SDTM
domain fed them.

## Usage

``` r
Standardize_Domain(
  dfDomain,
  dfSubjects,
  strSubjectCol = "USUBJID",
  strTestCDCol,
  strTestCol,
  strValueCol,
  strVisitCol = "VISIT",
  strVisitNumCol = "VISITNUM",
  strLowCol = NULL,
  strHighCol = NULL,
  strCharCol = NULL,
  strCategory,
  strPrefix = ""
)
```

## Arguments

- dfDomain:

  `data.frame` Raw SDTM findings.

- dfSubjects:

  `data.frame` Standardised subject table with `subject_id`, `site`, and
  optionally `studyid`, `country`, `region`.

- strSubjectCol, strTestCDCol, strTestCol, strValueCol, strVisitCol,
  strVisitNumCol:

  `character` SDTM column names to translate.

- strLowCol, strHighCol:

  `character` Reference-bound columns. `NULL` when the source has no
  ranges.

- strCharCol:

  `character` Optional character result column (e.g. `LBSTRESC`). Fills
  `original_category` where `strValueCol` is `NA`, so qualitative
  results stay visible in ctasapp's source data. `NULL` by default.

- strCategory:

  `character` Constant stamped onto `parameter_category_1`.

- strPrefix:

  `character` Optional prefix applied to `parameter_id` (e.g. `"NUM"`
  -\> `"NUM_SYSBP"`). Empty by default; `parameter_category_2` always
  keeps the raw test code so ctasapp can stitch sibling metrics.

## Value

`data.frame` in the CTAS long-format vocabulary. Includes the raw
SDTM-derived columns (`visit`, `visitnum`, `value`, and `low`/`high`
when supplied) alongside the CTAS-ready columns (`parameter_category_2`,
`parameter_category_3 = "numeric"`, `timepoint_1_name`,
`timepoint_rank`, `result`, `baseline`) and the ctasapp `untransformed`
source columns (`original_value`, `lower`, `upper`,
`original_category`). No rows are dropped apart from subjects absent
from `dfSubjects`, so the output can serve as the `untransformed` frame.
`visitnum` and `timepoint_rank` are recalculated as a contiguous `1..N`
`row_number()` within each `(subject_id, parameter_id)` group, ordered
by the source `VISITNUM` with `VISIT` as a tiebreaker – matching
ctasapp's `recalculate_timepoint_rank()`. The default output is ready to
feed straight into [`Analyze_CTAS()`](Analyze_CTAS.md); use
[`Transform_Range()`](Transform_Range.md) or
[`Transform_Missing()`](Transform_Missing.md) to overwrite
`result`/`parameter_category_3`/`parameter_id` for those transforms.

## Details

Reference-bound columns (`strLowCol`/`strHighCol`) are optional and only
meaningful for range-carrying sources such as LB.

## Examples

``` r
Standardize_Domain(
  dfDomain = data.frame(
    USUBJID = "S1", VSTESTCD = "SYSBP", VSTEST = "Systolic Blood Pressure",
    VSSTRESN = 120, VISIT = "WEEK 2", VISITNUM = 3
  ),
  dfSubjects = data.frame(
    studyid = "A", subject_id = "S1", site = "701", country = "USA"
  ),
  strTestCDCol = "VSTESTCD", strTestCol = "VSTEST", strValueCol = "VSSTRESN",
  strCategory = "Vital Signs"
)
#> # A tibble: 1 × 21
#>   subject_id parameter_id parameter_name          parameter_category_1
#>   <chr>      <chr>        <chr>                   <chr>               
#> 1 S1         SYSBP        Systolic Blood Pressure Vital Signs         
#> # ℹ 17 more variables: parameter_category_2 <chr>, parameter_category_3 <chr>,
#> #   visit <chr>, visitnum <int>, timepoint_1_name <chr>,
#> #   timepoint_2_name <chr>, timepoint_rank <int>, value <dbl>, result <dbl>,
#> #   baseline <dbl>, original_value <dbl>, lower <dbl>, upper <dbl>,
#> #   original_category <chr>, studyid <chr>, site <chr>, country <chr>
```
