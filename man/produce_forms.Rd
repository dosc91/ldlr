\name{produce_forms}
\alias{produce_forms}
\title{Produce ordered forms}
\usage{
produce_forms(production, comprehension, cues = production$cues,
  method = c("build", "learn"), max_candidates = 10L,
  threshold = 0.1, tolerant = FALSE, tolerance = -1000,
  max_tolerance = 3L, neighbours = 10L, verbose = FALSE)
}
\arguments{
  \item{production}{Matching production model.}
  \item{comprehension}{Matching comprehension model used for synthesis-by-analysis.}
  \item{cues}{Structured cue object for the evaluated word types.}
  \item{method}{JudiLing's build-paths or learn-paths algorithm.}
  \item{max_candidates}{Maximum candidate paths retained per item.}
  \item{threshold, tolerant, tolerance, max_tolerance}{Learn-paths threshold settings.}
  \item{neighbours}{Nearest training forms used by build-paths.}
  \item{verbose}{Whether JudiLing should report progress.}
}
\value{A portable \code{ldlr_forms} object containing item and candidate tables.}
\description{Turn predicted cue activation into ordered candidate word forms using JudiLing.}
\details{R validates the model and cue objects. Julia reconstructs cues with \code{JudiLing.make_cue_matrix()} or \code{JudiLing.make_combined_cue_matrix()}, obtains the search horizon with \code{JudiLing.cal_max_timestep()}, and calls \code{JudiLing.learn_paths_rpi()} or \code{JudiLing.build_paths()}. Candidate paths are converted to forms with \code{JudiLing.translate()} and returned as portable R tables. Path search can be computationally expensive.}
