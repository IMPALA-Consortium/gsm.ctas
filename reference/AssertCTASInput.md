# Validate a CTAS long-format input frame

Validate a CTAS long-format input frame

## Usage

``` r
AssertCTASInput(dfInput, strStudyCol = "studyid")
```

## Arguments

- dfInput:

  `data.frame` Long-format CTAS input.

- strStudyCol:

  `character` Optional study column expected on `dfInput`.

## Value

`NULL`, invisibly. Aborts when the input is unusable.
