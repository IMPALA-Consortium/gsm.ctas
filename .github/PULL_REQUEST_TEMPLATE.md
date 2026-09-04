<!--
Thanks for the contribution. Please review the contributor guidelines:
https://impala-consortium.github.io/gsm.ctas/articles/ContributorGuidelines.html
-->

## Linked issue

Closes #

## Summary

<!-- One or two sentences describing the change. -->

## Checklist

- [ ] Branch cut from `dev` and named `{issue#}_short-slug`.
- [ ] Tests added or updated (`tests/testthat/`).
- [ ] `covr::percent_coverage(covr::package_coverage())` is `100` locally.
- [ ] No `# nocov` markers introduced. HTML-rendering code paths are
      exercised with real tests (`expect_s3_class(..., "htmlwidget")`
      for widgets, `withr::local_tempdir()` for `Report_CTAS()`).
      See README **Quality Control**.
- [ ] `devtools::document()` re-run; no unstaged diff in `man/` or
      `NAMESPACE`.
- [ ] `styler::style_pkg()` run.
- [ ] `NEWS.md` bullet added under the current development header.
- [ ] All GitHub Actions checks green.
