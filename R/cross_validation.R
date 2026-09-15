.ldlr_validate_cv_options <- function(output, progress, shift) {
  shift <- .ldlr_validate_shift(shift)
  if (!is.null(output) &&
      (!is.character(output) || length(output) != 1L || is.na(output) || !nzchar(output))) {
    .ldlr_stop("`output` must be NULL or one non-empty file path.")
  }
  list(output = output, progress = isTRUE(progress), shift = as.numeric(shift))
}

.ldlr_cv_result <- function(direction, predicted, target, fold, method,
                            parameters, output) {
  predicted <- as.matrix(predicted)
  target <- as.matrix(target)
  result <- list(direction = direction, method = method, predicted = predicted,
                 target = target, fold = as.integer(fold),
                 accuracy = .ldlr_accuracy(predicted, target), parameters = parameters)
  if (direction == "comprehension") result$S_hat <- predicted
  else result$C_hat <- predicted
  result <- structure(result, class = "ldlr_cv")
  if (!is.null(output)) {
    items <- rownames(predicted) %||% as.character(seq_len(nrow(predicted)))
    data.table::fwrite(data.frame(item = items, predicted, check.names = FALSE), output)
  }
  result
}

.ldlr_run_loo <- function(C, S, direction, output, progress, chunk_size, shift) {
  pair <- .ldlr_validate_pair(C, S, "C", "S")
  if (nrow(pair$x) < 2L) .ldlr_stop("Leave-one-out validation requires at least two rows.")
  options <- .ldlr_validate_cv_options(output, progress, shift)
  chunk_size <- .ldlr_positive_integer(chunk_size, "chunk_size")
  input <- if (direction == "comprehension") pair$x else pair$y
  target <- if (direction == "comprehension") pair$y else pair$x
  if (options$progress) message("Leave-one-out ", direction, ": preparing factorization...")
  predicted <- .ldlr_loo_backend(input, target, options$shift, chunk_size,
                                 options$progress)
  rownames(predicted) <- rownames(input)
  colnames(predicted) <- colnames(target)
  .ldlr_cv_result(direction, predicted, as.matrix(target), seq_len(nrow(input)),
                  "leave-one-out", list(n = nrow(input), shift = options$shift,
                                        chunk_size = chunk_size), options$output)
}

.ldlr_fold_ids <- function(n, folds, seed) {
  folds <- .ldlr_positive_integer(folds, "folds")
  if (folds < 2L || folds > n) .ldlr_stop("`folds` must be between 2 and the number of rows.")
  if (!is.numeric(seed) || length(seed) != 1L || !is.finite(seed)) {
    .ldlr_stop("`seed` must be one finite number.")
  }
  old_seed_exists <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  if (old_seed_exists) old_seed <- get(".Random.seed", envir = .GlobalEnv)
  on.exit({
    if (old_seed_exists) assign(".Random.seed", old_seed, envir = .GlobalEnv)
    else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE))
      rm(".Random.seed", envir = .GlobalEnv)
  }, add = TRUE)
  set.seed(as.integer(seed))
  sample(rep(seq_len(folds), length.out = n))
}

.ldlr_run_kfold <- function(C, S, direction, folds, seed, output, progress, shift) {
  pair <- .ldlr_validate_pair(C, S, "C", "S")
  options <- .ldlr_validate_cv_options(output, progress, shift)
  fold <- .ldlr_fold_ids(nrow(pair$x), folds, seed)
  input <- as.matrix(if (direction == "comprehension") pair$x else pair$y)
  target <- as.matrix(if (direction == "comprehension") pair$y else pair$x)
  predicted <- matrix(NA_real_, nrow(input), ncol(target))
  progress_bar <- if (options$progress) {
    message(max(fold), "-fold ", direction, " cross-validation...")
    utils::txtProgressBar(min = 0L, max = max(fold), style = 3L)
  } else NULL
  if (!is.null(progress_bar)) on.exit(close(progress_bar), add = TRUE)
  for (i in seq_len(max(fold))) {
    test <- fold == i
    mapping <- .ldlr_endstate_backend(input[!test, , drop = FALSE],
                                      target[!test, , drop = FALSE], options$shift)
    predicted[test, ] <- input[test, , drop = FALSE] %*% as.matrix(mapping)
    if (!is.null(progress_bar)) utils::setTxtProgressBar(progress_bar, i)
  }
  rownames(predicted) <- rownames(input)
  colnames(predicted) <- colnames(target)
  .ldlr_cv_result(direction, predicted, target, fold, "k-fold",
                  list(n = nrow(input), folds = max(fold), seed = as.integer(seed),
                       shift = options$shift), options$output)
}

