# Unit tests for Write_ctasapp() covering input validation, the loop skip
# branch, and the csv format branch (parquet is exercised by test_workflow.R).

MakeReportingFixture <- function() {
  list(
    Reporting_Results = list(
      results = data.frame(site = c("101", "102"), score = c(1, 2)),
      input = data.frame(subject_id = c("s1", "s2"), value = c(1.0, 2.0)),
      untransformed = data.frame()
    ),
    Reporting_Queries = list(
      queries = data.frame(subject_id = "s1", parameter_id = "AST")
    )
  )
}

test_that("errors when lReporting is not a list", {
  expect_error(
    Write_ctasapp(iris, tempdir()),
    "list of reporting workflow outputs"
  )
})

test_that("errors when strDir is not a single string", {
  expect_error(Write_ctasapp(MakeReportingFixture(), 1), "single directory path")
  expect_error(
    Write_ctasapp(MakeReportingFixture(), c("a", "b")),
    "single directory path"
  )
})

test_that("errors when strFormat is not one of parquet/csv", {
  expect_error(
    Write_ctasapp(MakeReportingFixture(), tempdir(), strFormat = "xlsx"),
    "parquet"
  )
})

test_that("errors when lReporting contains no writable frames", {
  expect_error(
    Write_ctasapp(list(Reporting_Empty = list()), tempdir()),
    "no writable data frames"
  )
})

test_that("non-list outer entries are skipped silently", {
  lReporting <- MakeReportingFixture()
  lReporting$Reporting_Skip <- "not a list"

  strDir <- withr::local_tempdir()
  vPaths <- Write_ctasapp(lReporting, strDir, strFormat = "csv")

  expect_true(length(vPaths) > 0)
  expect_false(any(grepl("Reporting_Skip", vPaths)))
})

test_that("csv format writes one .csv per non-empty inner frame", {
  strDir <- withr::local_tempdir()
  vPaths <- Write_ctasapp(MakeReportingFixture(), strDir, strFormat = "csv")

  expect_true(all(file.exists(vPaths)))
  expect_true(all(grepl("\\.csv$", vPaths)))
  expect_setequal(
    basename(vPaths),
    c("results.csv", "input.csv", "queries.csv")
  )

  # Round-trip check on one shard.
  dfResults <- utils::read.csv(file.path(strDir, "results.csv"))
  expect_equal(nrow(dfResults), 2)
  expect_setequal(dfResults$site, c(101, 102))
})

test_that("parquet format writes one .parquet per non-empty inner frame", {
  skip_if_not_installed("arrow")
  strDir <- withr::local_tempdir()
  vPaths <- Write_ctasapp(MakeReportingFixture(), strDir, strFormat = "parquet")

  expect_true(all(file.exists(vPaths)))
  expect_true(all(grepl("\\.parquet$", vPaths)))
  expect_setequal(
    basename(vPaths),
    c("results.parquet", "input.parquet", "queries.parquet")
  )
})
