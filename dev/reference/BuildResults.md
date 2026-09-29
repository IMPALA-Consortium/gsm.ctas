# Enrich `site_scores` with parameter metadata and rename `studyid` to `study`

Joins CTAS `site_scores` to `timeseries` on `timeseries_id` to recover
`parameter_id`, and to the parameter metadata derived from `dfInput` to
recover the category columns CTAS discards. Renames `studyid` to `study`
(ctasapp vocabulary) when the multi-study contract is active.

## Usage

``` r
BuildResults(lCTAS, dfInput, strStudyCol)
```
