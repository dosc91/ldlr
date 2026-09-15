#' Compute an LDL comprehension mapping
#'
#' Fits `C -> S` and returns `S_hat`, its targets, the mapping `F`, parameters,
#' and evaluation metadata as a portable R object. End-state and
#' frequency-informed learning call `JudiLing.make_transform_matrix()`;
#' incremental learning calls `JudiLing.wh_learn()` and optionally
#' `JudiLing.make_learn_seq()`. Validation, matrix naming, prediction, and
#' construction of the R model object happen in R.
#' @export
compute_comprehension <- function(C, S, C_test = NULL, S_test = NULL,
                                  learning = c("endstate", "frequency", "incremental"),
                                  frequency = NULL, epochs = 1L,
                                  learning_rate = 0.1,
                                  learning_sequence = NULL, seed = 314L,
                                  shift = 0.02) {
  training_cues <- if (inherits(C, "ldlr_cues")) C else NULL
  pair <- .ldlr_validate_pair(C, S, "C", "S")
  learning <- .ldlr_validate_learning(learning, frequency, epochs,
                                      learning_rate, learning_sequence)
  shift <- .ldlr_validate_shift(shift)
  if (!is.null(frequency) && length(frequency) != nrow(pair$x)) {
    .ldlr_stop("`frequency` must have one value per training row.")
  }
  if (!is.null(learning_sequence) && any(learning_sequence > nrow(pair$x))) {
    .ldlr_stop("`learning_sequence` contains a row index larger than the training data.")
  }
  fit <- .ldlr_fit_backend(pair$x, pair$y, learning, frequency, epochs,
                           learning_rate, learning_sequence, seed, shift)
  fit <- as.matrix(fit)
  dimnames(fit) <- list(colnames(pair$x), colnames(pair$y))
  test <- !is.null(C_test) || !is.null(S_test)
  if (test && (is.null(C_test) || is.null(S_test))) {
    .ldlr_stop("Supply both `C_test` and `S_test`, or neither.")
  }
  eval_pair <- if (test) .ldlr_validate_pair(C_test, S_test, "C_test", "S_test") else pair
  if (ncol(eval_pair$x) != nrow(fit)) .ldlr_stop("Test cue columns are incompatible with the fitted mapping.")
  predicted <- as.matrix(eval_pair$x) %*% as.matrix(fit)
  rownames(predicted) <- rownames(eval_pair$x)
  colnames(predicted) <- colnames(pair$y)
  model <- .ldlr_new_model("comprehension", as.matrix(fit), predicted,
                           as.matrix(eval_pair$y), eval_pair$x, learning,
                           list(frequency = frequency, epochs = epochs,
                                learning_rate = learning_rate, seed = seed,
                                shift = shift), test)
  model$cues <- if (test && inherits(C_test, "ldlr_cues")) C_test else training_cues
  model$training_cues_object <- training_cues
  model
}

#' Compute an LDL production mapping
#'
#' Fits `S -> C` and returns `C_hat`, its targets, the mapping `G`, parameters,
#' and evaluation metadata as a portable R object. End-state and
#' frequency-informed learning call `JudiLing.make_transform_matrix()`;
#' incremental learning calls `JudiLing.wh_learn()` and optionally
#' `JudiLing.make_learn_seq()`. Validation, matrix naming, prediction, and
#' construction of the R model object happen in R.
#' @export
compute_production <- function(S, C, S_test = NULL, C_test = NULL,
                               learning = c("endstate", "frequency", "incremental"),
                               frequency = NULL, epochs = 1L,
                               learning_rate = 0.1,
                               learning_sequence = NULL, seed = 314L,
                               shift = 0.02) {
  training_cues_object <- if (inherits(C, "ldlr_cues")) C else NULL
  pair <- .ldlr_validate_pair(S, C, "S", "C")
  learning <- .ldlr_validate_learning(learning, frequency, epochs,
                                      learning_rate, learning_sequence)
  shift <- .ldlr_validate_shift(shift)
  if (!is.null(frequency) && length(frequency) != nrow(pair$x)) {
    .ldlr_stop("`frequency` must have one value per training row.")
  }
  if (!is.null(learning_sequence) && any(learning_sequence > nrow(pair$x))) {
    .ldlr_stop("`learning_sequence` contains a row index larger than the training data.")
  }
  fit <- .ldlr_fit_backend(pair$x, pair$y, learning, frequency, epochs,
                           learning_rate, learning_sequence, seed, shift)
  fit <- as.matrix(fit)
  dimnames(fit) <- list(colnames(pair$x), colnames(pair$y))
  test <- !is.null(S_test) || !is.null(C_test)
  if (test && (is.null(S_test) || is.null(C_test))) {
    .ldlr_stop("Supply both `S_test` and `C_test`, or neither.")
  }
  eval_pair <- if (test) .ldlr_validate_pair(S_test, C_test, "S_test", "C_test") else pair
  if (ncol(eval_pair$x) != nrow(fit)) .ldlr_stop("Test semantic columns are incompatible with the fitted mapping.")
  predicted <- as.matrix(eval_pair$x) %*% as.matrix(fit)
  rownames(predicted) <- rownames(eval_pair$x)
  colnames(predicted) <- colnames(pair$y)
  model <- .ldlr_new_model("production", as.matrix(fit), predicted,
                           as.matrix(eval_pair$y), eval_pair$x, learning,
                           list(frequency = frequency, epochs = epochs,
                                learning_rate = learning_rate, seed = seed,
                                shift = shift), test)
  model$cues <- if (test && inherits(C_test, "ldlr_cues")) C_test else training_cues_object
  model$training_cues_object <- training_cues_object
  model$training_semantics <- as.matrix(pair$x)
  model$training_cues <- as.matrix(pair$y)
  model
}

