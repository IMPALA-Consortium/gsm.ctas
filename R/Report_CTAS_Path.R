#' Render the standard gsm.kri site-level KRI report from the CTAS package
#'
#' Thin wrapper around [gsm.kri::Report_KRI()] that plugs the vendored
#' `inst/report/Report_CTAS.Rmd` template into `strInputPath`. Exists so
#' workflow YAMLs don't have to resolve the template path themselves --
#' resolving `system.file(package = "gsm.ctas")` from a function that
#' lives in the `gsm.ctas` namespace is the only way to pick up
#' `pkgload`'s `inst/` shim under `devtools::load_all()`.
#'
#' Every other argument is forwarded verbatim to `Report_KRI()`.
#'
#' @param lCharts,dfResults,dfMetrics,dfGroups,strOutputDir,strOutputFile
#'   Forwarded to [gsm.kri::Report_KRI()].
#' @param ... Further arguments passed to [gsm.kri::Report_KRI()].
#'
#' @return `character(1)` File path of the rendered html report, invisibly.
#'
#' @export
Report_CTAS <- function(lCharts = NULL,
                        dfResults = NULL,
                        dfMetrics = NULL,
                        dfGroups = NULL,
                        strOutputDir = getwd(),
                        strOutputFile = NULL,
                        ...) {
  rlang::check_installed("gsm.kri", reason = "to run `Report_CTAS()`.")
  gsm.kri::Report_KRI(
    lCharts = lCharts,
    dfResults = dfResults,
    dfMetrics = dfMetrics,
    dfGroups = dfGroups,
    strOutputDir = strOutputDir,
    strOutputFile = strOutputFile,
    strInputPath = system.file("report", "Report_CTAS.Rmd", package = "gsm.ctas"),
    ...
  )
}
