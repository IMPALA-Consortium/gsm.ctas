test_that("package loads and is installable", {
  expect_true(requireNamespace("gsm.ctas", quietly = TRUE))
  expect_type(utils::packageVersion("gsm.ctas"), "list")
})
