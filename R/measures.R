.ldlr_measure_catalog <- data.frame(
  name = c(
    "l1", "l2", "semantic_density", "average_lexical_correlation",
    "euclidean_nearest_neighbour", "nearest_neighbour_correlation",
    "target_correlation", "rank", "recognition", "uncertainty",
    "functional_load", "total_distance", "semantic_support_for_form",
    "last_support", "c_precision", "scpp", "path_sum", "target_path_sum",
    "path_sum_chat", "within_path_entropy", "mean_word_support",
    "mean_word_support_chat", "length_weakest_link_ratio",
    "length_weakest_link_ratio_chat", "path_count", "path_entropy_scp",
    "path_entropy_chat", "average_levenshtein_distance"
  ),
  stage = c(rep("matrix", 10), rep("cue", 5), rep("path", 13)),
  direction = c(
    "both", "both", rep("comprehension", 7), "both",
    "comprehension", "both", "production", "production", "production",
    rep("forms", 13)
  ),
  original = c(
    "L1Norm", "L2Norm", "density", "ALC", "EDNN", "NNC",
    "target_correlation", "rank", "recognition", "uncertainty",
    "functional_load", "total_distance", "semantic_support_for_form",
    "last_support", "c_precision", "SCPP", "path_sum", "target_path_sum",
    "path_sum_chat", "within_path_entropies", "mean_word_support",
    "mean_word_support_chat", "lwlr", "lwlr_chat", "path_counts",
    "path_entropies_scp", "path_entropies_chat", "ALDC"
  ),
  stringsAsFactors = FALSE
)

#' List all measures known to ldlr
#'
#' Returns an R data frame containing the public name, calculation stage,
#' applicable direction, and corresponding JudiLingMeasures name. Julia is not
#' called.
#' @export
available_measures <- function() .ldlr_measure_catalog

.ldlr_applicable_measures <- function(object) {
  if (inherits(object, "ldlr_forms")) {
    applicable <- .ldlr_measure_catalog$name[
      .ldlr_measure_catalog$direction %in% c("both", "production", "forms")
    ]
    if (object$method == "build") {
      applicable <- setdiff(applicable, c("path_sum", "target_path_sum",
                                          "within_path_entropy", "mean_word_support",
                                          "length_weakest_link_ratio"))
    }
    return(applicable)
  }
  if (inherits(object, "ldlr_cv")) {
    return(.ldlr_measure_catalog$name[
      .ldlr_measure_catalog$stage == "matrix" &
        .ldlr_measure_catalog$direction %in% c("both", object$direction)
    ])
  }
  .ldlr_measure_catalog$name[
    .ldlr_measure_catalog$direction %in% c("both", object$direction) &
      .ldlr_measure_catalog$direction != "forms"
  ]
}

.ldlr_bind_measure <- function(out, name, value) {
  value <- .ldlr_julia_get(value)
  if (length(value) == nrow(out) && !is.list(value)) {
    out[[name]] <- value
  } else if (length(value) == nrow(out)) {
    out[[name]] <- I(as.list(value))
  } else {
    .ldlr_stop("Measure `", name, "` returned ", length(value),
               " values for ", nrow(out), " items.")
  }
  out
}

#' Compute validated LDL measures
#'
#' R selects measures applicable to the supplied object and returns one row per
#' item. Matrix and cue calculations run in the package's Julia backend. Their
#' terminology follows JudiLingMeasures, but guarded implementations are used
#' instead of directly dispatching to upstream functions so that undefined
#' correlations, cue indices, missingness, and scalar versus vector measure
#' names are handled consistently. For produced forms, the underlying paths
#' come from `JudiLing.learn_paths_rpi()` or `JudiLing.build_paths()`.
#'
#' @param model An `ldlr_model`, `ldlr_cv`, or `ldlr_forms` object.
#' @param measures Measure names, or `"all"` for every applicable measure.
#' @param neighbours Number of neighbours used for semantic density.
#' @param uncertainty_method Similarity used by uncertainty: `"correlation"`,
#'   `"cosine"`, or `"mse"`.
#' @param functional_load_method Compare cue contributions using
#'   `"correlation"` or `"mse"`.
#' @export
compute_measures <- function(model, measures = "all", neighbours = 8L,
                             uncertainty_method = c("correlation", "cosine", "mse"),
                             functional_load_method = c("correlation", "mse")) {
  if (!inherits(model, "ldlr_model") && !inherits(model, "ldlr_forms") &&
      !inherits(model, "ldlr_cv")) {
    .ldlr_stop("`model` must be an ldlr model, cross-validation result, or produced-forms object.")
  }
  uncertainty_method <- match.arg(uncertainty_method)
  functional_load_method <- match.arg(functional_load_method)
  neighbours <- .ldlr_positive_integer(neighbours, "neighbours")
  applicable <- .ldlr_applicable_measures(model)
  if (identical(measures, "all")) {
    measures <- applicable
  } else {
    unknown <- setdiff(measures, .ldlr_measure_catalog$name)
    if (length(unknown)) .ldlr_stop("Unknown measure(s): ", paste(unknown, collapse = ", "))
    unavailable <- setdiff(measures, applicable)
    if (length(unavailable)) {
      .ldlr_stop("Measure(s) not applicable to this object: ", paste(unavailable, collapse = ", "))
    }
  }

  if (inherits(model, "ldlr_forms")) {
    base_names <- intersect(measures, .ldlr_applicable_measures(model$production))
    out <- if (length(base_names)) {
      compute_measures(model$production, base_names, neighbours, uncertainty_method,
                       functional_load_method)
    } else {
      data.frame(item = seq_len(nrow(model$items)))
    }
    path_names <- intersect(measures,
      .ldlr_measure_catalog$name[.ldlr_measure_catalog$stage == "path"])
    for (name in path_names) out <- .ldlr_bind_measure(out, name, model$measures[[name]])
    return(out)
  }

  matrix_names <- intersect(measures, c(
    "l1", "l2", "semantic_density", "average_lexical_correlation",
    "euclidean_nearest_neighbour", "nearest_neighbour_correlation",
    "target_correlation", "rank", "recognition", "uncertainty"
  ))
  out <- data.frame(item = rownames(model$predicted) %||% seq_len(nrow(model$predicted)),
                    stringsAsFactors = FALSE)
  if (length(matrix_names)) {
    values <- .ldlr_measure_backend(model$predicted, model$target,
                                    matrix_names, neighbours, uncertainty_method)
    for (name in matrix_names) out <- .ldlr_bind_measure(out, name, values[[name]])
  }

  cue_names <- intersect(measures, c("functional_load", "total_distance",
                                     "semantic_support_for_form", "last_support",
                                     "c_precision"))
  if (length(cue_names) && !inherits(model, "ldlr_cv")) {
    cues <- model$cues
    if (!inherits(cues, "ldlr_cues")) {
      .ldlr_stop("Cue-dependent measures require a model fitted with an `ldlr_cues` object.")
    }
    values <- .ldlr_cue_measure_backend(
      model$direction, model$mapping, model$predicted, model$target,
      cues$paths, cues$cue_names, cue_names, functional_load_method
    )
    for (name in cue_names) out <- .ldlr_bind_measure(out, name, values[[name]])
  }
  out
}