#' @export
predict.ldlr_comprehension <- function(object, newdata, ...) {
  newdata <- as.matrix(.ldlr_matrix(newdata, "newdata"))
  if (ncol(newdata) != nrow(object$mapping)) .ldlr_stop("`newdata` has incompatible columns.")
  newdata %*% object$mapping
}

#' @export
predict.ldlr_production <- function(object, newdata, ...) {
  newdata <- as.matrix(.ldlr_matrix(newdata, "newdata"))
  if (ncol(newdata) != nrow(object$mapping)) .ldlr_stop("`newdata` has incompatible columns.")
  newdata %*% object$mapping
}

#' @export
coef.ldlr_model <- function(object, ...) object$mapping

#' @export
fitted.ldlr_model <- function(object, ...) object$predicted

#' @export
print.ldlr_model <- function(x, ...) {
  cat("<ldlr ", x$direction, " model>\n", sep = "")
  cat(" Learning:", x$learning, "\n")
  cat(" Evaluated on:", x$evaluated_on, "data\n")
  cat(" Accuracy:", format(round(x$accuracy, 4L), nsmall = 4L), "\n")
  cat(" Mapping:", nrow(x$mapping), "x", ncol(x$mapping), "\n")
  invisible(x)
}

#' @export
summary.ldlr_model <- function(object, ...) {
  data.frame(direction = object$direction, learning = object$learning,
             evaluated_on = object$evaluated_on, accuracy = object$accuracy,
             mapping_rows = nrow(object$mapping), mapping_columns = ncol(object$mapping))
}

#' @export
as.data.frame.ldlr_model <- function(x, ...) {
  target_correlation <- vapply(seq_len(nrow(x$predicted)), function(i) {
    .ldlr_row_cor(x$predicted[i, ], x$target[i, ])
  }, numeric(1L))
  data.frame(item = rownames(x$predicted) %||% seq_len(nrow(x$predicted)),
             target_correlation = target_correlation, stringsAsFactors = FALSE)
}

`%||%` <- function(x, y) if (is.null(x)) y else x

#' Save a portable ldlr model
#'
#' Uses R's [saveRDS()] format. Julia is not called and no live Julia object is
#' stored.
#' @export
save_ldlr_model <- function(model, file) {
  if (!inherits(model, "ldlr_model") && !inherits(model, "ldlr_forms") &&
      !inherits(model, "ldlr_cv")) {
    .ldlr_stop("`model` must be an ldlr model, cross-validation result, or produced-forms object.")
  }
  saveRDS(model, file = file, version = 3L)
  invisible(normalizePath(file, mustWork = FALSE))
}

#' Load a portable ldlr model
#'
#' Uses R's [readRDS()] and validates the stored class. Julia is not required.
#' @export
load_ldlr_model <- function(file) {
  model <- readRDS(file)
  if (!inherits(model, "ldlr_model") && !inherits(model, "ldlr_forms") &&
      !inherits(model, "ldlr_cv")) {
    .ldlr_stop("The file does not contain an ldlr object.")
  }
  model
}

