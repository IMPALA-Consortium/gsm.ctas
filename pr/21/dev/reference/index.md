# Package index

## Mapping

Map SDTM domains into CTAS input frames.

- [`Input_Missing()`](Input_Missing.md) : Map a findings domain to a
  missingness-ratio CTAS input

- [`Input_Numeric()`](Input_Numeric.md) : Map a numeric findings domain
  to CTAS input

- [`Input_OneHot()`](Input_OneHot.md) : Map a categorical findings
  domain to CTAS input via one-hot encoding

- [`Input_Range()`](Input_Range.md) : Map a numeric findings domain with
  reference ranges to CTAS input

- [`Input_Subjects()`](Input_Subjects.md) :

  Map a subject-level domain to the CTAS `subjects` frame

- [`Combine_CTAS_Input()`](Combine_CTAS_Input.md) : Combine domain
  inputs into the five CTAS input frames

## Preparation

Make values comparable across parameters.

- [`Prepare_Categorical()`](Prepare_Categorical.md) : One-hot encode a
  categorical variable
- [`Prepare_MissingRatio()`](Prepare_MissingRatio.md) : Running ratio of
  missing values over time
- [`Prepare_Normalize()`](Prepare_Normalize.md) : Normalize values by
  reference range
- [`Prepare_TimepointRank()`](Prepare_TimepointRank.md) : Recalculate
  timepoint rank as a positional integer

## Analysis

Run CTAS and bridge into the gsm analysis contract.

- [`Analyze_CTAS()`](Analyze_CTAS.md) : Run the CTAS engine over a
  combined study input

- [`Combine_CTAS_Scores()`](Combine_CTAS_Scores.md) : Attach parameter
  identity and category to CTAS site scores

- [`Summarize_CTAS()`](Summarize_CTAS.md) :

  Aggregate CTAS site scores into the gsm `Analysis_Analyzed` contract

- [`Flag_CTAS()`](Flag_CTAS.md) : Flag aggregated CTAS scores

## Reporting

Adjust the stock gsm.kri report for CTAS metrics.

- [`DropChart()`](DropChart.md) :

  Remove named charts from a `gsm.kri` chart list

## Drill-down

Retain and export timeseries-level detail for the ctasapp dashboard.

- [`Combine_CTAS_Detail()`](Combine_CTAS_Detail.md) :

  Assemble the timeseries-level detail object for `ctasapp` drill-down

- [`Write_CTAS_Detail()`](Write_CTAS_Detail.md) :

  Write the CTAS detail object to files `ctasapp` can load

## Package

- [`gsm.ctas`](gsm.ctas-package.md)
  [`gsm.ctas-package`](gsm.ctas-package.md) : gsm.ctas: Add CTAS Anomaly
  Detection to gsm
