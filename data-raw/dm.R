dm <- as.data.frame(pharmaversesdtm::dm)
usethis::use_data(dm, overwrite = TRUE, compress = "xz")
