\name{compute_comprehension}
\alias{compute_comprehension}
\alias{compute_production}
\title{Compute LDL comprehension and production mappings}
\usage{
compute_comprehension(C, S, C_test = NULL, S_test = NULL,
  learning = c("endstate", "frequency", "incremental"), frequency = NULL,
  epochs = 1L, learning_rate = 0.1, learning_sequence = NULL, seed = 314L,
  shift = 0.02)

compute_production(S, C, S_test = NULL, C_test = NULL,
  learning = c("endstate", "frequency", "incremental"), frequency = NULL,
  epochs = 1L, learning_rate = 0.1, learning_sequence = NULL, seed = 314L,
  shift = 0.02)
}
\arguments{
  \item{C, S}{Matched cue and semantic matrices. \code{C} may be an \code{ldlr_cues} object.}
  \item{C_test, S_test}{Optional matched held-out matrices.}
  \item{learning}{End-state, frequency-informed, or incremental Widrow-Hoff learning.}
  \item{frequency}{Frequencies for frequency-informed learning, or integer event counts for incremental learning.}
  \item{epochs}{Number of incremental passes through the presentation sequence.}
  \item{learning_rate}{Widrow-Hoff learning rate.}
  \item{learning_sequence}{Optional explicit sequence of training row indices.}
  \item{seed}{Seed used to create a frequency-expanded random presentation sequence.}
  \item{shift}{Positive ridge shift for end-state and frequency-informed mappings; the default matches JudiLing.}
}
\value{A portable \code{ldlr_comprehension} or \code{ldlr_production} model.}
\description{Estimate a mapping in Julia and return its mapping, predictions, accuracy, and metadata as an ordinary R object.}
\details{In R, the functions validate row alignment and dimensions, retain names and targets, calculate predictions, and construct portable model objects. End-state and frequency-informed fits call \code{JudiLing.make_transform_matrix()}. Incremental fits call \code{JudiLing.wh_learn()} and optionally \code{JudiLing.make_learn_seq()}. Comprehension returns \code{S_hat = C F}; production returns \code{C_hat = S G}.}
