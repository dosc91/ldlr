#' Load vectors in fastText text format
#'
#' Read a fastText `.vec` file into a numeric matrix. The vocabulary is stored
#' as row names, in the same order as it occurs in the file.
#'
#' This function is implemented entirely in R using [data.table::fread()]. It
#' does not start Julia or call JudiLing.
#'
#' @param file Path to a fastText text-vector file. Its first line must contain
#'   the vocabulary size and vector dimension.
#' @return A numeric matrix with one word per row and one vector dimension per
#'   column.
#' @export
load_fasttext_vectors <- function(file) {
  if (!is.character(file) || length(file) != 1L || is.na(file) || !nzchar(file)) {
    .ldlr_stop("`file` must be one non-empty file path.")
  }
  if (!file.exists(file)) .ldlr_stop("The fastText vector file does not exist: `", file, "`.")

  header <- readLines(file, n = 1L, warn = FALSE)
  fields <- strsplit(trimws(header), "[[:space:]]+")[[1L]]
  expected <- suppressWarnings(as.integer(fields))
  if (length(fields) != 2L || anyNA(expected) || any(expected < 1L)) {
    .ldlr_stop("The first line must contain the fastText vocabulary size and vector dimension.")
  }

  input <- data.table::fread(file, skip = 1L, header = FALSE, quote = "",
                             showProgress = interactive())
  if (ncol(input) != expected[[2L]] + 1L) {
    .ldlr_stop("The header declares ", expected[[2L]], " vector dimensions, but the data contain ",
               ncol(input) - 1L, ".")
  }
  if (nrow(input) != expected[[1L]]) {
    warning("The header declares ", expected[[1L]], " words, but ", nrow(input),
            " rows were read.", call. = FALSE)
  }

  words <- as.character(input[[1L]])
  vectors <- as.matrix(input[, -1L, with = FALSE])
  storage.mode(vectors) <- "double"
  rownames(vectors) <- words
  colnames(vectors) <- paste0("dim_", seq_len(ncol(vectors)))
  vectors
}
