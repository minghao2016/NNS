% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/Normalization.R
\name{NNS.norm}
\alias{NNS.norm}
\title{NNS Normalization}
\usage{
NNS.norm(A, linear = FALSE, chart.type = NULL, location = "topleft")
}
\arguments{
\item{A}{a numeric matrix or data frame.}

\item{linear}{logical; \code{FALSE} (default) Performs a linear scaling normalization, resulting in equal means for all variables.}

\item{chart.type}{options: ("l", "b"); \code{NULL} (default).  Set \code{(chart.type = "l")} for line,
\code{(chart.type = "b")} for boxplot.}

\item{location}{Sets the legend location within the plot, per the \code{x} and \code{y} co-ordinates used in base graphics \link{legend}.}
}
\value{
Returns a \link{data.frame} of normalized values.
}
\description{
Normalizes a matrix of variables based on nonlinear scaling normalization method.
}
\examples{
set.seed(123)
x <- rnorm(100) ; y<-rnorm(100)
A <- cbind(x, y)
NNS.norm(A)
}
\references{
Viole, F. and Nawrocki, D. (2013) "Nonlinear Nonparametric Statistics: Using Partial Moments"
\url{https://www.amazon.com/dp/1490523995}
}
\author{
Fred Viole, OVVO Financial Systems
}
