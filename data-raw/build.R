# Regenerate every bundled dataset from pharmaversesdtm.
#
# Run with `Rscript data-raw/build.R` from the package root. Order matters:
# the SDTM domain copies land first, then `queries.R` samples against them.

vScripts <- c(
  "data-raw/dm.R",
  "data-raw/lb.R",
  "data-raw/vs.R",
  "data-raw/eg.R",
  "data-raw/rs.R",
  "data-raw/pd.R",
  "data-raw/queries.R"
)

for (s in vScripts) {
  message("== ", s)
  source(s, echo = FALSE)
}
