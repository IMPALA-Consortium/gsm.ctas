# Changelog

## gsm.ctas (development version)

### Source data always reaches ctasapp (#39)

ctasapp now gets source data for every field: when CTAS scores it, when
CTAS drops the timeseries, when the field only has a missingness score,
and when a field’s values are all NA. Each metric workflow ships its
[`Standardize_Domain()`](../reference/Standardize_Domain.md) output as
the `untransformed` frame, so source rows don’t depend on whether the
CTAS run succeeds. The ctasapp upload contract is unchanged; only
columns were added.

#### Root causes

- **[`Transform_Range()`](../reference/Transform_Range.md) dropped
  rows.** It removed rows with an NA value or an unusable reference
  range. ANISO has numeric values but no reference ranges, so it
  disappeared completely. COLOR is text-only and was dropped the same
  way.
- **Only some metrics shipped source rows.** `range_normalized` shipped
  its transformed rows as `untransformed`, so NA rows were already gone.
  `numeric` and `ratio_missing` shipped nothing.
- **[`BindResults_CTAS()`](../reference/BindResults_CTAS.md) dropped
  rows without a value.** It removed every `untransformed` row where
  both `original_value` and `original_category` were NA, and it didn’t
  de-duplicate across metrics.
- **A CTAS failure cost the whole metric.** An error inside CTAS,
  including CTAS dropping every timeseries, aborted the metric workflow
  and lost its `input` and `untransformed`.
- **ctasapp ignores missingness rows for source data.** Its Source Data
  table only attaches `untransformed` to `input` rows that aren’t
  missingness rows. A field with only a `MISS_` timeseries, such as
  COLOR, therefore showed no source data.

#### Changes

- **[`Standardize_Domain()`](../reference/Standardize_Domain.md)**
  - Always adds `original_value`, `lower`, `upper` and
    `original_category`.
  - New argument `strCharCol` (e.g. `LBSTRESC`) fills
    `original_category` where the numeric result is NA, so text results
    like COLOR “N” or ECGINT “ABNORMAL” stay visible.
  - Drops no rows, except for subjects missing from `dfSubjects`.
- **[`Transform_Range()`](../reference/Transform_Range.md)**
  - No longer drops rows. Rows with an NA value or an unusable range
    keep `result = NA`, so CTAS’s missingness threshold applies.
  - New argument `dMaxShareMissingRange` (default `0.5`). When more than
    that share of a field’s values has no usable range, the field is
    emitted as raw `NUM_<field>` with
    `parameter_category_3 = "numeric"`. ANISO is handled this way.
  - Fields with no values at all are kept with NA results and listed in
    a message.
- **[`Transform_Missing()`](../reference/Transform_Missing.md)**: lists
  fields that are 100% missing for all subjects in a `cli` message. The
  `MISS_` output is unchanged.
- **`BindResults_CTAS(..., "untransformed")`**
  - Removes `value`, `result`, `low`, `high`, `parameter_id` and
    `parameter_category_3` before binding.
  - Keeps rows with no reported value.
  - De-duplicates on
    `(study, subject_id, parameter_category_2, timepoint_1_name)`,
    keeping the copy with the most filled-in `original_*` columns.
- **[`Analyze_CTAS()`](../reference/Analyze_CTAS.md)**: new
  `bStopOnError` argument. When `FALSE`, an error from CTAS becomes a
  warning and an empty results frame
  ([`EmptyCTASResults()`](../reference/EmptyCTASResults.md)), so `input`
  and `untransformed` are still shipped. Input validation still aborts.
- **Workflows**
  - All four metric YAMLs ship `untransformed` and set
    `StopOnError: false`.
  - `range_normalized.yaml` adds `MaxShareMissingRange: 0.5`.
  - `categorical.yaml` no longer needs its SQL de-duplication step.
  - The LB, VS and EG mappings and metric specs now carry `*STRESC`.
- **Docs**: roxygen, `man/`, Cookbook and
  `.github/copilot-instructions.md`.

#### Effect on the sample data

- **ANISO**: scored as `NUM_ANISO`.
- **COLOR**: has `RANGE_COLOR` input rows with NA results plus
  `MISS_COLOR`. Its 830 `untransformed` rows show
  `original_category = "N"`.
- **ECGINT**: has numeric input rows with NA results, and its source
  rows show NORMAL/ABNORMAL.
- **Coverage**: every input field appears in `untransformed`, and the
  join keys are unique.