#' Produce ordered word forms from a production model
#'
#' R validates compatible comprehension, production, and cue objects, then
#' delegates path search to Julia. The backend recreates cues with
#' `JudiLing.make_cue_matrix()` or `JudiLing.make_combined_cue_matrix()`, obtains
#' the search horizon with `JudiLing.cal_max_timestep()`, and calls
#' `JudiLing.learn_paths_rpi()` or `JudiLing.build_paths()`. Candidate paths are
#' translated with `JudiLing.translate()` and returned as portable R tables.
#'
#' @param production A model returned by [compute_production()].
#' @param comprehension The matching model returned by [compute_comprehension()].
#' @param cues The structured cue object used for the evaluated rows.
#' @param method JudiLing's `"build"` or `"learn"` path algorithm.
#' @param max_candidates Maximum number of candidate paths retained per item.
#' @param threshold Cue support threshold for `method = "learn"`.
#' @param tolerant Allow a limited number of cues below `threshold`.
#' @param tolerance Lower support threshold in tolerant mode.
#' @param max_tolerance Maximum below-threshold cues in a path.
#' @param neighbours Number of nearest forms used by `method = "build"`.
#' @param verbose Show JudiLing progress output.
#' @export
produce_forms <- function(production, comprehension, cues = production$cues,
                          method = c("build", "learn"), max_candidates = 10L,
                          threshold = 0.1, tolerant = FALSE,
                          tolerance = -1000, max_tolerance = 3L,
                          neighbours = 10L, verbose = FALSE) {
  if (!inherits(production, "ldlr_production")) {
    .ldlr_stop("`production` must be returned by `compute_production()`.")
  }
  if (!inherits(comprehension, "ldlr_comprehension")) {
    .ldlr_stop("`comprehension` must be returned by `compute_comprehension()`.")
  }
  if (!inherits(cues, "ldlr_cues")) {
    .ldlr_stop("`cues` must be returned by `make_ortho_trigrams()`.")
  }
  method <- match.arg(method)
  if (length(cues$words) != nrow(production$predicted)) {
    .ldlr_stop("The cue object and production predictions have different row counts.")
  }
  if (ncol(cues$C) != ncol(production$predicted) ||
      !identical(colnames(cues$C), colnames(production$predicted))) {
    .ldlr_stop("The cue object does not match the production model's cue columns.")
  }
  if (nrow(comprehension$mapping) != ncol(cues$C) ||
      ncol(comprehension$mapping) != ncol(production$input)) {
    .ldlr_stop("The comprehension and production mappings are dimensionally incompatible.")
  }
  max_candidates <- .ldlr_positive_integer(max_candidates, "max_candidates")
  max_tolerance <- .ldlr_nonnegative_integer(max_tolerance, "max_tolerance")
  neighbours <- .ldlr_positive_integer(neighbours, "neighbours")
  if (!is.numeric(threshold) || length(threshold) != 1L || !is.finite(threshold)) {
    .ldlr_stop("`threshold` must be one finite number.")
  }
  if (!is.numeric(tolerance) || length(tolerance) != 1L || !is.finite(tolerance)) {
    .ldlr_stop("`tolerance` must be one finite number.")
  }
  training_cues <- production$training_cues_object %||% cues
  raw <- .ldlr_paths_backend(
    training_cues$words, cues$words, production$training_cues,
    production$input, comprehension$mapping, production$predicted,
    cues$cue_names, cues$n, cues$boundary,
    method, max_candidates, threshold, isTRUE(tolerant), tolerance,
    max_tolerance, neighbours, isTRUE(verbose)
  )
  structure(
    list(
      method = method,
      candidates = .ldlr_portable_data_frame(raw$candidates),
      items = .ldlr_portable_data_frame(raw$items),
      gold = .ldlr_portable_data_frame(raw$gold),
      measures = raw$measures,
      production = production,
      comprehension = comprehension,
      cues = cues,
      parameters = list(max_candidates = max_candidates, threshold = threshold,
                        tolerant = tolerant, tolerance = tolerance,
                        max_tolerance = max_tolerance, neighbours = neighbours)
    ),
    class = "ldlr_forms"
  )
}

#' @export
print.ldlr_forms <- function(x, ...) {
  cat("<ldlr produced forms>\n")
  cat(" Method:", x$method, "\n")
  cat(" Items:", nrow(x$items), "\n")
  correct <- x$items$correct
  if (length(correct) && any(!is.na(correct))) {
    cat(" Accuracy:", format(round(mean(correct, na.rm = TRUE), 4L), nsmall = 4L), "\n")
  }
  invisible(x)
}
