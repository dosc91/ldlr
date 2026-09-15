\name{make_ortho_trigrams}
\alias{make_ortho_trigrams}
\alias{make_combined_ortho_trigrams}
\title{Create orthographic n-gram cues}
\usage{
make_ortho_trigrams(words, n = 3L, boundary = "#", sparse = TRUE)

make_combined_ortho_trigrams(train_words, test_words, n = 3L,
  boundary = "#", sparse = TRUE)
}
\arguments{
  \item{words}{Character vector with one word type per row.}
  \item{train_words, test_words}{Character vectors for training and test partitions.}
  \item{n}{N-gram size.}
  \item{boundary}{One-character boundary marker.}
  \item{sparse}{Whether to use a sparse matrix when Matrix is installed.}
}
\value{An \code{ldlr_cues} object, or a list containing compatible training and test cue objects.}
\description{Construct binary cue matrices while retaining the cue paths and metadata required for form production.}
\details{Cue extraction and matrix construction are implemented entirely in R. \code{make_ortho_trigrams()} mirrors the representation of \code{JudiLing.make_cue_matrix()}; the combined function mirrors \code{JudiLing.make_combined_cue_matrix()} by giving training and test objects identical cue columns. During form production the Julia representation is reconstructed and its cue order is checked against R.}
