\name{setup_julia}
\alias{setup_julia}
\alias{ldlr_status}
\title{Configure the Julia backend}
\usage{
setup_julia(julia = NULL, install_julia = interactive(), install_packages = TRUE)

ldlr_status(julia = NULL)
}
\arguments{
  \item{julia}{Optional path to the Julia executable.}
  \item{install_julia}{Whether the optional JuliaCall installer may install Julia.}
  \item{install_packages}{Whether to install and precompile compatible Julia dependencies.}
}
\value{A status list, invisibly for \code{setup_julia()}.}
\description{Locate Julia, activate an isolated ldlr environment, install dependencies, load the adapter, and run a smoke test.}
\details{The workflow is controlled from R and requires no Julia syntax. It installs Julia 1.12 when requested, manages a package-specific Julia environment, loads JudiLing and the ldlr backend, and tests the connection with a small call to \code{JudiLing.make_transform_matrix()}. Julia 1.13 is currently rejected because JudiLing 1 does not declare compatibility with it. \code{ldlr_status()} performs R-side discovery and reports the selected executable, version, compatibility, and environment.}