#### Known limitation

`MISS_` ratios still look only at `*STRESN`, so text-only fields such as
COLOR and ECGINT show 100% missing. Counting a `*STRESC` result as
reported is left for a follow-up.

#### Tests tagged \#39

**`Standardize_Domain results must match source data, keeping every row and field (#29, #39)`**
(`test-validation.R`)

- **Data:** bundled `dm`, `vs` and `lb`.
- **Preparation:**
  [`Standardize_Domain()`](../reference/Standardize_Domain.md) on VS,
  and on LB with `strLowCol`, `strHighCol` and
  `strCharCol = "LBSTRESC"`.
- **Comparison:** the output’s `original_value`, `lower`, `upper` and
  `original_category` are mapped back to `LBSTRESN`, `LBSTNRLO`,
  `LBSTNRHI` and `LBSTRESC`. The source side keeps `LBSTRESC` only where
  `LBSTRESN` is NA.
- **Alignment:** both frames are sorted on all columns.
- **Expected:** the mapped-back frame equals the source exactly, so no
  rows or fields are lost.

**`Transform_Range results must match source data without dropping any field (#32, #39)`**
(`test-validation.R`)

- **Data:** bundled `dm` and `lb`.
- **Preparation:**
  [`Standardize_Domain()`](../reference/Standardize_Domain.md) with
  ranges, then [`Transform_Range()`](../reference/Transform_Range.md)
  with the default threshold.
- **Comparison:** `NUM_` fields are mapped back to the raw value and
  `RANGE_` fields are de-normalised. The expected frame is derived from
  the source: it applies the fallback rule per field and sets
  unusable-range values to NA.
- **Alignment:** both frames are sorted on all columns.
- **Expected:** the frames are equal, every `LBTESTCD` is present (COLOR
  included), and ANISO is `NUM_ANISO`.

**`Write_ctasapp files meet ctasapp file requirements and carry source rows for every field (#33, #39)`**
(`test-validation.R`)

- **Data:** the full bundled data (`dm`, `lb`, `vs`, `eg`, `rs`,
  `queries`, `pd`).
- **Preparation:** the mapping, metric and reporting workflows, then
  [`Write_ctasapp()`](../reference/Write_ctasapp.md) to parquet.
- **Comparison 1:** the `untransformed` keys are compared with the
  distinct keys from the mapped LB, VS, EG, RS and BMI data, restricted
  to known subjects.
- **Comparison 2:** the test rebuilds ctasapp’s
  `prepare_ts_data_multi()` join: `input` without `ratio_missing` rows,
  left-joined to de-duplicated `untransformed` on the join keys.
- **Expected:**
  - the `untransformed` keys are unique and equal the source keys;
  - every `parameter_category_2` in `input` appears in the joined Source
    Data table. This check failed on COLOR before the
    [`Transform_Range()`](../reference/Transform_Range.md) change.

**`an all-NA field keeps MISS_ input and raw untransformed rows (#39)`**
(`test_workflow.R`)

- **Data:** a 6-site slice of the `pharmaversesdtm` data, stacked into
  two studies, with EG including ECGINT (a text-only field).
- **Preparation:** the mapping and metric workflows.
- **Comparison:** the `MISS_ECGINT` input and the bound `untransformed`
  rows for ECGINT, against the distinct study/subject/visit combinations
  in the source.
- **Expected:**
  - `MISS_ECGINT` is 1 everywhere;
  - `untransformed` has one ECGINT row per source key, with NA
    `original_value` and non-NA `original_category`.

**`a field CTAS drops still ships input and untransformed (#39)`**
(`test_workflow.R`)

- **Data:** the same workflow test data as above.
- **Preparation:** the numeric metric workflow, which receives ECGINT
  with NA results only.
- **Comparison:** `results` against `input` and `untransformed` for
  ECGINT.
- **Expected:** ECGINT is missing from `results` but present in both
  `input` and `untransformed`.

**`Transform_Missing keeps an all-NA field and names it in a message (#39)`**
(`test-Transform.R`)

- **Data:** a small synthetic frame with COLOR (all NA) and ALT (partly
  NA).
- **Preparation:**
  [`Transform_Missing()`](../reference/Transform_Missing.md).
- **Comparison:** the emitted message and the `MISS_` output.
- **Expected:** the message names COLOR, COLOR’s ratio is 1 at every
  visit, and both `MISS_COLOR` and `MISS_ALT` are present.
