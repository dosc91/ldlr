#' Construct an orthographic n-gram cue matrix
#'
#' Cue extraction, matrix construction, and metadata storage are implemented in
#' R. The representation mirrors `JudiLing.make_cue_matrix()`. Keeping the
#' returned object lets later backend calls verify Julia's cue order and compute
#' cue-dependent measures.
#'
#' @param words Character vector containing one word type per row.
#' @param n N-gram size. The default is three.
#' @param boundary Boundary marker placed at the beginning and end of each word.
#' @param sparse Return a sparse matrix when the Matrix package is available.
#' @return An `ldlr_cues` object containing `C` and sequencing metadata.
#' @export
.ldlr_make_ortho_ngrams <- function(words, n, boundary) {
  if (!is.character(words) || anyNA(words) || any(words == "")) {
    .ldlr_stop("`words` must be a character vector without missing or empty values.")
  }
  if (length(n) != 1L || n < 1 || n != as.integer(n)) {
    .ldlr_stop("`n` must be a positive integer.")
  }
  if (!is.character(boundary) || length(boundary) != 1L || nchar(boundary) != 1L) {
    .ldlr_stop("`boundary` must be one character.")
  }
  if (any(grepl(boundary, words, fixed = TRUE))) {
    .ldlr_stop("The boundary marker already occurs in at least one word.")
  }

  lapply(words, function(word) {
    marked <- paste0(boundary, word, boundary)
    length_marked <- nchar(marked, type = "chars")
    if (length_marked < n) return(character())
    substring(marked, seq_len(length_marked - n + 1L), seq_len(length_marked - n + 1L) + n - 1L)
  })
}

.ldlr_cue_object <- function(words, grams, cue_names, n, boundary, sparse) {
  row_ids <- names(words)
  if (is.null(row_ids)) row_ids <- words
  C <- matrix(0, nrow = length(words), ncol = length(cue_names),
              dimnames = list(row_ids, cue_names))
  for (i in seq_along(grams)) C[i, match(unique(grams[[i]]), cue_names)] <- 1
  if (sparse && requireNamespace("Matrix", quietly = TRUE)) C <- Matrix::Matrix(C, sparse = TRUE)

  structure(
    list(C = C, words = words, paths = grams, cue_names = cue_names,
         n = as.integer(n), boundary = boundary),
    class = "ldlr_cues"
  )
}

#' Construct an orthographic n-gram cue matrix
#'
#' @param words Character vector containing one word type per row.
#' @param n N-gram size. The default is three.
#' @param boundary Boundary marker placed at the beginning and end of each word.
#' @param sparse Return a sparse matrix when the Matrix package is available.
#' @return An `ldlr_cues` object containing `C` and sequencing metadata.
#' @export
make_ortho_trigrams <- function(words, n = 3L, boundary = "#", sparse = TRUE) {
  grams <- .ldlr_make_ortho_ngrams(words, n, boundary)
  cue_names <- unique(unlist(grams, use.names = FALSE))
  .ldlr_cue_object(words, grams, cue_names, n, boundary, sparse)
}

#' Construct compatible training and test cue matrices
#'
#' This is an R implementation of the shared cue-space behavior provided by
#' `JudiLing.make_combined_cue_matrix()`: the two matrices have the same columns
#' in the same order, including cues unique to either partition.
#'
#' @param train_words,test_words Character vectors for the two partitions.
#' @inheritParams make_ortho_trigrams
#' @return A list with compatible `train` and `test` cue objects.
#' @export
make_combined_ortho_trigrams <- function(train_words, test_words, n = 3L,
                                         boundary = "#", sparse = TRUE) {
  train_grams <- .ldlr_make_ortho_ngrams(train_words, n, boundary)
  test_grams <- .ldlr_make_ortho_ngrams(test_words, n, boundary)
  cue_names <- unique(c(unlist(train_grams, use.names = FALSE),
                        unlist(test_grams, use.names = FALSE)))
  list(
    train = .ldlr_cue_object(train_words, train_grams, cue_names, n, boundary, sparse),
    test = .ldlr_cue_object(test_words, test_grams, cue_names, n, boundary, sparse)
  )
}

#' @export
as.matrix.ldlr_cues <- function(x, ...) as.matrix(x$C)

#' @export
as.data.frame.ldlr_cues <- function(x, ...) as.data.frame(as.matrix(x$C), ...)

#' @export
print.ldlr_cues <- function(x, ...) {
  cat("<ldlr orthographic cues>\n")
  cat(" ", length(x$words), "word types x", length(x$cue_names),
      paste0(" ", x$n, "-gram cues\n"))
  invisible(x)
}
