# pharmaversesdtm's oncology response frame is `rs_onco`; renamed to `rs` on
# ingest so `Raw_RS` in the mapping YAMLs matches the two-letter SDTM domain
# convention used by every other bundled dataset.
rs <- as.data.frame(pharmaversesdtm::rs_onco)
usethis::use_data(rs, overwrite = TRUE, compress = "xz")
