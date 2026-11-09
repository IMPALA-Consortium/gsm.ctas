# NA

## Linked issue

Closes \#

## Summary

## Checklist

Branch cut from `dev` and named `{issue#}_short-slug`.

Tests added or updated (`tests/testthat/`).

Each linked issue has a test with `(#issue)` in its title or the
`qcthat-nocov` label.

`covr::percent_coverage(covr::package_coverage())` is `100` locally.

No `# nocov` markers introduced. HTML-rendering code paths are exercised
with real tests (`expect_s3_class(..., "htmlwidget")` for widgets,
[`withr::local_tempdir()`](https://withr.r-lib.org/reference/with_tempfile.html)
for [`Report_CTAS()`](reference/Report_CTAS.md)). See README **Quality
Control**.

`devtools::document()` re-run; no unstaged diff in `man/` or
`NAMESPACE`.

`styler::style_pkg()` run.

`NEWS.md` bullet added under the current development header.

All GitHub Actions checks green.
