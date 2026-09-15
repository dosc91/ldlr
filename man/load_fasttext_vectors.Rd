\name{load_fasttext_vectors}
\alias{load_fasttext_vectors}
\title{Load vectors in fastText text format}
\usage{
load_fasttext_vectors(file)
}
\arguments{
  \item{file}{Path to a fastText text-vector file. Its first line must contain the vocabulary size and vector dimension.}
}
\value{A numeric matrix with vocabulary items as row names and vector dimensions as columns.}
\description{Read a fastText \code{.vec} text file into a matrix suitable for use as an LDL semantic matrix.}
\details{This function is implemented entirely in R using \code{data.table::fread()}. It does not start Julia or call JudiLing.}
