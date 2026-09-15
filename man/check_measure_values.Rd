\name{check_measure_values}
\alias{check_measure_values}
\title{Diagnose problematic measure columns}
\usage{
check_measure_values(x, problems_only = FALSE,
  tolerance = sqrt(.Machine$double.eps), include_identifiers = FALSE)
}
\arguments{
  \item{x}{A data frame returned by \code{compute_measures()}.}
  \item{problems_only}{Return only columns with a detected problem.}
  \item{tolerance}{Relative tolerance used to identify numerically constant floating-point columns.}
  \item{include_identifiers}{Also inspect identifier columns named \code{item} and \code{fold}.}
}
\value{A data frame with one row per inspected measure, diagnostic counts, flags, and a concise issues column.}
\description{Detect missing values, NaN, infinity, all-missing output, and constant or numerically near-constant measures. Numeric values inside list-columns are included.}
\details{All diagnostics are computed in R. Julia, JudiLing, and JudiLingMeasures are not called.}
