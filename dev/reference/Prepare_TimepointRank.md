# Recalculate timepoint rank as a positional integer

Replaces `timepoint_rank` with a contiguous 1, 2, 3, ... sequence within
each `(subject_id, parameter_id)` group, ordered by the incoming numeric
`timepoint_rank` (typically `VISITNUM`) with `timepoint_1_name` as a
tiebreaker. CTAS requires contiguous ranks, which the source visit
numbers no longer provide after filtering or after binding several
domains together.

## Usage

``` r
Prepare_TimepointRank(dfInput)
```

## Arguments

- dfInput:

  `data.frame` Containing at least `subject_id`, `parameter_id`,
  `timepoint_1_name` and `timepoint_rank`.

## Value

`data.frame` with `timepoint_rank` recalculated, sorted by group and
rank.
