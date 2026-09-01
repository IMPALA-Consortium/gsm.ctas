#' Absolute path to the vendored `Report_CTAS.Rmd` template
#'
#' Returns the `inst/report/Report_CTAS.Rmd` path this package ships.
#' Exists because YAML workflows can only call functions by name, and
#' `base::system.file` -- the version `workr` resolves for a bare
#' `system.file` step -- skips `pkgload`'s `inst/` shim during
#' `devtools::load_all()`, so the workflow needs an in-package indirection
#' that both `load_all` and the installed package resolve identically.
#'
#' @return `character(1)` Absolute path to the vendored Rmd template.
#'
#' @export
Report_CTAS_Path <- function() {
  system.file("report", "Report_CTAS.Rmd", package = "gsm.ctas")
}
