\name{compute_measures}
\alias{compute_measures}
\alias{available_measures}
\title{Compute LDL measures}
\usage{
available_measures()

compute_measures(model, measures = "all", neighbours = 8L,
  uncertainty_method = c("correlation", "cosine", "mse"),
  functional_load_method = c("correlation", "mse"))
}
\arguments{
  \item{model}{An ldlr comprehension, production, cross-validation, or produced-forms object. Cross-validation results support matrix-level measures.}
  \item{measures}{Measure names, or \code{"all"} for every applicable measure.}
  \item{neighbours}{Number of neighbours for semantic density.}
  \item{uncertainty_method}{Correlation, cosine similarity, or mean squared error.}
  \item{functional_load_method}{Correlation or mean squared error.}
}
\value{\code{available_measures()} returns the measure catalogue. \code{compute_measures()} returns one data-frame row per item.}
\description{Compute all applicable JudiLingMeasures measures through guarded Julia implementations.}
\details{R selects measures applicable to the object and returns one row per item. Names and intended quantities follow JudiLingMeasures. Numerical work runs in \code{LDLRBackend.matrix_measures()} and \code{LDLRBackend.cue_measures()} rather than dispatching directly to upstream measure functions. These corrected Julia implementations guard undefined correlations, missing values, cue indices, and scalar versus vector measure names. Form-path inputs originate from \code{JudiLing.learn_paths_rpi()} or \code{JudiLing.build_paths()}. \code{available_measures()} itself is entirely native R code.}
