#' Empty untransformed detail frame
#'
#' @return `data.frame` with zero rows and the untransformed detail schema.
#'
#' @keywords internal
EmptyCTASUntransformed <- function() {
  data.frame(
    subject_id = character(0),
    parameter_category_2 = character(0),
    timepoint_1_name = character(0),
    original_value = numeric(0),
    lower = numeric(0),
    upper = numeric(0),
    original_category = character(0),
    stringsAsFactors = FALSE
  )
}
