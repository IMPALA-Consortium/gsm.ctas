# Package index

## Mapping

Map SDTM domains into the CTAS long-format vocabulary.

- [`Standardize_Domain()`](Standardize_Domain.md) : Rename an SDTM
  findings domain into the CTAS long-format vocabulary
- [`Standardize_Queries()`](Standardize_Queries.md) : Standardise an EDC
  query frame into the CTAS + ctasapp vocabulary
- [`Transform_Missing()`](Transform_Missing.md) : Convert findings to a
  running missing-ratio timeseries for CTAS
- [`Transform_OneHot()`](Transform_OneHot.md) : One-hot encode a
  categorical findings frame for CTAS
- [`Transform_Range()`](Transform_Range.md) : Normalise
  reference-bounded numeric findings for CTAS

## Analysis

Run CTAS and emit the ctasapp-shaped output frames.

- [`Analyze_CTAS()`](Analyze_CTAS.md) : Score sites with CTAS

## Reporting

Bind the ctasapp output frames and write them to disk for the ctasapp
dashboard.

- [`BindResults_CTAS()`](BindResults_CTAS.md) : Bind one named shard
  across metric workflow outputs
- [`Write_ctasapp()`](Write_ctasapp.md) : Write ctasapp shards to disk

## Summary

Aggregate CTAS results into a gsm-shaped summary + metric + group meta
for the CTAS site report.

- [`Summarize_CTAS()`](Summarize_CTAS.md) : Aggregate CTAS site scores
  into a gsm-shaped CTAS summary

- [`Flag_CTAS()`](Flag_CTAS.md) :

  Flag CTAS scores with a gsm-shaped `Flag` column

- [`MakeMetric_CTAS()`](MakeMetric_CTAS.md) :

  Build the CTAS gsm-shaped `dfMetrics` audit table

- [`Report_CTAS()`](Report_CTAS.md) : Render the CTAS site-level report
  from a CTAS summary

## Package

- [`gsm.ctas`](gsm.ctas-package.md)
  [`gsm.ctas-package`](gsm.ctas-package.md) : gsm.ctas: Add CTAS Anomaly
  Detection to gsm

## Datasets

Illustrative SDTM domains and EDC query records shipped with the
package.

- [`dm`](dm.md) : SDTM DM (Demographics) domain
- [`lb`](lb.md) : SDTM LB (Laboratory) domain
- [`vs`](vs.md) : SDTM VS (Vital Signs) domain
- [`eg`](eg.md) : SDTM EG (ECG) domain
- [`rs`](rs.md) : SDTM RS (Disease Response) domain
- [`queries`](queries.md) : Illustrative EDC query records
- [`pd`](pd.md) : Illustrative Protocol Deviation records
