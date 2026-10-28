# Contributor Guidelines

[`CONTRIBUTING.md`](https://github.com/IMPALA-Consortium/gsm.ctas/blob/main/CONTRIBUTING.md)
is a stub that links here.

## Branches

- `main` — protected. Only merged via pull request; all required checks
  must be green.
- `{issue#}_short-slug` — one feature/fix branch per GitHub issue, cut
  from `main`. The issue number prefix ties the branch to the tracker
  and to the changelog entry.
- `dev` branch usage is encouraged but not required before deploying
  complex changes so that they can be easier reviewed.

## Development process

1.  Open a GitHub issue describing the change. Pick the appropriate
    template from `.github/ISSUE_TEMPLATE/`.

2.  Cut a branch named `{issue#}_short-slug` from `main`. j block first,
    then the R code that makes it pass. Every exported function and
    every non-trivial internal helper gets a direct unit test.

3.  Regenerate documentation and format code before pushing:

    ``` r

    devtools::document()
    styler::style_pkg()
    ```

4.  Add a bullet to `NEWS.md` under the current development header.

5.  Open a pull request against `main`.

## Issue-linked tests (qcthat)

Every issue must be covered by qcthat:

- Link the test that proves the issue’s requirement by putting the issue
  number in the `test_that()` title, e.g.
  `test_that("Transform_Range results must match source data (#32)", ...)`.
  qcthat ignores issue numbers in comments.
- Issues that need no test evidence (documentation, CI, refactoring) get
  the `qcthat-nocov` label. Obsolete issues are closed as “not planned”.
- Document the test in the issue in this order: sample data, preparation
  functions, compared processing paths, output alignment, expected
  result.
- Tests for edge cases and errors do not need an issue.

## Quality control

see README.md
