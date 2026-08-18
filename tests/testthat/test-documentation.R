# WP9 keeps two documents in step with the code: the end-to-end vignette and the
# pkgdown reference index. Both drift silently -- a stale vignette still builds,
# and a missing pkgdown entry only shows up when the site is rendered -- so they
# are asserted here rather than left to review.

strVignette <- testthat::test_path("..", "..", "vignettes", "gsm-ctas.Rmd")
strPkgdown <- testthat::test_path("..", "..", "_pkgdown.yml")

test_that("the end-to-end vignette exists and declares its build metadata", {
  skip_if_not(file.exists(strVignette))

  vLines <- readLines(strVignette, warn = FALSE)

  expect_true(any(grepl("%\\\\VignetteIndexEntry\\{", vLines)))
  expect_true(any(grepl("%\\\\VignetteEngine\\{knitr::rmarkdown\\}", vLines)))
})

test_that("the vignette walks every workflow layer", {
  skip_if_not(file.exists(strVignette))

  strText <- paste(readLines(strVignette, warn = FALSE), collapse = "\n")

  # The point of the vignette is the *whole* path, so a layer dropping out of it
  # is a regression even though nothing fails.
  for (strLayer in c("1_mappings", "2_metrics", "3_reporting", "4_modules")) {
    expect_true(grepl(strLayer, strText, fixed = TRUE))
  }

  # The two documented customisation paths, per PLAN.md WP9.
  expect_true(grepl("ParseThreshold", strText, fixed = TRUE))
  expect_true(grepl("Adding a metric", strText, fixed = TRUE))
})

test_that("the vignette's R chunks parse", {
  skip_if_not(file.exists(strVignette))
  skip_if_not_installed("knitr")

  # Catches syntax errors without paying for the CTAS run that evaluating the
  # vignette would require.
  strCode <- withr::local_tempfile(fileext = ".R")
  suppressMessages(knitr::purl(strVignette, output = strCode, quiet = TRUE))

  expect_no_error(parse(strCode))
})

test_that("every exported function appears in the pkgdown reference", {
  skip_if_not(file.exists(strPkgdown))
  skip_if_not_installed("yaml")

  lPkgdown <- yaml::read_yaml(strPkgdown)
  vContents <- unlist(lapply(lPkgdown$reference, function(lSection) lSection$contents))

  vExports <- getNamespaceExports("gsm.ctas")

  # `starts_with("Input_")`-style selectors are resolved by hand: pkgdown itself
  # would need the built site to do it.
  vPrefixes <- sub('^starts_with\\("(.*)"\\)$', "\\1", grep("^starts_with", vContents, value = TRUE))
  vExplicit <- vContents[!grepl("^starts_with", vContents)]

  bCovered <- vapply(
    vExports,
    function(strExport) {
      strExport %in% vExplicit || any(startsWith(strExport, vPrefixes))
    },
    logical(1)
  )

  expect_true(all(bCovered), info = paste(vExports[!bCovered], collapse = ", "))
})

test_that("the pkgdown site lists the vignette as an article", {
  skip_if_not(file.exists(strPkgdown))
  skip_if_not_installed("yaml")

  lPkgdown <- yaml::read_yaml(strPkgdown)
  vArticles <- unlist(lapply(lPkgdown$articles, function(lSection) lSection$contents))

  expect_true("gsm-ctas" %in% vArticles)
})
