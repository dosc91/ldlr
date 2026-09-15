\name{save_ldlr_model}
\alias{save_ldlr_model}
\alias{load_ldlr_model}
\title{Save and load portable ldlr objects}
\usage{
save_ldlr_model(model, file)

load_ldlr_model(file)
}
\arguments{
  \item{model}{An ldlr model, cross-validation result, or produced-forms object.}
  \item{file}{RDS file path.}
}
\value{The save path invisibly, or the restored object.}
\description{Persist ordinary R data rather than a live Julia proxy.}
\details{These functions call \code{saveRDS()} and \code{readRDS()} and validate the restored class. No Julia session is required.}
