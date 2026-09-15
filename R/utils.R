.ldlr_stop <- function(..., call. = FALSE) {
  stop(..., call. = call.)
}

.ldlr_positive_integer <- function(x, name) {
  if (!is.numeric(x) || length(x) != 1L || !is.finite(x) || x < 1 || x != as.integer(x)) {
    .ldlr_stop("`", name, "` must be a positive integer.")
  }
  as.integer(x)
}

.ldlr_nonnegative_integer <- function(x, name) {
  if (!is.numeric(x) || length(x) != 1L || !is.finite(x) || x < 0 || x != as.integer(x)) {
    .ldlr_stop("`", name, "` must be a non-negative integer.")
  }
  as.integer(x)
}

.ldlr_validate_shift <- function(shift) {
  if (!is.numeric(shift) || length(shift) != 1L || !is.finite(shift) || shift <= 0) {
    .ldlr_stop("`shift` must be one positive finite number.")
  }
  as.numeric(shift)
}

.ldlr_portable_data_frame <- function(x) {
  x <- as.list(x)
  lengths <- vapply(x, length, integer(1L))
  row_count <- if (length(lengths)) max(lengths) else 0L
  out <- list()
  for (name in names(x)) {
    value <- x[[name]]
    if (length(value) == row_count && !is.list(value)) {
      out[[name]] <- value
    } else {
      out[[name]] <- I(as.list(value))
    }
  }
  as.data.frame(out, stringsAsFactors = FALSE, optional = TRUE)
}

.ldlr_matrix <- function(x, name) {
  if (inherits(x, "ldlr_cues")) x <- x$C
  if (!is.matrix(x) && !inherits(x, "Matrix")) {
    .ldlr_stop("`", name, "` must be a numeric matrix or an ldlr cue object.")
  }
  if (!is.numeric(x)) .ldlr_stop("`", name, "` must be numeric.")
  if (any(!is.finite(x))) .ldlr_stop("`", name, "` contains missing or infinite values.")
  x
}

.ldlr_validate_pair <- function(x, y, x_name, y_name) {
  x <- .ldlr_matrix(x, x_name)
  y <- .ldlr_matrix(y, y_name)
  if (nrow(x) != nrow(y)) {
    .ldlr_stop("`", x_name, "` and `", y_name, "` must have the same number of rows.")
  }
  rx <- rownames(x)
  ry <- rownames(y)
  if (!is.null(rx) && !is.null(ry) && !identical(rx, ry)) {
    if (setequal(rx, ry)) {
      .ldlr_stop("Row names match but are ordered differently. Reorder the matrices explicitly.")
    }
    .ldlr_stop("The row names of `", x_name, "` and `", y_name, "` do not match.")
  }
  list(x = x, y = y)
}

.ldlr_validate_learning <- function(learning, frequency, epochs,
                                    learning_rate, learning_sequence) {
  learning <- match.arg(learning, c("endstate", "frequency", "incremental"))
  if (learning == "frequency") {
    if (is.null(frequency)) .ldlr_stop("`frequency` is required for frequency-informed learning.")
    if (!is.numeric(frequency) || any(!is.finite(frequency)) || any(frequency < 0) ||
        !any(frequency > 0)) {
      .ldlr_stop("`frequency` must be finite, non-negative, and contain a positive value.")
    }
  }
  if (learning == "incremental") {
    if (length(epochs) != 1L || epochs < 1 || epochs != as.integer(epochs)) {
      .ldlr_stop("`epochs` must be a positive integer.")
    }
    if (length(learning_rate) != 1L || !is.finite(learning_rate) || learning_rate <= 0) {
      .ldlr_stop("`learning_rate` must be a positive finite number.")
    }
    if (!is.null(learning_sequence) &&
        (!is.numeric(learning_sequence) || any(learning_sequence < 1))) {
      .ldlr_stop("`learning_sequence` must contain positive row indices.")
    }
    if (!is.null(frequency) &&
        (!is.numeric(frequency) || any(!is.finite(frequency)) || any(frequency < 0) ||
         any(frequency != as.integer(frequency)))) {
      .ldlr_stop("For incremental learning, `frequency` must contain non-negative integer event counts.")
    }
    if (!is.null(frequency) && length(learning_sequence)) {
      .ldlr_stop("Supply either `frequency` or `learning_sequence` for incremental learning, not both.")
    }
  }
  learning
}

.ldlr_new_model <- function(direction, mapping, predicted, target, input,
                            learning, parameters, test = FALSE) {
  value <- list(
      direction = direction,
      mapping = mapping,
      predicted = predicted,
      target = target,
      input = input,
      accuracy = .ldlr_accuracy(predicted, target),
      learning = learning,
      parameters = parameters,
      evaluated_on = if (test) "test" else "training",
      backend = list(name = "JudiLing", package_version = "0.0.1")
    )
  if (direction == "comprehension") {
    value$F <- mapping
    value$S_hat <- predicted
  } else {
    value$G <- mapping
    value$C_hat <- predicted
  }
  structure(value, class = c(paste0("ldlr_", direction), "ldlr_model"))
}

.ldlr_row_cor <- function(a, b) {
  if (length(a) < 2L || stats::sd(a) == 0 || stats::sd(b) == 0) return(NA_real_)
  stats::cor(a, b)
}

.ldlr_accuracy <- function(predicted, target) {
  predicted <- as.matrix(predicted)
  target <- as.matrix(target)
  sims <- stats::cor(t(predicted), t(target))
  if (is.null(dim(sims))) sims <- matrix(sims, 1L, 1L)
  valid <- rowSums(is.na(sims)) == 0L
  if (!any(valid)) return(NA_real_)
  mean(max.col(sims[valid, , drop = FALSE], ties.method = "first") ==
         seq_len(nrow(predicted))[valid])
}
