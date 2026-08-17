# Builds tests/testthat/fixtures/ctas_result.rds
#
# `ctas::process_a_study()` is slow, so WP4-WP6 tests consume this cached
# result instead of re-running the engine. Re-run this script (from the package
# root) whenever the mapping layer or the CTAS defaults change.
#
#   source("tests/testthat/fixtures/make-ctas-fixture.R")

devtools::load_all(quiet = TRUE)

# A small but non-degenerate slice: 6 sites, 3 vital-signs parameters.
#
# Deliberately VS-only, even though the workflow now also maps LB. This fixture
# exists to make the `Analyze_CTAS()` / `Summarize_CTAS()` unit tests cheap, and
# a single domain is enough for that. Multi-domain behaviour - in particular the
# parameter filtering each metric relies on - is covered end to end in
# `test_workflow.R`, which runs the engine over VS and both lab views.
vs <- pharmaversesdtm::vs
dm <- pharmaversesdtm::dm

vSites <- sort(unique(dm$SITEID))[1:6]
dmSmall <- dm[dm$SITEID %in% vSites, ]
vsSmall <- vs[
  vs$USUBJID %in% dmSmall$USUBJID & vs$VSTESTCD %in% c("SYSBP", "DIABP", "PULSE"),
]

lInput <- Combine_CTAS_Input(
  Input_Numeric(vsSmall),
  Input_Range(lbSmall),
  Input_Missing(lbSmall),
  Input_Numeric(vsSmall),
  dfSubjectslyze_CTAS(lInput, nSeed = 20260813)

saveRDS(
  list(input = lInput, result = lCTAS),
  testthat::test_path("fixtures", "ctas_result.rds"),
  compress = "xz"
)