#' Leave-one-out LDL predictions
#'
#' Compute exact end-state leave-one-out predictions for every row. The
#' implementation is equivalent to refitting JudiLing's additive mapping `n`
#' times, but uses a ridge-leverage identity and chunked progress updates.
#' The exact identity and its Cholesky factorization run in the ldlr Julia
#' backend. It matches the estimator used by `JudiLing.make_transform_matrix()`
#' but avoids calling that function once per row. Validation, progress display,
#' optional CSV writing, and result construction happen in R.
#' @param C A numeric cue matrix or an `ldlr_cues` object.
#' @param S A matched numeric semantic matrix.
#' @param output Optional CSV output path.
#' @param progress Show an R progress bar.
#' @param chunk_size Rows calculated between progress updates.
#' @param shift Positive ridge shift; `0.02` matches JudiLing's default.
#' @export
compute_comprehension_loo <- function(C, S, output = NULL, progress = interactive(),
                                      chunk_size = 25L, shift = 0.02) {
  .ldlr_run_loo(C, S, "comprehension", output, progress, chunk_size, shift)
}

#' @rdname compute_comprehension_loo
#' @export
compute_production_loo <- function(S, C, output = NULL, progress = interactive(),
                                   chunk_size = 25L, shift = 0.02) {
  .ldlr_run_loo(C, S, "production", output, progress, chunk_size, shift)
}

#' K-fold LDL predictions
#'
#' Fit an end-state mapping on `folds - 1` partitions and predict the held-out
#' partition, repeating until all `n` rows have one held-out prediction.
#' R creates reproducible balanced folds and displays progress. Each Julia fit
#' uses a Cholesky implementation of the same shifted end-state estimator as
#' `JudiLing.make_transform_matrix()`; held-out multiplication and the returned
#' portable cross-validation object are managed in R.
#' @inheritParams compute_comprehension_loo
#' @param folds Number of cross-validation folds.
#' @param seed Seed for reproducible balanced fold assignment.
#' @export
compute_comprehension_cv <- function(C, S, folds = 10L, seed = 314L,
                                     output = NULL, progress = interactive(),
                                     shift = 0.02) {
  .ldlr_run_kfold(C, S, "comprehension", folds, seed, output, progress, shift)
}

#' @rdname compute_comprehension_cv
#' @export
compute_production_cv <- function(S, C, folds = 10L, seed = 314L,
                                  output = NULL, progress = interactive(),
                                  shift = 0.02) {
  .ldlr_run_kfold(C, S, "production", folds, seed, output, progress, shift)
}

#' @export
print.ldlr_cv <- function(x, ...) {
  cat("<ldlr ", x$direction, " cross-validation>\n", sep = "")
  cat(" Method:", x$method, "\n")
  cat(" Rows:", nrow(x$predicted), "\n")
  if (x$method == "k-fold") cat(" Folds:", x$parameters$folds, "\n")
  cat(" Accuracy:", format(round(x$accuracy, 4L), nsmall = 4L), "\n")
  invisible(x)
}

.ldlr_cv_rows <- function(x) {
  target_correlation <- vapply(seq_len(nrow(x$predicted)), function(i) {
    .ldlr_row_cor(x$predicted[i, ], x$target[i, ])
  }, numeric(1L))
  similarities <- suppressWarnings(stats::cor(t(x$predicted), t(x$target)))
  if (is.null(dim(similarities))) similarities <- matrix(similarities, 1L, 1L)
  recognition <- rep(NA, nrow(x$predicted))
  valid <- rowSums(is.na(similarities)) == 0L
  recognition[valid] <- max.col(similarities[valid, , drop = FALSE],
                                ties.method = "first") == seq_len(nrow(x$predicted))[valid]
  data.frame(item = rownames(x$predicted) %||% seq_len(nrow(x$predicted)),
             fold = x$fold, target_correlation = target_correlation,
             recognition = recognition, stringsAsFactors = FALSE)
}

#' @export
as.data.frame.ldlr_cv <- function(x, ...) .ldlr_cv_rows(x)

#' @export
fitted.ldlr_cv <- function(object, ...) object$predicted

#' @export
summary.ldlr_cv <- function(object, by_fold = FALSE, ...) {
  rows <- .ldlr_cv_rows(object)
  summarise_rows <- function(data, fold = NA_integer_) {
    data.frame(direction = object$direction, method = object$method,
               fold = fold, rows = nrow(data),
               accuracy = if (all(is.na(data$recognition))) NA_real_ else
                 mean(data$recognition, na.rm = TRUE),
               mean_target_correlation = if (all(is.na(data$target_correlation))) NA_real_ else
                 mean(data$target_correlation, na.rm = TRUE))
  }
  overall <- summarise_rows(rows)
  if (!isTRUE(by_fold)) return(overall[, setdiff(names(overall), "fold"), drop = FALSE])
  per_fold <- do.call(rbind, lapply(split(rows, rows$fold), function(data) {
    summarise_rows(data, unique(data$fold))
  }))
  rownames(per_fold) <- NULL
  per_fold
}
