# Tag every result frame with a studyid column

Tag every result frame with a studyid column

## Usage

``` r
TagStudyID(lCTAS, strStudy, strStudyCol)
```

## Arguments

- lCTAS:

  `list` Result of
  [`ctas::process_a_study()`](https://rdrr.io/pkg/ctas/man/process_a_study.html).

- strStudy:

  `character` Study id to write.

- strStudyCol:

  `character` Column name to use.

## Value

`list` `lCTAS` with `strStudyCol` present on every non-null frame.
