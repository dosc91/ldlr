\name{compute_comprehension_loo}
\alias{compute_comprehension_loo}
\alias{compute_production_loo}
\alias{compute_comprehension_cv}
\alias{compute_production_cv}
\alias{print.ldlr_cv}
\alias{summary.ldlr_cv}
\alias{as.data.frame.ldlr_cv}
\alias{fitted.ldlr_cv}
\title{Cross-validated LDL predictions}
\usage{
compute_comprehension_loo(C, S, output = NULL, progress = interactive(),
  chunk_size = 25L, shift = 0.02)

compute_production_loo(S, C, output = NULL, progress = interactive(),
  chunk_size = 25L, shift = 0.02)

compute_comprehension_cv(C, S, folds = 10L, seed = 314L,
  output = NULL, progress = interactive(), shift = 0.02)

compute_production_cv(S, C, folds = 10L, seed = 314L,
  output = NULL, progress = interactive(), shift = 0.02)

\method{summary}{ldlr_cv}(object, by_fold = FALSE, ...)

\method{as.data.frame}{ldlr_cv}(x, ...)

\method{fitted}{ldlr_cv}(object, ...)
}
\arguments{
  \item{C}{A numeric cue matrix or \code{ldlr_cues} object.}
  \item{S}{A matched numeric semantic matrix.}
  \item{folds}{Number of cross-validation folds; defaults to 10.}
  \item{seed}{Seed for reproducible balanced fold assignment.}
  \item{output}{Optional CSV output path.}
  \item{progress}{Whether to display an R progress bar.}
  \item{chunk_size}{Rows calculated between leave-one-out progress updates.}
  \item{shift}{Positive ridge shift; \code{0.02} matches JudiLing's default.}
  \item{object, x}{An \code{ldlr_cv} object.}
  \item{by_fold}{Return one summary row per fold instead of an overall summary.}
  \item{...}{Additional arguments reserved for methods.}
}
\value{An \code{ldlr_cv} object containing held-out predictions, targets, fold assignments, accuracy, and \code{S_hat} or \code{C_hat}. These objects support \code{print()}, \code{summary()}, \code{as.data.frame()}, \code{fitted()}, \code{compute_measures()}, and the ldlr persistence helpers.}
\description{Compute leave-one-out or balanced k-fold end-state LDL predictions for any number of matched rows.}
\details{R validates input, creates balanced folds, displays progress, writes optional CSV output, and constructs the result. Leave-one-out predictions use an exact ridge-leverage identity and one Julia Cholesky factorization; this is equivalent to refitting \code{JudiLing.make_transform_matrix()} for every omitted row. K-fold fitting uses a Julia Cholesky implementation of the same shifted end-state estimator.}
