#' Diagnose problematic measure columns
#'
#' Inspect output from [compute_measures()] for values that commonly indicate a
#' failed or uninformative calculation. Nested numeric list-columns, such as
#' item-level cue measures, are flattened for the diagnostic counts.
#'
#' The calculation is entirely native R and does not call Julia,
#' JudiLing, or JudiLingMeasures.
#'
#' @param x A data frame returned by [compute_measures()].
#' @param problems_only Return only columns with at least one detected problem.
#' @param tolerance Relative tolerance used to identify numerically constant
#'   floating-point columns.
#' @param include_identifiers Also inspect identifier columns named `item` and
#'   `fold`.
#' @return A data frame with one row per inspected column and diagnostic counts.
#' @export
check_measure_values <- function(x, problems_only = FALSE,
                                 tolerance = sqrt(.Machine$double.eps),
                                 include_identifiers = FALSE) {
  if (!is.data.frame(x)) .ldlr_stop("`x` must be a data frame returned by `compute_measures()`.")
  if (!is.logical(problems_only) || length(problems_only) != 1L || is.na(problems_only)) {
    .ldlr_stop("`problems_only` must be TRUE or FALSE.")
  }
  if (!is.logical(include_identifiers) || length(include_identifiers) != 1L ||
      is.na(include_identifiers)) {
    .ldlr_stop("`include_identifiers` must be TRUE or FALSE.")
  }
  if (!is.numeric(tolerance) || length(tolerance) != 1L || !is.finite(tolerance) ||
      tolerance < 0) {
    .ldlr_stop("`tolerance` must be one non-negative finite number.")
  }

  columns <- names(x)
  if (!include_identifiers) columns <- setdiff(columns, c("item", "fold"))
  rows <- lapply(columns, function(name) {
    column <- x[[name]]
    flattened <- if (is.list(column)) unlist(column, recursive = TRUE,
                                              use.names = FALSE) else column
    supported <- is.numeric(flattened) || is.logical(flattened)
    if (!supported) return(NULL)

    missing <- sum(is.na(flattened))
    nan <- if (is.numeric(flattened)) sum(is.nan(flattened)) else 0L
    infinite <- if (is.numeric(flattened)) sum(is.infinite(flattened)) else 0L
    usable <- !is.na(flattened)
    if (is.numeric(flattened)) usable <- usable & is.finite(flattened)
    observed <- flattened[usable]
    distinct <- length(unique(observed))
    all_missing <- length(observed) == 0L
    constant <- FALSE
    if (!all_missing) {
      constant <- if (is.numeric(observed)) {
        limits <- range(observed)
        (limits[[2L]] - limits[[1L]]) <=
          tolerance * max(1, max(abs(observed)))
      } else distinct == 1L
    }
    issues <- c(if (missing > 0L) "missing",
                if (nan > 0L) "NaN",
                if (infinite > 0L) "infinite",
                if (all_missing) "all missing",
                if (constant) "constant")
    data.frame(
      measure = name,
      storage = if (is.list(column)) "list-column" else typeof(column),
      values = length(flattened),
      missing = missing,
      nan = nan,
      infinite = infinite,
      distinct_observed = distinct,
      all_missing = all_missing,
      constant = constant,
      problem = length(issues) > 0L,
      issues = if (length(issues)) paste(issues, collapse = "; ") else "ok",
      stringsAsFactors = FALSE
    )
  })
  rows <- rows[!vapply(rows, is.null, logical(1L))]
  result <- if (length(rows)) do.call(rbind, rows) else data.frame(
    measure = character(), storage = character(), values = integer(),
    missing = integer(), nan = integer(), infinite = integer(),
    distinct_observed = integer(), all_missing = logical(), constant = logical(),
    problem = logical(), issues = character(), stringsAsFactors = FALSE
  )
  rownames(result) <- NULL
  if (problems_only) result <- result[result$problem, , drop = FALSE]
  result
}
